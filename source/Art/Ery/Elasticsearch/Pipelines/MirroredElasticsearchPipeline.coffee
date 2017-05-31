{present, object, defineModule, array, log, isString, formattedInspect} = require 'art-standard-lib'
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

    #####################
    # Declarable API
    #####################
    @declarable   sourcePipelineName: validate: isString
    @classGetter  sourcePipeline: -> pipelines[@getSourcePipelineName()]
    @getter       sourcePipeline: -> pipelines[@getSourcePipelineName()]

    #####################
    # Optional Overrides
    #####################
    ###
    IN:
      sourceData:
        extracted from sourcePipelineResponse:

        sourceData =
          sourcePipelineResponse.responseProps.updatedData ||
          sourcePipelineResponse.responseData ||
          sourcePipelineResponse.requestData

      sourcePipelineResponse: Art.Ery.Response from a get, create or update request on the @sourcePipeline

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
      The default implementation selects all the fields from sourceData that are
      in the properties defined by @mapping.
    ###

    getElasticsearchData: (sourceData, sourcePipelineResponse) ->
      object @getMapping().properties,
        when: (v, k) -> sourceData[k]?
        with: (v, k) -> sourceData[k]

    # Opposite of getElasticsearchData
    # override for custom elasticsearchDataFormat > applicationDbDataFormat
    # OUT: object (not a promise!)
    getApplicationData: (data) -> data

    ######################
    # PUBLIC IMPLEMENTATION
    ######################
    @postCreateConcreteClass: ->
      out = super

      throw new Error "sourcePipelineName invalid: #{formattedInspect getSourcePipelineName()}" unless isString @getSourcePipelineName()

      # TODO: implement deleteAfter in UpdateAfterMixin
      # @deleteAfter
      #   delete: "#{@getSourcePipelineName()}": (response) -> key: response.key

      @updateAfter
        create: "#{@getSourcePipelineName()}": (response) -> @_getElasticsearchUpdateProps response
        update: "#{@getSourcePipelineName()}": (response) -> @_getElasticsearchUpdateProps response

      out

    @handler
      reindex: (request) ->
        request.subrequest @getSourcePipelineName(), "get", key: request.key, returnResponseObject: true
        .then (response)    => @_getElasticsearchUpdateProps response
        .then (updateProps) => request.subrequest request.pipeline, "addOrReplace", updateProps

    @filter
      after: get: (response) ->
        response.withData @getApplicationData response.responseData

    ###############
    # PRIVATE
    ###############

    _getElasticsearchUpdateProps: (sourcePipelineResponse)->
      sourceData =
        sourcePipelineResponse.responseProps.updatedData ||
        sourcePipelineResponse.responseData ||
        sourcePipelineResponse.requestData

      Promise.resolve @getElasticsearchData sourceData, sourcePipelineResponse
      .then (elasticsearchData) =>
        key:  sourcePipelineResponse.responseData?.id || sourcePipelineResponse.key
        data: @_getElasticsearchDataWithRouting elasticsearchData, sourcePipelineResponse

    _getElasticsearchDataWithRouting: (elasticsearchData, response) ->
      routingField = @class.getRoutingField()
      parentField = @class.getParentField()
      {requestData, responseData} = response

      elasticsearchData = object elasticsearchData if routingField || parentField

      if routingField
        unless present elasticsearchData[routingField] ||= responseData[routingField] || requestData[routingField]
          throw new Error "missing routing field: #{formattedInspect {routingField, requestData, responseData}}"

      if parentField
        unless present elasticsearchData[parentField] ||= responseData[parentField] || requestData[parentField]
          throw new Error "missing parent field: #{formattedInspect {parentField, requestData, responseData}}"

      elasticsearchData
