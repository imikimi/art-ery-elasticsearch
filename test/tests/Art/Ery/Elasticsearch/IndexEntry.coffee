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

  {userSearch} = pipelines

  setup ->
    userSearch.indexExists()
    .then (exists) -> userSearch.deleteIndex data: force: true if exists
    .then -> userSearch.initialize()

  test "indexExists, deleteIndex and initialize", ->

  test "index then search", ->
    userSearch.index key: "abc", data: email: "shanebdavis@imikimi.com", name: "Shane Delamore", about: "I like to make fun things."
    .then -> timeout 1000 # it takes > 500ms for the new entry to show up in the search...
    .then -> userSearch.elasticsearch data: query: match: about: "thing"
    .then (out) -> assert.eq out.hits.total, 1


  test "update-create then update-update then search", ->
    userSearch.update key: "123", data: email: "shanebdavis@imikimi.com", name: "Shane Delamore", about: "I like to make fun things."
    .then -> timeout 1000 # it takes > 500ms for the new entry to show up in the search...
    .then -> userSearch.elasticsearch data: query: match: about: "thing"
    .then (out) -> assert.eq out.hits.total, 1
    .then -> userSearch.update key: "123", data: email: "shanebdavis@gmail.com"

    .then -> timeout 1000 # it takes > 500ms for the new entry to show up in the search...
    .then -> userSearch.elasticsearch data: query: match: about: "thing"
    .then (out) ->
      assert.eq out.hits.total, 1
      assert.eq
        email: "shanebdavis@gmail.com"
        name: "Shane Delamore"
        about: "I like to make fun things."
        out.hits.hits[0]._source
