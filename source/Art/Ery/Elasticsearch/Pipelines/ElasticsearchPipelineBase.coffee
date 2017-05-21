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

defineModule module, class ElasticsearchPipelineBase extends DeclarableMixin Pipeline
  @abstractClass()
  @getter
    restClient:           -> @_aws4RestClient     ||= new Aws4RestClient merge config, service: 'es'
    elasticsearchIndex:   -> @_elasticsearchIndex ||= snakeCase config.index
    indexUrl:     (index) -> "/#{index || @getElasticsearchIndex()}"

  normalizeJsonRestClientResponse: (request, p) ->
    p.catch (e) => @normalizeJsonRestClientError request, e

  normalizeJsonRestClientError: (request, error) ->
    if error.info
      request.toResponse error.info.status, data: error.info.response
    else
      throw error
