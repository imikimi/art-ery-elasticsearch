{
  formattedInspect, log
  defineModule
  merge
} = require 'art-standard-lib'
{DeclarableMixin} = require 'art-class-system'
{Pipeline} = require 'art-ery'

{config} = require "../ElasticsearchConfig"
{Aws4RestClient} = require 'art-aws'

defineModule module, class ElasticsearchGlobal extends require './ElasticsearchPipelineBase'

  @handlers

    # SEE: @getElasticsearchMappings
    initialize: (request)->
      request.subrequest request.pipeline, "indexExists"
      .then (exists) =>
        if !exists
          @normalizeJsonRestClientResponse request,
            @restClient.putJson @getIndexUrl(), @class.getElasticsearchMappings()
        else
          status: "alreadyInitialized"

    getIndicies: (request) ->
      @restClient.getJson "/*"

    createIndex: (request) ->
      @normalizeJsonRestClientResponse request, @restClient.putJson @getIndexUrl()

    deleteIndex: (request) ->
      request.require request.data?.force, "data.force=true required"
      .then =>
        @normalizeJsonRestClientResponse request, @restClient.deleteJson @getIndexUrl()
