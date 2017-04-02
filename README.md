# Art-Ery Elasticsearch

ArtEry Pipeline for Elasticsearch

# Development Server

##### Get

* [download elastic search](https://www.elastic.co/downloads/elasticsearch)
* [official installation doc](https://www.elastic.co/guide/en/elasticsearch/guide/current/running-elasticsearch.html)

##### Run

```bash
> ./elasticsearch-5.3.0/bin/elasticsearch
```

##### Verify

* [click to test](http://localhost:9200/?pretty)

You should see something like this:

```json
{
  "name" : "TD4A4C2",
  "cluster_name" : "elasticsearch",
  "cluster_uuid" : "3AH3n90VQEiuVbei0jKHJw",
  "version" : {
    "number" : "5.3.0",
    "build_hash" : "3adb13b",
    "build_date" : "2017-03-23T03:31:50.652Z",
    "build_snapshot" : false,
    "lucene_version" : "6.4.1"
  },
  "tagline" : "You Know, for Search"
}
```
