/* Use of Collections Data Migration from Version 5.0

-- This SQL script migrates existing Use of Collections data from Version 5.0 to incorporate new features developed by the UCB CSpace team, based on the following assumptions:

	-- The appropriate database is specified in executing this script.
	   This script does not contain commands to connect to the appropriate database.

	-- New database changes have been made: e.g. new tables created, foreign keys added.

	-- New records should not exist in newly created tables.
	   But, since this script may possibly be run repeatedly, it checks for data in the new tables
           and it only creates a new record if the record has not yet been migrated.

	-- The uuid_generate_v4() function is required to generate UUID for new records.
	   Installing the uuid-ossp extension will make all UUID generation functions available.
	   This script creates and uses the uuid_generate_v4() function to generate a version 4 UUID.

           -- To install the uuid-ossp extension and make all the UUID functions available:
 		CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

	   -- To only install the uuid_generate_v4() function to generate Type 4 UUIDs:
		CREATE OR REPLACE FUNCTION public.uuid_generate_v4()
		  RETURNS uuid
		  LANGUAGE c
		  PARALLEL SAFE STRICT
		AS '$libdir/uuid-ossp', $function$uuid_generate_v4$function$;

	-- Once existing data has been migrated, this script does not delete data from,
           nor drop the newly obsolete columns.

-- Version 5.0 Use of Collections tables:
	
	public.uoc_common ============> MIGRATION NEEDED: various fields updated to repeatable fields/groups.
	public.uoc_common_methodlist => NO MIGRATION NEEDED.
	public.usergroup =============> NO MIGRATION NEEDED, although 3 new fields were added to the table.
	
-- Version 5.0 uoc_common table description and migration note:
	
	                            Table "public.uoc_common"
	      Column       |            Type             | Nullable | Migrate To
	-------------------+-----------------------------+----------+------------------------
	 id                | character varying(36)       | not null |
	 enddate           | timestamp without time zone |          |
	 location          | character varying           |          | uoc_common_locationlist
	 authorizationdate | timestamp without time zone |          | authorizationgroup
	 title             | character varying           |          |
	 note              | character varying           |          |
	 provisos          | character varying           |          |
	 result            | character varying           |          |
	 referencenumber   | character varying           |          |
	 authorizationnote | character varying           |          | authorizationgroup
	 authorizedby      | character varying           |          | authorizationgroup
	 startsingledate   | timestamp without time zone |          | usedategroup
	Indexes:
	    "uoc_common_pk" PRIMARY KEY, btree (id)
	Foreign-key constraints:
	    "uoc_common_id_hierarchy_fk" FOREIGN KEY (id) REFERENCES hierarchy(id) ON DELETE CASCADE
	
-- NO CHANGES are required for the following uoc_common columns:
	
	uoc_common.id
	uoc_common.enddate
	uoc_common.title
	uoc_common.note
	uoc_common.provisos
	uoc_common.result
	uoc_common.referencenumber
	
-- REPEATABLE FIELDS: The following uoc_common columns are now repeatable fields; migration path:
	
	uoc_common.location ==========> uoc_common_locationlist.item
	uoc_common.authorizationdate => authorizationgroup.authorizationdate
	uoc_common.authorizationnote => authorizationgroup.authorizationnote
	uoc_common.authorizedby ======> authorizationgroup.authorizedby
	uoc_common.startsingledate ===> usedategroup.usedate

*/


-- 1) Create function uuid_generate_v4() for generating UUID before migration:

CREATE OR REPLACE FUNCTION public.uuid_generate_v4()
 RETURNS uuid
 LANGUAGE c
 PARALLEL SAFE STRICT
AS '$libdir/uuid-ossp', $function$uuid_generate_v4$function$
	

/* 2) Migrate v5.0 UOC Location data to uoc_common_locationlist table:

-- NEW uoc_common_locationlist table description:
	
	   Table "public.uoc_common_locationlist"
	 Column |         Type          | Modifiers 
	--------+-----------------------+-----------
	 id     | character varying(36) | not null
	 pos    | integer               | 
	 item   | character varying     | 
	Indexes:
	    "uoc_common_locationlist_id_idx" btree (id)
	Foreign-key constraints:
	    "uoc_common_locationlist_id_hierarchy_fk" FOREIGN KEY (id) REFERENCES hierarchy(id) ON DELETE CASCADE

-- Migration path for uoc_common.location:

	uoc_common.id ========> uoc_common_locationlist.id
	0 or next pos value ==> uoc_common_locationlist.pos
	uoc_common.location ==> uoc_common_locationlist.item

-- Only add a new record to uoc_common_locationlist when there is a value for location; do not create empty records.
-- Only add the record if it does NOT already exist.
-- In the case of a new install, check for the uoc_common.location column and do nothing if it does not exist.

*/

