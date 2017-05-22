{
  formattedInspect, log, present, isPlainObject, defineModule, snakeCase
  array, object, find
  compactFlatten
  objectWithout
  mergeInto
  isString
  merge
} = require 'art-standard-lib'
{DeclarableMixin} = require 'art-class-system'
{CommunicationStatus:{missing}} = require 'art-foundation'
{Pipeline, pipelines} = require 'art-ery'

{config} = require "../ElasticsearchConfig"

defineModule module, class ElasticsearchPipeline extends require './ElasticsearchPipelineBase'
  @abstractClass()

  ###################
  # DECLARATIVE API
  ###################

  ###
  set mapping

  SEE: https://www.elastic.co/guide/en/elasticsearch/reference/current/mapping.html

  IN: the mapping for this pipeline's index+type

    NOTE: the elasticsearch API's mappings action can set all indexes and all types
    in one call. The mapping specified HERE, though, is only for the current pipeline's
    mapping. Each pipeline represents a specific elasticsearch-index and a specific
    elasticsearch-type.

    SO, the input value for @mapping is the plain-object-structure for just one index+type.
    The index and type will automatically be wrapped around the @mapping value you specified.

  example:

    declaration:

      @mapping
        _all:     enabled: false
        properties:
          title:  type: "text"
          name:   type: "text"
          age:    type: "integer"

    sent to elasticsearch:
      mappings:
        "#{@elasticsearchType}":
          _all:     enabled: false
          properties:
            title:  type: "text"
            name:   type: "text"
            age:    type: "integer"

  ###
  @declarable
    parentField:  validate: isString
    routingField: validate: isString
    mapping:      extendable: {}

  ###################
  @getter
    elasticsearchType:  -> @_elasticsearchType  ||= snakeCase @class.getName()
    indexTypeUrl:       -> "#{@getIndexUrl()}/#{@getElasticsearchType()}"
    searchUrl:          -> "#{@getIndexTypeUrl()}/_search"

  getEntryBaseUrl:  (id) -> "#{@getIndexUrl()}/#{@elasticsearchType}/#{id}"
  getEntryUrl:      (id, data) -> "#{@getEntryBaseUrl id}#{@getEntryUrlParams data}"
  getUpdateUrl:     (id, data) -> "#{@getEntryBaseUrl id}/_update#{@getEntryUrlParams data}"

  getEntryUrlParams:    (data) ->
    params = compactFlatten [
      if routingField = @getRoutingField()
        unless present routingValue = data[routingField]
          throw new Error "routing field '#{routingField}' is not present in data: #{formattedInspect data}"
        "routing=#{encodeURIComponent routingValue}"

      if parentField = @getParentField()
        unless present parentValue = data[parentField]
          throw new Error "parent field '#{parentField}' is not present in data: #{formattedInspect data}"

        "parent=#{encodeURIComponent parentValue}"
    ]

    "?#{params.join "&"}"

  @handlers

    get: (request) ->
      {key, data} = request
      request.require present(key), "key required, #{formattedInspect {key, data}}"
      .then =>
        @normalizeJsonRestClientResponse request,
          @restClient.getJson @getEntryUrl key, data
          # @elasticsearchClient.get id: key, data: data
      .then (got) =>
        request.success
          data: got._source
          elasticsearch: objectWithout got, "_source"

    # Adds or replaces a 'document' in the index
    # this is not "create" since it doesn't generate a key - the key must be provided
    addOrReplace: (request) ->
      {key, data} = request
      request.require present(key) && isPlainObject(data), "key and data required, #{formattedInspect {key, data}}"
      .then =>
        @normalizeJsonRestClientResponse request,
          @restClient.putJson @getEntryUrl(key, data), data

    # SEE: https://www.elastic.co/guide/en/elasticsearch/reference/current/docs-update.html
    # Actually, this is createOrUpdate
    # TODO: I'd probably rename this to createOrUpdate, but ArtEry.UpdateAfterMixin only supports "update" right now
    update: (request) ->
      {key, data} = request
      request.require present(key) && isPlainObject(data), "key and data required, #{formattedInspect {key, data}}"
      .then =>
        @normalizeJsonRestClientResponse request,
          @restClient.postJson @getUpdateUrl(key, data),
            doc:            data  # update fields in data
            doc_as_upsert:  true  # if doesn't exist, create with data

    # delete
    delete: (request) ->
      request.require false # TODO!

    ###
    perform a search

    Initially, data should just be the full elasticsearch API.

    But, I suspect we'll want some streamlined options.
    ###
    elasticsearch: (request) ->
      {data} = request
      @normalizeJsonRestClientResponse request,
        @restClient.postJson @getSearchUrl(), data
