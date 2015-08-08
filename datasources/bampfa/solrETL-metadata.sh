#!/bin/bash -x
date
cd /home/developers/bampfa
TENANT=$1
export NUMCOLS=38
USERNAME="reporter_bampfa"
DATABASE=bampfa_domain_bampfa
CONNECTSTRING="host=$TENANT.cspace.berkeley.edu dbname=$DATABASE"
##############################################################################
# extract metadata and media info from CSpace
##############################################################################
# NB: unlike the other ETL processes, we're still using the default | delimiter here
##############################################################################
time psql -R"@@" -A -U $USERNAME -d "$CONNECTSTRING"  -f metadata.sql -o d1.csv
# some fix up required, alas: data from cspace is dirty: contain csv delimiters, newlines, etc. that's why we used @@ as temporary record separator
time perl -pe 's/[\r\n]/ /g;s/\@\@/\n/g' d1.csv > d3.csv 
time perl -ne " \$x = \$_ ;s/[^\|]//g; if     (length eq \$ENV{NUMCOLS}) { print \$x;}" d3.csv > metadata.csv
time perl -ne " \$x = \$_ ;s/[^\|]//g; unless (length eq \$ENV{NUMCOLS}) { print \$x;}" d3.csv > errors.csv &
time psql -R"@@" -A -U $USERNAME -d "$CONNECTSTRING" -f media.sql -o m1.csv
time perl -pe 's/[\r\n]/ /g;s/\@\@/\n/g' m1.csv > media.csv 
# make the header
head -1 metadata.csv > header4Solr.csv
# add the blob field name to the header (the header already ends with a tab); rewrite objectcsid_s to id (for solr id...)
perl -i -pe 's/\|/_s\|/g;s/objectcsid_s/id/;s/$/_s|blob_ss/' header4Solr.csv
# add the blobcsids to the rest of the data
time perl mergeObjectsAndMedia.pl > d6.csv
# we want to use our "special" solr-friendly header.
tail -n +2 d6.csv > d7.csv
cat header4Solr.csv d7.csv > 4solr.$TENANT.metadata.csv
#rm d6.csv d7.csv m1.csv d1.csv d3.csv
wc -l *.csv
# clear out the existing data
curl -S -s "http://localhost:8983/solr/${TENANT}-metadata/update" --data '<delete><query>*:*</query></delete>' -H 'Content-type:text/xml; charset=utf-8'
curl -S -s "http://localhost:8983/solr/${TENANT}-metadata/update" --data '<commit/>' -H 'Content-type:text/xml; charset=utf-8'
time curl -S -s "http://localhost:8983/solr/${TENANT}-metadata/update/csv?commit=true&header=true&trim=true&separator=%7C&f.othernumbers_ss.split=true&f.othernumbers_ss.separator=;&f.blob_ss.split=true&f.blob_ss.separator=,&encapsulator=\\" --data-binary @4solr.$TENANT.metadata.csv -H 'Content-type:text/plain; charset=utf-8'
#
rm 4solr*.csv.gz
gzip 4solr.*.csv
#
date