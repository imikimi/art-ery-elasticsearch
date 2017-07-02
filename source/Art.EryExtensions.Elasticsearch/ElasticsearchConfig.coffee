{merge, defineModule, select, newObjectFromEach, mergeInto, Configurable} = require 'art-foundation'

defineModule module, class ElasticsearchConfig extends Configurable
  @defaults
    index:    "ArtEryElasticsearch"
    endpoint: # "https://search-imikimi-zo-ws32l6szgwqfv6hivvp7j5wlsq.us-east-1.es.amazonaws.com"
      "http://localhost:9200"