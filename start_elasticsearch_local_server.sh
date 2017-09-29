#!/usr/bin/env bash
VERSION=5.6.2
cd `dirname "$0"`/devserver
echo "ELASTICSEARCH: deleting old data"
rm -rf elasticsearch-$VERSION/
echo "ELASTICSEARCH: unzipping v$VERSION"
unzip elasticsearch-$VERSION.zip > /dev/null
echo "ELASTICSEARCH: starting server v$VERSION"
./elasticsearch-$VERSION/bin/elasticsearch