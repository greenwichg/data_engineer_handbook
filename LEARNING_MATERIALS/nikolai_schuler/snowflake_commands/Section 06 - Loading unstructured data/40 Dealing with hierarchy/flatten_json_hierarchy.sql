-- =============================================================================
-- SECTION 6.40: FLATTEN() FOR JSON HIERARCHIES (JSON Part 4 of 5)
-- =============================================================================
--
-- OBJECTIVE:
--   Learn FLATTEN() - the preferred way to dynamically unnest JSON arrays
--   into rows, replacing the manual UNION ALL approach.
--
-- WHAT YOU WILL LEARN:
--   1. Understanding arrays of objects in JSON
--   2. Manual UNION ALL approach (for comparison)
--   3. FLATTEN() to dynamically explode arrays into rows
--   4. Accessing flattened element fields with f.value:key
--
-- JSON STRUCTURE BEING QUERIED:
--   {
--     "first_name": "Alice",
--     "spoken_languages": [                    <-- Array of objects
--       {"language": "English", "level": "A1"},
--       {"language": "French",  "level": "B2"},
--       {"language": "Spanish", "level": "C1"}
--     ]
--   }
--
-- KEY INTERVIEW CONCEPTS:
--   - FLATTEN(input => array) explodes array elements into rows
--   - f.value accesses the current element in the flattened result
--   - f.value:key accesses a field within each array element
--   - Lateral join syntax: FROM table, TABLE(FLATTEN(...)) f
--   - FLATTEN handles variable-length arrays automatically (unlike UNION ALL)
--
-- FLATTEN() OUTPUT COLUMNS (CONCEPT GAP FILLED):
--   SEQ   - Unique sequence number for each input row
--   KEY   - Key name (for objects) or index (for arrays)
--   PATH  - Full path to the element
--   INDEX - Array index (0-based) or NULL for objects
--   VALUE - The actual element value (VARIANT)
--   THIS  - The original input array/object
-- =============================================================================


-- =============================================
-- STEP 1: Explore the array structure
-- =============================================
-- View the spoken_languages array for each person

SELECT
    RAW_FILE:spoken_languages AS spoken_languages
FROM OUR_FIRST_DB.PUBLIC.JSON_RAW;
-- Output: [{"language":"English","level":"A1"},{"language":"French","level":"B2"}, ...]

SELECT * FROM OUR_FIRST_DB.PUBLIC.JSON_RAW;


-- =============================================
-- STEP 2: Check array sizes
-- =============================================
SELECT
    RAW_FILE:first_name::STRING                AS first_name,
    ARRAY_SIZE(RAW_FILE:spoken_languages)       AS num_languages
FROM OUR_FIRST_DB.PUBLIC.JSON_RAW;
-- Shows how many languages each person speaks (varies per person)


-- =============================================
-- STEP 3: Access array elements by index
-- =============================================
-- Access the first language object
SELECT
    RAW_FILE:spoken_languages[0] AS first_language
FROM OUR_FIRST_DB.PUBLIC.JSON_RAW;
-- Output: {"language":"English","level":"A1"}

-- Access nested fields within the array element
SELECT
    RAW_FILE:first_name::STRING                          AS first_name,
    RAW_FILE:spoken_languages[0].language::STRING         AS first_language,
    RAW_FILE:spoken_languages[0].level::STRING            AS level_spoken
FROM OUR_FIRST_DB.PUBLIC.JSON_RAW;

-- SYNTAX: col:array[index].nested_key::TYPE
-- Combines array indexing ([0]) with dot notation (.language)


-- =============================================
-- STEP 4: Manual UNION ALL approach (DON'T use in production)
-- =============================================
-- This works but is fragile: you must know the max array size.

SELECT
    RAW_FILE:id::INT AS id,
    RAW_FILE:first_name::STRING AS first_name,
    RAW_FILE:spoken_languages[0].language::STRING AS language,
    RAW_FILE:spoken_languages[0].level::STRING    AS level_spoken
FROM OUR_FIRST_DB.PUBLIC.JSON_RAW

UNION ALL

SELECT
    RAW_FILE:id::INT AS id,
    RAW_FILE:first_name::STRING AS first_name,
    RAW_FILE:spoken_languages[1].language::STRING AS language,
    RAW_FILE:spoken_languages[1].level::STRING    AS level_spoken
FROM OUR_FIRST_DB.PUBLIC.JSON_RAW

UNION ALL

SELECT
    RAW_FILE:id::INT AS id,
    RAW_FILE:first_name::STRING AS first_name,
    RAW_FILE:spoken_languages[2].language::STRING AS language,
    RAW_FILE:spoken_languages[2].level::STRING    AS level_spoken
FROM OUR_FIRST_DB.PUBLIC.JSON_RAW

ORDER BY id;

-- PROBLEMS WITH THIS APPROACH:
-- 1. What if someone speaks 4 languages? You'd miss the 4th.
-- 2. What if someone speaks only 1? You get NULL rows for [1] and [2].
-- 3. Must manually maintain the number of UNION ALL blocks.


-- =============================================
-- STEP 5: FLATTEN() - The correct approach
-- =============================================
-- FLATTEN() dynamically unnests ANY array, regardless of size.
-- It uses a lateral join: each array element generates one output row.

SELECT
    RAW_FILE:first_name::STRING  AS first_name,
    f.value:language::STRING     AS language,        -- Access field in each element
    f.value:level::STRING        AS level_spoken     -- Access field in each element
FROM OUR_FIRST_DB.PUBLIC.JSON_RAW,
     TABLE(FLATTEN(RAW_FILE:spoken_languages)) f;

-- HOW IT WORKS:
--   1. For each row in JSON_RAW, FLATTEN() takes the spoken_languages array
--   2. Creates one output row per array element
--   3. 'f' is the alias for the flattened result
--   4. 'f.value' contains the current array element (a JSON object here)
--   5. 'f.value:language' accesses the "language" key within that element

-- INTERVIEW TIP: FLATTEN is essentially a LATERAL JOIN in SQL.
-- The comma between the table and TABLE(FLATTEN(...)) is implicit CROSS JOIN.
-- Equivalent explicit syntax:
--   FROM JSON_RAW
--   CROSS JOIN LATERAL TABLE(FLATTEN(input => RAW_FILE:spoken_languages)) f


-- =============================================================================
-- CONCEPT GAP: ADVANCED FLATTEN() USAGE
-- =============================================================================
-- 1. FLATTEN with PATH for deeply nested arrays:
--    TABLE(FLATTEN(input => col:level1.level2.array_field)) f
--
-- 2. FLATTEN with MODE for objects (not just arrays):
--    TABLE(FLATTEN(input => col:some_object, MODE => 'OBJECT')) f
--    -- f.key = object key name, f.value = object value
--
-- 3. RECURSIVE FLATTEN for deeply nested structures:
--    TABLE(FLATTEN(input => col:nested, RECURSIVE => TRUE)) f
--    -- Flattens ALL levels of nesting
--
-- 4. FLATTEN with OUTER => TRUE (keep rows with empty/null arrays):
--    TABLE(FLATTEN(input => col:array, OUTER => TRUE)) f
--    -- Without OUTER: rows with NULL/empty arrays are dropped
--    -- With OUTER: rows with NULL/empty arrays produce one row with NULL value
--
-- INTERVIEW TIP: OUTER => TRUE is critical in production to avoid
-- silently dropping rows that have empty or NULL arrays.
-- =============================================================================
