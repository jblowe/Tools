curl -S -s http://localhost:8983/solr/bampfa-internal/update --data '<optimize/>' -H 'Content-type:text/xml; charset=utf-8'
curl -S -s http://localhost:8983/solr/bampfa-public/update --data '<optimize/>' -H 'Content-type:text/xml; charset=utf-8'
curl -S -s http://localhost:8983/solr/botgarden-internal/update --data '<optimize/>' -H 'Content-type:text/xml; charset=utf-8'
curl -S -s http://localhost:8983/solr/botgarden-propagations/update --data '<optimize/>' -H 'Content-type:text/xml; charset=utf-8'
curl -S -s http://localhost:8983/solr/botgarden-public/update --data '<optimize/>' -H 'Content-type:text/xml; charset=utf-8'
curl -S -s http://localhost:8983/solr/pahma-internal/update --data '<optimize/>' -H 'Content-type:text/xml; charset=utf-8'
curl -S -s http://localhost:8983/solr/pahma-locations/update --data '<optimize/>' -H 'Content-type:text/xml; charset=utf-8'
curl -S -s http://localhost:8983/solr/pahma-osteology/update --data '<optimize/>' -H 'Content-type:text/xml; charset=utf-8'
curl -S -s http://localhost:8983/solr/pahma-public/update --data '<optimize/>' -H 'Content-type:text/xml; charset=utf-8'
curl -S -s http://localhost:8983/solr/ucjeps-media/update --data '<optimize/>' -H 'Content-type:text/xml; charset=utf-8'
curl -S -s http://localhost:8983/solr/ucjeps-public/update --data '<optimize/>' -H 'Content-type:text/xml; charset=utf-8'