-- Insert a new record into uoc_common_locationlist table.

DO $$
DECLARE
    trow record;
    maxpos int;
BEGIN
    -- For new install, if uoc_common.location does not exist, there is nothing to migrate.

    IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='uoc_common' AND column_name='location') THEN
        FOR trow IN
            -- Get record in uoc_common that does not have an existing/matching record in uoc_common_locationlist:

            SELECT uc.id, uc.location
            FROM public.uoc_common uc
            LEFT OUTER JOIN public.uoc_common_locationlist ucll ON (uc.id = ucll.id AND uc.location != ucll.item)
            WHERE uc.location IS NOT NULL AND uc.location != '' AND ucll.item IS NULL  

            LOOP
                -- Get max pos value for the UOC record's Location field, and generate a new uuid:

                SELECT coalesce(max(pos), -1) INTO maxpos
                FROM public.uoc_common_locationlist
                WHERE id = trow.id;

                -- Migrate uoc_common Location data to uoc_common_locationlist table:

                INSERT INTO public.uoc_common_locationlist (id, pos, item)
                VALUES (trow.id, maxpos + 1, trow.location);

            END LOOP;

    ELSE
        RAISE NOTICE 'No v5.0 UOC data to migrate: uoc_common.location DOES NOT EXIST';

    END IF;
END
$$;


/* 3) Migrate v5.0 UOC Authorization data to authorizationgroup table:

-- NEW authorizationgroup table description:

	               Table "public.authorizationgroup"
	       Column        |            Type             | Modifiers 
	---------------------+-----------------------------+-----------
	 id                  | character varying(36)       | not null
	 authorizationnote   | character varying           | 
	 authorizedby        | character varying           | 
	 authorizationdate   | timestamp without time zone | 
	 authorizationstatus | character varying           | 
	Indexes:
	    "authorizationgroup_pk" PRIMARY KEY, btree (id)
	Foreign-key constraints:
	    "authorizationgroup_id_hierarchy_fk" FOREIGN KEY (id) REFERENCES hierarchy(id) ON DELETE CASCADE

-- Migrate/add data from uoc_common to hierarchy.
-- The foreign key on the authorizationgroup table requires first adding new records to hierarchy.
-- Use the uuid_generate_v4() function to generate a new type 4 UUID for the new record.

	uuid_generate_v4()::varchar AS id ====> hierarchy.id
	uoc_common.id ========================> hierarchy.parentid
	0 ====================================> hierarchy.pos
	'uoc_common:authorizationGroupList' ==> hierarchy.name
	True =================================> hierarchy.isproperty
	'authorizationGroup' =================> hierarchy.primarytype

-- Migrate data from uoc_common to authorizationgroup:
-- Only add a new record when there is a value for authorizationdate, authorizationnote, or authorizedby.
-- Do not create empty records in authorizationgroup.

	hierarchy.id ==> authorizationgroup.id
	uoc_common.authorizationdate =======> authorizationgroup.authorizationdate
	uoc_common.authorizationnote =======> authorizationgroup.authorizationnote
	uoc_common.authorizedby ============> authorizationgroup.authorizedby

*/

-- Migrate/add Authorization data to hierarchy, authorizationgroup tables.

DO $$
DECLARE
    trow record;
    maxpos int;
    agid varchar(36);
BEGIN

    -- For new install, if uoc_common.authorizedby does not exist, there is nothing to migrate.

    IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='uoc_common' AND column_name='authorizedby') THEN
        FOR trow IN
            -- Get record in uoc_common that does not have an existing/matching record in authorizationgroup:
            -- Only need to match the uoc_common.id as there is only one data set per UOC record.
            -- Verify that there is data to migrate.

            SELECT id AS parentid, authorizedby, authorizationdate, authorizationnote 
            FROM public.uoc_common 
            WHERE id not in (
                SELECT uc.id
                FROM public.uoc_common uc
                JOIN public.hierarchy h ON (uc.id = h.parentid)
                JOIN public.authorizationgroup ag ON (
                    h.id = ag.id
                    AND uc.authorizedby IS NOT DISTINCT FROM ag.authorizedby
                    AND uc.authorizationdate IS NOT DISTINCT FROM ag.authorizationdate
                    AND uc.authorizationnote IS NOT DISTINCT FROM ag.authorizationnote
                )
            )
            AND (authorizedby IS NOT NULL OR authorizationdate IS NOT NULL OR authorizationnote IS NOT NULL)

            LOOP
                -- Get max pos value for the UOC record's Authorization group, and generate a new uuid:

                SELECT
                    coalesce(max(pos), -1),
                    uuid_generate_v4()::varchar
                INTO
                    maxpos,
                    agid
                FROM public.hierarchy
                WHERE parentid = trow.parentid
                AND primarytype = 'authorizationGroup';

                -- Insert new record into hierarchy table first, due to foreign key on authorizationgroup table:

                INSERT INTO public.hierarchy (
                    id,
                    parentid,
                    pos,
                    name,
                    isproperty,
                    primarytype)
                VALUES (
                    agid,
                    trow.parentid,
                    maxpos + 1,
                    'uoc_common:authorizationGroupList',
                    true,
                    'authorizationGroup');

                -- Migrate uoc_common Authorization data into authorizationgroup table:

                INSERT INTO public.authorizationgroup (
                    id, 
                    authorizedby,
                    authorizationdate, 
                    authorizationnote)
                VALUES ( 
                    agid,
                    trow.authorizedby,
                    trow.authorizationdate, 
                    trow.authorizationnote);

            END LOOP;

    ELSE
        RAISE NOTICE 'No v5.0 UOC data to migrate: uoc_common.authorizedby DOES NOT EXIST';

    END IF;
