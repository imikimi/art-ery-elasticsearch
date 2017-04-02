{log, defineModule} = require 'art-standard-lib'
{createWithPostCreate} = require 'art-class-system'
{ElasticsearchPipeline} = Neptune.Art.Ery.Elasticsearch

defineModule module, suite: ->
  test "foo", ->
    createWithPostCreate class MySearchPipeline extends ElasticsearchPipeline
      ;

    msp = new MySearchPipeline
    msp.index key: "abc", data: foo: 123, bar: "welcome to search"
    .then ->
      msp.search data: query: match: _id: "abc"
    .then (out) ->
      assert.eq out.hits.total, 1
    .catch (e) ->
      log errorInfo: e.info
      throw e