{timeout, log, defineModule} = require 'art-standard-lib'
{CommunicationStatus:{missing}} = require 'art-foundation'
{createWithPostCreate} = require 'art-class-system'
{ElasticsearchPipeline} = Neptune.Art.Ery.Elasticsearch
{pipelines} = require 'art-ery'
RestClient = require 'art-rest-client'

defineModule module, suite: ->
  @timeout 10000

  createWithPostCreate class UserSearch extends ElasticsearchPipeline
    @mapping
      properties:
        email: type: "keyword"
        name:  type: "text"
        about: type: "text", analyzer: "english"

  createWithPostCreate class PostSearch extends ElasticsearchPipeline
    @parentField "userId"

    @mapping
      _parent: type: "user_search"
      properties:
        userId: type: "keyword"
        text:   type: "text", analyzer: "english"

  {userSearch} = pipelines

  setup ->
    userSearch.indexExists()
    .then (exists) -> userSearch.deleteIndex data: force: true if exists
    .then ->