END
$$;


/* 4) Migrate v5.0 UOC Start/single date data to usedategroup table:
	
-- NEW usedategroup table description:

	                    Table "public.usedategroup"
	         Column          |            Type             | Modifiers 
	-------------------------+-----------------------------+-----------
	 id                      | character varying(36)       | not null
	 usedate                 | timestamp without time zone | 
	 usedatenumberofvisitors | bigint                      | 
	 usedatevisitornote      | character varying           | 
	 usedatehoursspent       | double precision            | 
	 usedatetimenote         | character varying           | 
	Indexes:
	    "usedategroup_pk" PRIMARY KEY, btree (id)
	Foreign-key constraints:
	    "usedategroup_id_hierarchy_fk" FOREIGN KEY (id) REFERENCES hierarchy(id) ON DELETE CASCADE

-- Migrate/add data from uoc_common to hierarchy.
-- The foreign key on the usedategroup table requires first adding new records to hierarchy.
-- Use the uuid_generate_v4() function to generate a new type 4 UUID for the new record.

	uuid_generate_v4()::varchar AS id ====> hierarchy.id
	uoc_common.id ========================> hierarchy.parentid
	0 ====================================> hierarchy.pos
	'uoc_common:useDateGroupList' ========> hierarchy.name
	True =================================> hierarchy.isproperty
	'useDateGroup' =======================> hierarchy.primarytype

-- Migrate data from uoc_common to usedategroup.
-- Only add a new record when there is a value for startsingledate.
-- Do not create empty records in usedategroup.

	hierarchy.id ==> usedategroup.id
	uoc_common.startsingledate =========> usedategroup.usedate

*/

-- Migrate/add Start/single datA data to hierarchy, usedategroup tables.

DO $$
DECLARE
    trow record;
    maxpos int;
    udgid varchar(36);
BEGIN

    -- For new install, if uoc_common.startsingledate does not exist, there is nothing to migrate.

    IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='uoc_common' AND column_name='startsingledate') THEN
        FOR trow IN
            -- Get record in uoc_common that does not have an existing/matching record in usedategroup.
            -- Only need to match the uoc_common.id as there is only one data set per UOC record.
            -- Verify that there is data to migrate.

            SELECT id AS parentid, startsingledate AS usedate
            FROM public.uoc_common
            WHERE id NOT IN (
                SELECT uc.id
                FROM public.uoc_common uc
                JOIN public.hierarchy h ON (uc.id = h.parentid)
                JOIN public.usedategroup udg ON (
                    h.id = udg.id
                    AND uc.startsingledate IS NOT DISTINCT FROM udg.usedate
                )
            )
            AND startsingledate IS NOT NULL

            LOOP
                -- Get max pos value for the UOC record's Use Date group, and generate a new uuid:

                SELECT
                    coalesce(max(pos), -1),
                    uuid_generate_v4()::varchar
                INTO
                    maxpos,
                    udgid
                FROM public.hierarchy
                WHERE parentid = trow.parentid
                AND primarytype = 'useDateGroup';

                -- Insert new record into hierarchy table first, due to foreign key on usedategroup table:

                INSERT INTO public.hierarchy (
                    id,
                    parentid,
                    pos,
                    name,
                    isproperty,
                    primarytype)
                VALUES (
                    udgid,
                    trow.parentid,
                    maxpos + 1,
                    'uoc_common:useDateGroupList',
                    true,
                    'useDateGroup');

                -- Insert new record into authorizationgroup table:

                INSERT INTO public.usedategroup (
                    id, 
                    usedate)
                VALUES ( 
                    udgid,
                    trow.usedate);

            END LOOP;

    ELSE
        RAISE NOTICE 'No v5.0 UOC data to migrate: uoc_common.startsingledate DOES NOT EXIST';

    END IF;
END
$$;

-- END OF MIGRATION
