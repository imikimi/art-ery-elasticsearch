# generated by Neptune Namespaces v3.x.x
# file: Art.EryExtensions.Elasticsearch/namespace.coffee

module.exports = (require 'neptune-namespaces').addNamespace 'Art.EryExtensions.Elasticsearch', class Elasticsearch extends Neptune.PackageNamespace
  @version: require('../../package.json').version
require './Pipelines/namespace'