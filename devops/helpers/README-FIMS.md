FIMS2CSPACE: a prototype "loader" of FIMS data in CollectionSpace

This software suite takes as input the URL of a dataset (or a download of that URL) that has been uploaded to FIMS,

e.g.

http://data.biscicol.org/ds/data?graph=urn:uuid:9c8edd22-72e8-47b6-bb9a-bbf92bafdfbb

...and loads the data as collection objects into CollectionSpace (ucjeps-dev)

Specifically the suite does the following:

* Pulls down the dataset as RDF
* Extracts the fields from the RDF as a .csv file (with 3 columns)
* Loads the .csv file into CSpace, according to specified parameters
* Provides a means to delete the records loaded (convenient for testing and correcting)

Some notes:

The "pulling and extracting" is pretty much of a hack. There is a nice python tool for ripping RDF files
called rdfxml.py (http://infomesh.net/2003/rdfparser/) and the default invocation merely outputs the
attributes of an RDF resource as 3 tab-separated columns. This is easier to understand by studying an example
than by explaining so please refer to the example below.

The result of the 1st step of "pulling and extracting" is then passed through a PERL one-liner to do a bit of cleanup
and the result is loaded in to CSpace using a Python script written for the purpose.

This script is a bit complicated: it first reads the input .csv file, an XML template for the UCJEPS collectionobject,
a configuration file containing CSpace server details. It then substitutes the input values into the template and
performs an HTTP PUT to the configured CollectionSpace server.  It outputs a trace of its action in the
form of a three column file with the objectNumber, CSID of the created record, and elapsed time for the
operation.

Among the many simplifications and shortcomings of the program are the following:

* No attempt is made to validate any of the data.
* If a record fails to load, the program attempts to continue. The only evidence that the record failed
  is that the objectNumber will have no CSID in the output trace file.
* At some point the massaging done via rdfxml.py and the one liners should be incorporated into
  loadCSpace.py -- there is no reason all the processing, soup-to-nuts, cannot be done in the one
  script.
* The loadCspace.py script currently reads a "mapping file", but does nothing with it. The idea is (was)
  that this file would provide all the info needed to map the input fields to CSpace, and no
  template would be required. However, for now, for simplicity, the user must provided an XML template
  (the one supplied is called collectionobject.xml) with appropriate content for the data being processed.
* The loadCspace.py script expects a particular 3-column .csv format that was easily extracted
  from the RDF resource; it may be more useful to have it accept a more conventional "spreadsheet"-type
  data layout, or to read native Excel files. Many integration details and use cases remain to be
  considered!
* The code handles a number of types of exceptions, but many remain to be handled. In particular, when the
  POSTing of a record to CSpace fails, there is little indication of the specific problem: "Error 500" is
  returned and the user will usually have to log in to the server and look at the tomcat logs to see
  what happened.

Here's an annotated "run" based on sample RDF data available at the time of writing. YMMV!

$ ./rdfxml.py http://data.biscicol.org/ds/data?graph=urn:uuid:9c8edd22-72e8-47b6-bb9a-bbf92bafdfbb > extracted.csv
# or, if you have already snagged the RDF resource
$ ./rdfxml.py data.rdf > extracted.csv

# the first few "lines" of the RDF resource...
$ head -15 data.rdf 
<rdf:RDF
    xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#"
    xmlns:j.0="urn:"
    xmlns:rdfs="http://www.w3.org/2000/01/rdf-schema#" > 
  <rdf:Description rdf:about="ark:/21547/aR2344">
    <rdf:type rdf:resource="http://www.w3.org/2000/01/rdf-schema#Resource"/>
    <j.0:locality>Di Giorgio Road. Near Driveway for House #811.</j.0:locality>
    <j.0:habitat>In coarse sand along road passing through grapefruit orchard.</j.0:habitat>
    <j.0:county>San Diego</j.0:county>
    <j.0:country>USA</j.0:country>
    <j.0:stateprovince>CA</j.0:stateprovince>
    <j.0:coll_date>2010-02-14</j.0:coll_date>
    <j.0:coll_year>2010</j.0:coll_year>
    <j.0:elevation>714</j.0:elevation>
    <j.0:coll_day>14</j.0:coll_day>

# ... the results of "extracting" the content
$ head -10 extracted.csv 
<ark:/21547/aR2344> <http://www.w3.org/1999/02/22-rdf-syntax-ns#type> <http://www.w3.org/2000/01/rdf-schema#Resource> .
<ark:/21547/aR2344> <urn:locality> "Di Giorgio Road. Near Driveway for House #811." .
<ark:/21547/aR2344> <urn:habitat> "In coarse sand along road passing through grapefruit orchard." .
<ark:/21547/aR2344> <urn:county> "San Diego" .
<ark:/21547/aR2344> <urn:country> "USA" .
<ark:/21547/aR2344> <urn:stateprovince> "CA" .
<ark:/21547/aR2344> <urn:coll_date> "2010-02-14" .
<ark:/21547/aR2344> <urn:coll_year> "2010" .
<ark:/21547/aR2344> <urn:elevation> "714" .
<ark:/21547/aR2344> <urn:coll_day> "14" .

# concordance of the 27 fields extracted from this RDF resource
$ perl -pe "s/^.*?urn:(.*?)>.*/\1/" extracted.csv | grep -v "<ark:" | sort | uniq -c

 145 all_collectors
 145 barcodenumber
  53 brief_desc
 145 coll_date
 145 coll_day
 145 coll_month
 145 coll_num
 145 coll_year
  63 comments
 145 coordinate_source
 145 country
 145 county
 145 det_day
 145 det_month
 145 det_year
 145 determinedby
 145 elevation
 145 elevation_units
 100 habitat
   2 label_footer
 145 label_header
 145 latitude
 145 locality
 145 longitude
 145 main_collector
 145 scientificname
 145 stateprovince

# one line PERL hack to make 3 tab-delimited columns...
 $ perl -pe 's/^<(.*?)> <urn:(.*?)> "(.*?)" +./\1\t\2\t\3/' extracted.csv | perl -ne "print unless /^</"  > 3cols.csv

# ... here's the result
 $ head -10 3cols.csv

ark:/21547/aR2344	locality	Di Giorgio Road. Near Driveway for House #811.
ark:/21547/aR2344	habitat	In coarse sand along road passing through grapefruit orchard.
ark:/21547/aR2344	county	San Diego
ark:/21547/aR2344	country	USA
ark:/21547/aR2344	stateprovince	CA
ark:/21547/aR2344	coll_date	2010-02-14
ark:/21547/aR2344	coll_year	2010
ark:/21547/aR2344	elevation	714
ark:/21547/aR2344	coll_day	14
ark:/21547/aR2344	scientificname	Tiquilia plicata (Torr.) A. T. Richardson

# OK, now we can load this into CSpace
$ python loadCspace.py 3cols.csv ucjeps_Fims2Cspace_Dev.cfg FIMS2CSpaceMapping.csv collectionobject.xml 3cols-results.csv
********************************************************************************
FIMS2CSPACE: input  file:    3cols.csv
FIMS2CSPACE: config file:    ucjeps_Fims2Cspace_Dev.cfg
FIMS2CSPACE: mapping file:   FIMS2CSpaceMapping.csv
FIMS2CSPACE: template:       collectionobject.xml
FIMS2CSPACE: output file:    3cols-results.csv
********************************************************************************
FIMS2CSPACE: 3499 lines and 143 records found in file 3cols.csv
********************************************************************************
FIMS2CSPACE: hostname        ucjeps-dev.cspace.berkeley.edu
FIMS2CSPACE: institution     ucjeps
********************************************************************************
FIMS2CSPACE: 27 lines and 27 records found in file FIMS2CSpaceMapping.csv
********************************************************************************
FIMS2CSPACE: 143 records processed, 143 successful PUTs
********************************************************************************

# ... and if we want to get rid of all this, we can just delete the records.
$ cut -f2 3cols-results.csv > toDelete.csv
$ nohup ./delete-multiple.sh collectionobjects toDelete.csv &

# here's the 3-line script, ready to run...
./rdfxml.py http://data.biscicol.org/ds/data?graph=urn:uuid:9c8edd22-72e8-47b6-bb9a-bbf92bafdfbb > extracted.csv
perl -pe 's/^<(.*?)> <urn:(.*?)> "(.*?)" +./\1\t\2\t\3/' extracted.csv | perl -ne "print unless /^</"  > 3cols.csv
python loadCspace.py 3cols.csv ucjeps_Fims2Cspace_Dev.cfg FIMS2CSpaceMapping.csv collectionobject.xml 3cols-results.csv

# to undo what you just did, do the following:
#
# 1. setup the environment vars so the scripts can run.
source set-config-ucjeps-dev.sh
# 2. make a list of just the CSIDS
cut -f2 3cols-results.csv > toDelete.csv
# 3. feed these to the delete script
nohup ./delete-multiple.sh collectionobjects toDelete.csv &
# 4. cleanup after...
rm nohup.out toDelete.csv extracted.csv 3col*.csv

# a collectionobject on dev...just for easy reference
https://ucjeps-dev.cspace.berkeley.edu/cspace-services/collectionobjects/bb8ccf9e-dfe5-4747-b156-5a5a54a07785

# to upload a single column list of orgauthorities:
python loadGeneric.py algaeNON1-collectors_to_add.txt ucjeps_DWC2Cspace_Dev.cfg OrgauthoritiesMapping.csv orgauthorities-template.xml orgauthorities-results.csv
