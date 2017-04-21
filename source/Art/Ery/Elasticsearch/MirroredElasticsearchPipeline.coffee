{present, object, defineModule, array, log} = require 'art-standard-lib'
{pipelines, UpdateAfterMixin, KeyFieldsMixin} = require 'art-ery'
ElasticsearchPipeline = require "./ElasticsearchPipeline"

defineModule module, ->
  ###
  Purpose:

  Example use:
    class UserSearch extends MirroredElasticsearchPipeline

      @setSourcePipeline "user"

      @mapping
        # field-types: https://www.elastic.co/guide/en/elasticsearch/reference/current/mapping-types.html
        properties:
          displayName:        type: "text",     analyzer: "english"

          postCount:          type: "integer"
          topicCount:         type: "short"
          followerCount:      type: "integer"
          messageCount:       type: "integer"

          lastTopicCreatedAt: type: "long"
          lastPostCreatedAt:  type: "long"
          profileTopicId:     type: "keyword",  index: false

  ###
  class MirroredElasticsearchPipeline extends UpdateAfterMixin KeyFieldsMixin ElasticsearchPipeline
    @abstractClass()

    ###
    IN:
      sourceData:
        This is just a shortcut to the data you usually need from the response object:

        if response.type == 'update'
          response.requestData
          # generally, you only need to re-index the updated fields

        if response.type == 'create'
          response.responseData
          # generally, you'll want the created object's ID
          # and that's only in responseData.

      response: Art.Ery.Response from a create or update request on the @pipelineToIndex

    OUT:
      promise.then (data) ->
      OR
      data (promise is optional)

      data: plain data-structure to be passed to elastic-search to index

    The returned data will be merged with any existing index data for the given key.
    Therefor, you only need to return updated fields. One quick test:

      sourceData = switch response.type
        when "update" then response.requestData
        when "create" then response.responseData
        else throw new Error "not supported"

    DEFAULT:
      The default implementation selects all the fields from updatedData that are
      in the properties defined by @mapping.
    ###

    getElasticsearchData: (updatedData, response) ->
      object @getMapping().properties,
        when: (v, k) -> updatedData[k]?
        with: (v, k) -> updatedData[k]

    # Opposite of getElasticsearchData
    # override for custom elasticsearchDataFormat > applicationDbDataFormat
    # OUT: object (not a promise!)
    getApplicationData: (data) -> data

    @getSourcePipelineName: -> @_sourcePipelineName
    @getSourcePipeline:     -> pipelines[@_sourcePipelineName]
    @sourcePipelineName:    (@_sourcePipelineName) ->

      # TODO: implement deleteAfter in UpdateAfterMixin
      # @deleteAfter
      #   delete:
      #     "#{@getSourcePipelineName()}": (response) ->
      #       key: response.key

      @updateAfter
        create:
          "#{@getSourcePipelineName()}": (response) ->
            Promise.resolve @getElasticsearchData response.responseData, response
            .then (elasticsearchData) =>
              key:  response.responseData.id # TODO: Art.Ery should return the new key with "response.key", but it doesn't yet...
              data: @_getElasticsearchDataWithRouting elasticsearchData, response

        update:
          "#{@getSourcePipelineName()}": (response) ->
            Promise.resolve @getElasticsearchData response.responseProps.updatedData || response.requestData, response
            .then (elasticsearchData) =>
              key:  response.key
              data: @_getElasticsearchDataWithRouting elasticsearchData, response

    @filter
      after: get: (response) ->
        response.withData @getApplicationData response.responseData

    ###############
    # PRIVATE
    ###############

    _getElasticsearchDataWithRouting: (elasticsearchData, response) ->
      routingField = @class.getRoutingField()
      parentField = @class.getParentField()
      {requestData, responseData} = response

      elasticsearchData = object elasticsearchData if routingField || parentField

      if routingField
        unless present elasticsearchData[routingField] ||= responseData[routingField] || requestData[routingField]
          throw new Error "missing routing field: #{routingField}"

      if parentField
        unless present elasticsearchData[parentField] ||= responseData[parentField] || requestData[parentField]
          throw new Error "missing parent field: #{parentField}"

      elasticsearchData
