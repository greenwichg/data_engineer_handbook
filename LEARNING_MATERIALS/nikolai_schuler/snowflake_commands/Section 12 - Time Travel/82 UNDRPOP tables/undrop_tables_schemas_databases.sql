-- =============================================================================
-- SECTION 12.82: UNDROP TABLES, SCHEMAS, AND DATABASES
-- =============================================================================
--
-- OBJECTIVE:
--   Learn how to recover dropped tables, schemas, and databases using
--   the UNDROP command within the data retention period.
--
-- WHAT YOU WILL LEARN:
--   1. How UNDROP works for tables, schemas, and databases
--   2. The naming conflict scenario and how to handle it
--   3. Retention period rules for different object types
--   4. The relationship between CREATE OR REPLACE and UNDROP
--
-- UNDROP SUPPORT BY OBJECT TYPE:
-- ┌──────────────────────┬──────────────────────────────────────────────────┐
-- │ Object Type          │ UNDROP Command                                   │
-- ├──────────────────────┼──────────────────────────────────────────────────┤
-- │ Table                │ UNDROP TABLE <db>.<schema>.<table>               │
-- │ Schema               │ UNDROP SCHEMA <db>.<schema>                      │
-- │ Database             │ UNDROP DATABASE <db>                             │
-- └──────────────────────┴──────────────────────────────────────────────────┘
--
-- RETENTION PERIOD BY TABLE TYPE (INTERVIEW TOPIC):
-- ┌──────────────────────┬────────────────┬──────────────────────────────────┐
-- │ Table Type           │ Min Retention  │ Max Retention                    │
-- ├──────────────────────┼────────────────┼──────────────────────────────────┤
-- │ Permanent            │ 0 days         │ 90 days (Enterprise Edition)     │
-- │ Transient            │ 0 days         │ 1 day                            │
-- │ Temporary            │ 0 days         │ 1 day                            │
-- └──────────────────────┴────────────────┴──────────────────────────────────┘
--
-- KEY INTERVIEW CONCEPTS:
--   - UNDROP only works within the data retention period
--   - UNDROP fails if an object with the same name already exists
--   - Rename the existing object first, then UNDROP the dropped one
--   - CREATE OR REPLACE implicitly drops the old object — UNDROP can recover it
--   - Dropping a schema/database drops all contained objects (all recoverable)
-- =============================================================================


-- =============================================
-- STEP 1: Set up the test table
-- =============================================
CREATE OR REPLACE STAGE MANAGE_DB.external_stages.time_travel_stage
    URL         = 's3://data-snowflake-fundamentals/time-travel/'
    file_format = MANAGE_DB.file_formats.csv_file;

CREATE OR REPLACE TABLE OUR_FIRST_DB.public.customers (
    id         INT,
    first_name STRING,
    last_name  STRING,
    email      STRING,
    gender     STRING,
    Job        STRING,
    Phone      STRING
);

COPY INTO OUR_FIRST_DB.public.customers
FROM @MANAGE_DB.external_stages.time_travel_stage
FILES = ('customers.csv');

SELECT * FROM OUR_FIRST_DB.public.customers;


-- =============================================
-- STEP 2: UNDROP a table
-- =============================================
-- Drop the table
DROP TABLE OUR_FIRST_DB.public.customers;

-- This will fail — table no longer exists
SELECT * FROM OUR_FIRST_DB.public.customers;

-- Recover the dropped table
UNDROP TABLE OUR_FIRST_DB.public.customers;

-- Table is back with all its data!
SELECT * FROM OUR_FIRST_DB.public.customers;


-- =============================================
-- STEP 3: UNDROP a schema
-- =============================================
-- Dropping a schema drops ALL tables within it
DROP SCHEMA OUR_FIRST_DB.public;

-- This will fail — schema no longer exists
SELECT * FROM OUR_FIRST_DB.public.customers;

-- Recover the entire schema (and all its tables)
UNDROP SCHEMA OUR_FIRST_DB.public;

