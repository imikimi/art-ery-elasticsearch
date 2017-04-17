{formattedInspect, log, present, isPlainObject, defineModule, snakeCase} = require 'art-standard-lib'
{CommunicationStatus:{missing}} = require 'art-foundation'
{Pipeline} = require 'art-ery'
RestClient = require 'art-rest-client'

{config} = require "./ElasticsearchConfig"

defineModule module, class ElasticsearchPipeline extends Pipeline
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
  @extendableProperty mapping: {}
  @mapping: @extendMapping

  ###################
  @classGetter
    elasticsearchType:  -> @_elasticsearchType  ||= snakeCase @getName().split(/Search$/)[0]
    elasticsearchIndex: -> @_elasticsearchIndex ||= snakeCase config.index
    indexTypeUrl: -> "#{@getIndexUrl()}/#{@getElasticsearchType()}"
    searchUrl:    -> "#{@getIndexTypeUrl()}/_search"
    indexUrl:     (index) -> "#{config.endpoint}/#{index || @getElasticsearchIndex()}"

  @getter
    elasticsearchType:  -> @class.getElasticsearchType()
    elasticsearchIndex: -> @class.getElasticsearchIndex()
    indexTypeUrl:       -> @class.getIndexTypeUrl()
    searchUrl:          -> @class.getSearchUrl()
    indexUrl:           (index) -> @class.getIndexUrl index

  getEntryUrl:  (id) -> "#{@getIndexUrl()}/#{@elasticsearchType}/#{id}"
  getUpdateUrl: (id) -> "#{@getEntryUrl id}/_update"

  normalizeJsonRestClientResponse = (request, p) ->
    p.catch (e) ->
      normalizeJsonRestClientError request, e

  normalizeJsonRestClientError = (request, error) ->
    if error.info?.response?.error
      request.failure data: error.info?.response?.error
    else
      throw error

  @handlers
    # using @fields, initialize the Elasticsearch index with proper field-types
    # SEE: https://www.elastic.co/guide/en/elasticsearch/reference/current/mapping.html
    # SEE: https://www.elastic.co/guide/en/elasticsearch/reference/current/mapping-types.html
    initialize: (request)->
      request.subrequest request.pipeline, "vivifyIndex"
      .then =>
        normalizeJsonRestClientResponse request,
          RestClient.putJson "#{@getIndexUrl()}/_mapping/#{@elasticsearchType}", @class.getMapping()

    vivifyIndex: (request) ->
      request.subrequest request.pipeline, "indexExists"
      .then (exists) ->
        unless exists
          request.subrequest request.pipeline, "createIndex"
        else
          true

    createIndex: (request) ->
      normalizeJsonRestClientResponse request, RestClient.putJson @getIndexUrl()

    listIndicies: (request) ->
      RestClient.restRequest verb: "HEAD", url: @getIndexUrl "*"

    indexExists: (request) ->
      RestClient.restRequest verb: "HEAD", url: @getIndexUrl()
      .then -> request.success data: true
      .catch (e) ->
        if e.status == missing
          request.success data: false
        else
          normalizeJsonRestClientError request, e

    deleteIndex: (request) ->
      request.require request.data?.force, "data.force=true required"
      .then =>
        normalizeJsonRestClientResponse request, RestClient.delete @getIndexUrl()


    # add or update(replace) a 'document' in the index
    index: (request) ->
      {key, data} = request
      request.require present(key) && isPlainObject(data), "key and data required, #{formattedInspect {key, data}}"
      .then =>
        normalizeJsonRestClientResponse request,
          RestClient.putJson @getEntryUrl(key), data

    # SEE: https://www.elastic.co/guide/en/elasticsearch/reference/current/docs-update.html
    # Actually, this is createOrUpdate
    update: (request) ->
      {key, data} = request
      request.require present(key) && isPlainObject(data), "key and data required, #{formattedInspect {key, data}}"
      .then =>
        normalizeJsonRestClientResponse request,
          RestClient.postJson @getUpdateUrl(key),
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
      normalizeJsonRestClientResponse request,
        RestClient.postJson @getSearchUrl(), data
