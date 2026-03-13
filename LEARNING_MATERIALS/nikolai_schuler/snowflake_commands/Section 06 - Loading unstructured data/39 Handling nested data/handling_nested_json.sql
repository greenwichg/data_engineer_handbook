-- =============================================================================
-- SECTION 6.39: HANDLING NESTED JSON DATA (JSON Part 3 of 5)
-- =============================================================================
--
-- OBJECTIVE:
--   Learn how to access nested JSON objects with dot notation, array elements
--   with index notation, and how to unnest arrays using UNION ALL.
--
-- WHAT YOU WILL LEARN:
--   1. Dot notation for nested objects (key.subkey)
--   2. Array indexing with [n] for accessing array elements
--   3. ARRAY_SIZE() to count elements in a JSON array
--   4. UNION ALL pattern to manually unnest array elements into rows
--
-- JSON STRUCTURE BEING QUERIED:
--   {
--     "id": 1,
--     "first_name": "Alice",
--     "last_name": "Smith",
--     "job": {                           <-- Nested object
--       "title": "Financial Analyst",
--       "salary": 65000
--     },
--     "prev_company": ["Google", "Meta"] <-- Array of strings
--   }
--
-- KEY INTERVIEW CONCEPTS:
--   - col:key.subkey for nested object access (dot notation)
--   - col:key[0] for array element access (0-based indexing)
--   - ARRAY_SIZE() to count elements in a JSON array
--   - UNION ALL pattern to manually unnest fixed-size arrays into rows
--   - Limitation: UNION ALL only works for known/fixed array sizes
-- =============================================================================


-- =============================================
-- STEP 1: Access nested objects with dot notation
-- =============================================
-- The "job" field is a nested JSON object.

-- View the entire nested object
SELECT RAW_FILE:job AS job
FROM OUR_FIRST_DB.PUBLIC.JSON_RAW;
-- Output: {"salary":65000,"title":"Financial Analyst"}

-- Access a specific field within the nested object using DOT notation
SELECT
    RAW_FILE:job.salary::INT AS salary
FROM OUR_FIRST_DB.PUBLIC.JSON_RAW;
-- Output: 65000 (as INT)

-- Combine top-level and nested fields
SELECT
    RAW_FILE:first_name::STRING AS first_name,
    RAW_FILE:job.salary::INT    AS salary,
    RAW_FILE:job.title::STRING  AS title
FROM OUR_FIRST_DB.PUBLIC.JSON_RAW;

-- INTERVIEW TIP: Dot notation can go multiple levels deep:
--   col:level1.level2.level3::TYPE
-- Each dot descends one level into the JSON hierarchy.


-- =============================================
-- STEP 2: Access JSON arrays
-- =============================================
-- The "prev_company" field is a JSON array of strings.

-- View the entire array
SELECT
    RAW_FILE:prev_company AS prev_company
FROM OUR_FIRST_DB.PUBLIC.JSON_RAW;
-- Output: ["Google","Meta"] (entire array as VARIANT)

-- Access specific array elements by index (0-based!)
SELECT
    RAW_FILE:prev_company[1]::STRING AS prev_company
FROM OUR_FIRST_DB.PUBLIC.JSON_RAW;
-- Output: "Meta" (second element, index 1)

-- IMPORTANT: Array indexes are 0-BASED in Snowflake JSON.
--   [0] = first element
--   [1] = second element
--   [n] = (n+1)th element


-- =============================================
-- STEP 3: Count array elements with ARRAY_SIZE()
-- =============================================
SELECT
    ARRAY_SIZE(RAW_FILE:prev_company) AS num_prev_companies
FROM OUR_FIRST_DB.PUBLIC.JSON_RAW;
-- Output: 2 (the person has 2 previous companies)

-- INTERVIEW TIP: ARRAY_SIZE() returns NULL if the field is not an array
-- or doesn't exist. Use it to understand data distribution before unnesting.


-- =============================================
-- STEP 4: Unnest arrays with UNION ALL (manual approach)
-- =============================================
-- Convert array elements into separate rows using UNION ALL.
-- This creates one row per array element per person.

SELECT
    RAW_FILE:id::INT           AS id,
    RAW_FILE:first_name::STRING AS first_name,
    RAW_FILE:prev_company[0]::STRING AS prev_company  -- First company
FROM OUR_FIRST_DB.PUBLIC.JSON_RAW

UNION ALL

SELECT
    RAW_FILE:id::INT           AS id,
    RAW_FILE:first_name::STRING AS first_name,
    RAW_FILE:prev_company[1]::STRING AS prev_company  -- Second company
FROM OUR_FIRST_DB.PUBLIC.JSON_RAW

ORDER BY id;

-- RESULT:
--   id | first_name | prev_company
--   1  | Alice      | Google
--   1  | Alice      | Meta
--   2  | Bob        | Amazon
--   2  | Bob        | NULL          <-- Bob only had 1 company

-- LIMITATIONS OF UNION ALL APPROACH:
--   1. You must know the MAXIMUM array size in advance
--   2. Creates NULL rows for shorter arrays
--   3. Not scalable for variable-length arrays
--   4. Requires manual maintenance if array sizes change
--
-- SOLUTION: Use FLATTEN() instead (covered in Section 6.40)


-- =============================================================================
-- CONCEPT GAP: CHECKING AND HANDLING NULL/MISSING KEYS
-- =============================================================================
-- JSON data often has missing keys or null values:
--
-- -- Check if a key exists (returns NULL if missing)
-- SELECT RAW_FILE:optional_field FROM JSON_RAW;
--
-- -- Handle missing keys with NVL/COALESCE
-- SELECT NVL(RAW_FILE:optional_field::STRING, 'N/A') AS field
-- FROM JSON_RAW;
--
-- -- Check array bounds before accessing
-- SELECT
--     CASE
--         WHEN ARRAY_SIZE(RAW_FILE:prev_company) > 2
--         THEN RAW_FILE:prev_company[2]::STRING
--         ELSE 'No third company'
--     END AS third_company
-- FROM JSON_RAW;
--
-- INTERVIEW TIP: Always handle NULL/missing keys in production queries.
-- JSON data is inherently schema-less, so keys may not exist in every row.
-- =============================================================================