-- All tables within the schema are restored
SELECT * FROM OUR_FIRST_DB.public.customers;


-- =============================================
-- STEP 4: UNDROP a database
-- =============================================
-- Dropping a database drops ALL schemas and tables within it
DROP DATABASE OUR_FIRST_DB;

-- This will fail — database no longer exists
SELECT * FROM OUR_FIRST_DB.public.customers;

-- Recover the entire database
UNDROP DATABASE OUR_FIRST_DB;

-- Everything is restored (database → schemas → tables)
SELECT * FROM OUR_FIRST_DB.public.customers;


-- =============================================
-- STEP 5: Handling naming conflicts with UNDROP
-- =============================================
-- SCENARIO: You used CREATE OR REPLACE, which dropped the old table
-- and created a new one with the same name. Now UNDROP fails.

-- First, make some changes to the original data
UPDATE OUR_FIRST_DB.public.customers
SET LAST_NAME = 'Tyson';

UPDATE OUR_FIRST_DB.public.customers
SET JOB = 'Data Analyst';

-- CREATE OR REPLACE implicitly drops the old table
CREATE OR REPLACE TABLE OUR_FIRST_DB.public.customers AS
SELECT * FROM OUR_FIRST_DB.public.customers
BEFORE (STATEMENT => '019b9f7c-0500-851b-0043-4d83000762be');

SELECT * FROM OUR_FIRST_DB.public.customers;

-- Try to UNDROP the old table — THIS WILL FAIL!
UNDROP TABLE OUR_FIRST_DB.public.customers;
-- ERROR: Object 'CUSTOMERS' already exists.

-- SOLUTION: Rename the current table, then UNDROP
ALTER TABLE OUR_FIRST_DB.public.customers
RENAME TO OUR_FIRST_DB.public.customers_wrong;

-- Now UNDROP will succeed (name is available)
UNDROP TABLE OUR_FIRST_DB.public.customers;

-- Verify — the original (pre-CREATE OR REPLACE) table is back
DESC TABLE OUR_FIRST_DB.public.customers;


-- =============================================================================
-- CONCEPT GAP: UNDROP BEHAVIOR AND LIMITATIONS
-- =============================================================================
--
-- WHAT UNDROP RESTORES:
--   - All data in the table/schema/database
--   - Table structure (columns, data types, constraints)
--   - Grants and privileges on the object
--   - Time travel history of the object
--
-- WHAT UNDROP CANNOT DO:
--   - Recover objects past the retention period (data is purged)
--   - Recover objects if retention was set to 0 days
--   - Recover if the same name exists (must rename first)
--   - Recover individual rows (use Time Travel SELECT for that)
--
-- UNDROP vs TIME TRAVEL:
-- ┌──────────────────────┬──────────────────────────────────────────────────┐
-- │ UNDROP               │ Time Travel SELECT                               │
-- ├──────────────────────┼──────────────────────────────────────────────────┤
-- │ Recovers DROPPED     │ Recovers MODIFIED/DELETED data                  │
-- │ objects               │ within an existing table                        │
-- │ Restores entire table │ Returns historical rows as a query result       │
-- │ No query ID needed   │ Needs OFFSET, TIMESTAMP, or STATEMENT           │
-- │ One command           │ Requires backup + truncate + insert pattern     │
-- └──────────────────────┴──────────────────────────────────────────────────┘
-- =============================================================================


-- =============================================================================
-- CONCEPT GAP: CREATE OR REPLACE vs DROP + CREATE
-- =============================================================================
-- CREATE OR REPLACE TABLE my_table (...):
--   1. Implicitly DROPS the existing table (if any)
--   2. Creates a brand new table with the same name
--   3. The dropped table CAN be recovered with UNDROP
--      (after renaming the new table)
--   4. The new table has NO time travel history from the old table
--
-- This is why CREATE OR REPLACE is risky for restores:
--   - You lose the old table's time travel
--   - You can still UNDROP the old table, but only within retention
--   - Always prefer TRUNCATE + INSERT for data restoration
-- =============================================================================
