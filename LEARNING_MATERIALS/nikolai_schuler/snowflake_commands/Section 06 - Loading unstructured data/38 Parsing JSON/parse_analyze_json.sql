-- =============================================================================
-- SECTION 6.38: PARSING AND ANALYZING JSON DATA (JSON Part 2 of 5)
-- =============================================================================
--
-- OBJECTIVE:
--   Learn how to query JSON stored in VARIANT columns using colon notation,
--   type casting, and multi-field selection.
--
-- WHAT YOU WILL LEARN:
--   1. Colon notation (:) to access top-level JSON keys
--   2. $1:key as alternative syntax from staged data
--   3. Type casting with ::STRING, ::INT for proper data types
--   4. Selecting multiple JSON attributes into a structured result
--
-- JSON ACCESS SYNTAX:
--   column_name:key         -> Access top-level key from a table column
--   $1:key                  -> Access top-level key from staged file ($1 = first column)
--   column_name['key']      -> Bracket notation (same as colon notation)
--   column_name:"Key Name"  -> Quoted key for case-sensitive or special chars
--
-- KEY INTERVIEW CONCEPTS:
--   - Colon notation: RAW_FILE:key to access JSON fields
--   - $1:key as alternative for positional + key access
--   - ::STRING, ::INT, ::FLOAT, ::BOOLEAN for type casting
--   - Without casting, values remain as VARIANT type
--   - VARIANT comparisons and joins may not work as expected
--
-- TYPE CASTING IMPORTANCE (CONCEPT GAP FILLED):
--   Without ::TYPE, all values are VARIANT. This matters because:
--   - VARIANT sorts differently than native types
--   - JOIN conditions on VARIANT may miss matches
--   - Aggregations (SUM, AVG) require numeric types
--   - String functions may not work directly on VARIANT
--   Always cast to the appropriate type for reliable operations.
-- =============================================================================


-- =============================================
-- STEP 1: Access a single JSON attribute
-- =============================================
-- Use column_name:key to access a top-level JSON field.
-- Result type is VARIANT (not STRING).

SELECT RAW_FILE:city FROM OUR_FIRST_DB.PUBLIC.JSON_RAW;

-- Alternative: Use $1 positional notation (refers to first column in table)
SELECT $1:first_name FROM OUR_FIRST_DB.PUBLIC.JSON_RAW;

-- INTERVIEW TIP: $1 notation works because JSON_RAW has only one column.
-- $1 always refers to the first column of the table.
-- In a multi-column table, use the actual column name instead.


-- =============================================
-- STEP 2: Type casting for proper data types
-- =============================================
-- Cast VARIANT to STRING for clean text output (removes quotes).

SELECT RAW_FILE:first_name::STRING AS first_name
FROM OUR_FIRST_DB.PUBLIC.JSON_RAW;
-- Without ::STRING: "Alice" (with quotes, VARIANT type)
-- With ::STRING:    Alice   (no quotes, VARCHAR type)

-- Cast to INT for numeric values
SELECT RAW_FILE:id::INT AS id
FROM OUR_FIRST_DB.PUBLIC.JSON_RAW;
-- Without ::INT: 1 (VARIANT type, not usable in math)
-- With ::INT:    1 (NUMBER type, supports arithmetic and aggregations)


-- =============================================
-- STEP 3: Select multiple fields with casting
-- =============================================
-- Build a structured result set from JSON data.

SELECT
    RAW_FILE:id::INT           AS id,
    RAW_FILE:first_name::STRING AS first_name,
    RAW_FILE:last_name::STRING  AS last_name,
    RAW_FILE:gender::STRING     AS gender
FROM OUR_FIRST_DB.PUBLIC.JSON_RAW;

-- This query produces a clean, tabular result that looks like
-- a regular structured table. Each JSON key maps to a named column.


-- =============================================
-- STEP 4: Accessing nested objects (preview)
-- =============================================
-- JSON can contain nested objects (objects within objects).
-- This returns the entire nested object as VARIANT.

SELECT RAW_FILE:job AS job
FROM OUR_FIRST_DB.PUBLIC.JSON_RAW;

-- Output: {"salary": 65000, "title": "Financial Analyst"}
-- This is a nested JSON object. See Section 6.39 for dot notation access.


-- =============================================================================
-- CONCEPT GAP: ALL JSON ACCESS PATTERNS
-- =============================================================================
-- ┌───────────────────────────────┬─────────────────────────────────────────┐
-- │ Syntax                        │ Use Case                               │
-- ├───────────────────────────────┼─────────────────────────────────────────┤
-- │ col:key                       │ Top-level key access                   │
-- │ col:key::TYPE                 │ Top-level key with type casting        │
-- │ col:key.subkey                │ Nested object access (dot notation)    │
-- │ col:key[0]                    │ Array element access (0-based index)   │
-- │ col:key[0].subkey             │ Array element's nested field           │
-- │ col['key']                    │ Bracket notation (same as colon)       │
-- │ col:"Key With Spaces"         │ Keys with spaces or special characters │
-- │ col:"CaseSensitiveKey"        │ Case-sensitive key access              │
-- └───────────────────────────────┴─────────────────────────────────────────┘
--
-- COMMON TYPE CASTS:
--   ::STRING   / ::VARCHAR  - Text values
--   ::INT      / ::INTEGER  - Whole numbers
--   ::FLOAT    / ::DOUBLE   - Decimal numbers
--   ::NUMBER(p,s)           - Fixed-precision numbers
--   ::BOOLEAN               - true/false values
--   ::DATE                  - Date values
--   ::TIMESTAMP             - Timestamp values
--   ::ARRAY                 - JSON arrays
--   ::OBJECT                - JSON objects
--
-- INTERVIEW TIP: JSON keys in Snowflake are CASE-SENSITIVE.
-- RAW_FILE:City and RAW_FILE:city are DIFFERENT keys.
-- Use exact case matching or quote the key name.
-- =============================================================================
