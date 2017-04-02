{formattedInspect, log, present, isPlainObject, defineModule, snakeCase} = require 'art-standard-lib'
{Pipeline} = require 'art-ery'
RestClient = require 'art-rest-client'

{config} = require "./ElasticsearchConfig"

defineModule module, class ElasticsearchPipeline extends Pipeline
  @abstractClass()

  @getter
    elastichSearchType: -> @_elasticSearchType ||= snakeCase @class.getName()

  getEntryUrl: (id) ->
    "#{config.endpoint}/#{snakeCase config.index}/#{@elastichSearchType}/#{id}"

  getSearchUrl: -> @getEntryUrl "_search"

  @handlers
    # using @fields, initialize the Elasticsearch index with proper field-types
    initialize: ->

    # add or update(replace) a 'document' in the index
    index: (request) ->
      {key, data} = request
      request.require present(key) && isPlainObject(data), "key and data required, #{formattedInspect {key, data}}"
      .then =>
        RestClient.putJson @getEntryUrl(key), data

    ###
    perform a search

    Initially, data should just be the full elasticsearch API.

    But, I suspect we'll want some streamlined options.
    ###
    search: (request) ->
      {data} = request
      RestClient.postJson @getSearchUrl(), data
