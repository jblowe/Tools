TENANT=$1
HOSTNAME="dba-postgres-prod-45.ist.berkeley.edu port=5307 sslmode=prefer"
USERNAME="nuxeo_${TENANT}"
DATABASE="${TENANT}_domain_${TENANT}"
CONNECTSTRING="host=$HOSTNAME dbname=$DATABASE"
psql -U $USERNAME -d "$CONNECTSTRING" -f checkstatus.sql
