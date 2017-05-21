{
  formattedInspect, log
  defineModule
  merge
  array
  mergeInto
  object
  objectWithout
  snakeCase
} = require 'art-standard-lib'
{DeclarableMixin} = require 'art-class-system'
{Pipeline, pipelines} = require 'art-ery'

{config} = require "../ElasticsearchConfig"
{Aws4RestClient} = require 'art-aws'
Elasticsearch = require './namespace'
{CommunicationStatus:{missing}} = require 'art-foundation'

defineModule module, class ElasticsearchPipelineBase extends DeclarableMixin Pipeline
  @abstractClass()
  @getter
    restClient:           -> @_aws4RestClient     ||= new Aws4RestClient merge config, service: 'es'
    elasticsearchIndex:   -> @_elasticsearchIndex ||= snakeCase config.index
    indexUrl:     (index) -> "/#{index || @getElasticsearchIndex()}"

  ###
  using @fields, generate the correct 'mappings' data for initializing the Elasticsearch index
  SEE:
    https://www.elastic.co/guide/en/elasticsearch/reference/current/mapping.html
    https://www.elastic.co/guide/en/elasticsearch/reference/current/mapping-types.html

  OUT: plain data-structue that is exactly what you can PUT to
    elasticsearch to initialize all mappings for the current elasticsearchPipelines.
  ###
  @getElasticsearchMappings: ->
    elasticsearchPipelines = array pipelines,
      when: (v) -> v instanceof Elasticsearch.ElasticsearchPipeline

    settings = {}
    mappings: object elasticsearchPipelines,
      key:  (pipeline) -> pipeline.elasticsearchType
      with: (pipeline) ->
        mapping = pipeline.getMapping()
        if mapping.settings
          mergeInto settings, mapping.settings
          objectWithout mapping, "settings"
        else
          mapping
    settings: settings

  @handlers
    indexExists: (request) ->
      @restClient.getJson @getIndexUrl()
      .then -> request.success data: true
      .catch (e) =>
        if e.status == missing
          request.success data: false
        else
          @normalizeJsonRestClientError request, e


  normalizeJsonRestClientResponse: (request, p) ->
    p.catch (e) =>
      @normalizeJsonRestClientError request, e

  normalizeJsonRestClientError: (request, error) ->
    if error.info
      request.failure
        status: error.info.status
        data:   error.info.response
    else
      throw error
