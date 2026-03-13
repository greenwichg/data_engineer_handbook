-- =============================================================================
-- SECTION 18.4: CALLING A STORED PROCEDURE FROM A TASK
-- =============================================================================
--
-- OBJECTIVE:
--   Learn how to invoke stored procedures from tasks, combining procedural
--   logic with scheduled automation for production ETL pipelines.
--
-- WHAT YOU WILL LEARN:
--   1. Creating a stored procedure with JavaScript
--   2. Using bind variables for safe SQL execution
--   3. Calling a procedure from a task with AS CALL
--   4. When to use procedures vs inline SQL in tasks
--
-- TASK + STORED PROCEDURE PATTERN:
-- ┌──────────────────────────────────────────────────────────────────────────┐
-- │                                                                         │
-- │   ┌─────────────────────┐         ┌─────────────────────────┐          │
-- │   │     TASK             │  CALL   │   STORED PROCEDURE       │         │
-- │   │  (scheduling +      │────────>│  (complex logic +        │         │
-- │   │   WHEN condition)   │         │   bind variables)        │          │
-- │   └─────────────────────┘         └─────────────────────────┘          │
-- │                                                                         │
-- │   Task handles:                    Procedure handles:                   │
-- │   - Schedule/CRON                  - Multi-statement logic              │
-- │   - WHEN conditions                - Error handling                     │
-- │   - Warehouse assignment           - Dynamic SQL                        │
-- │   - DAG dependencies               - Parameter binding                  │
-- │                                                                         │
-- └──────────────────────────────────────────────────────────────────────────┘
--
-- KEY INTERVIEW CONCEPTS:
--   - Tasks can only execute a SINGLE SQL statement
--   - For complex multi-step logic, use CALL <procedure> as the task's SQL
--   - Stored procedures support JavaScript, Python, Java, Scala, or SQL scripting
--   - Bind variables (:1, :2, etc.) prevent SQL injection in procedures
--   - This is the recommended production pattern for complex ETL tasks
-- =============================================================================


-- =============================================
-- STEP 1: Create a stored procedure
-- =============================================
USE TASK_DB;

SELECT * FROM CUSTOMERS;

-- JavaScript-based stored procedure with a parameter
CREATE OR REPLACE PROCEDURE CUSTOMERS_INSERT_PROCEDURE (CREATE_DATE VARCHAR)
    RETURNS STRING NOT NULL
    LANGUAGE JAVASCRIPT
AS
    $$
    var sql_command = 'INSERT INTO CUSTOMERS(CREATE_DATE) VALUES(:1);'
    snowflake.execute(
        {
        sqlText: sql_command,
        binds: [CREATE_DATE]
        });
    return "Successfully executed.";
    $$;

-- PROCEDURE ANATOMY:
--   CREATE PROCEDURE name (param datatype)
--     RETURNS datatype          → What the procedure returns
--     LANGUAGE JAVASCRIPT       → Procedure body language
--   AS $$ ... $$;              → The procedure body
--
-- BIND VARIABLES:
--   :1, :2, :3, etc.          → Positional placeholders in SQL
--   binds: [value1, value2]    → Values to bind to placeholders
--   This prevents SQL injection — NEVER concatenate strings!
--
-- snowflake.execute():
--   The JavaScript API for running SQL within a stored procedure.
--   Returns a resultSet object that can be iterated over.


-- =============================================
-- STEP 2: Create a task that calls the procedure
-- =============================================
CREATE OR REPLACE TASK CUSTOMER_TAKS_PROCEDURE
    WAREHOUSE = COMPUTE_WH
    SCHEDULE  = '1 MINUTE'
AS
    CALL CUSTOMERS_INSERT_PROCEDURE(CURRENT_TIMESTAMP);

-- SYNTAX: AS CALL <procedure_name>(arguments)
-- The procedure receives CURRENT_TIMESTAMP as the CREATE_DATE parameter.

SHOW TASKS;


-- =============================================
-- STEP 3: Resume and verify
-- =============================================
ALTER TASK CUSTOMER_TAKS_PROCEDURE RESUME;

-- After a few minutes, check results
SELECT * FROM CUSTOMERS;

-- Suspend when done testing
-- ALTER TASK CUSTOMER_TAKS_PROCEDURE SUSPEND;


-- =============================================================================
-- CONCEPT GAP: STORED PROCEDURE LANGUAGES IN SNOWFLAKE
-- =============================================================================
-- ┌──────────────────────┬──────────────────────────────────────────────────┐
-- │ Language             │ Best For                                         │
-- ├──────────────────────┼──────────────────────────────────────────────────┤
-- │ SQL (Snowflake       │ Simple multi-statement logic, loops, cursors     │
-- │ Scripting)           │ No external dependencies needed                  │
-- ├──────────────────────┼──────────────────────────────────────────────────┤
-- │ JavaScript           │ String manipulation, JSON processing, legacy     │
-- │                      │ procedures (was the first supported language)    │
-- ├──────────────────────┼──────────────────────────────────────────────────┤
-- │ Python               │ ML/data science, complex transformations         │
-- │                      │ Access to Python libraries (pandas, etc.)        │
-- ├──────────────────────┼──────────────────────────────────────────────────┤
-- │ Java / Scala         │ Enterprise integrations, JVM ecosystem           │
-- └──────────────────────┴──────────────────────────────────────────────────┘
--
-- MODERN ALTERNATIVE (Snowflake Scripting — SQL-native):
--   CREATE PROCEDURE my_proc()
--     RETURNS STRING
--     LANGUAGE SQL
--   AS
--   BEGIN
--     INSERT INTO table1 SELECT * FROM source;
--     UPDATE table2 SET status = 'done' WHERE ...;
--     RETURN 'Success';
--   END;
-- =============================================================================


-- =============================================================================
-- CONCEPT GAP: INLINE SQL vs PROCEDURE — WHEN TO USE WHICH
-- =============================================================================
-- USE INLINE SQL IN TASK WHEN:
--   ✓ Single, simple SQL statement
--   ✓ No parameters needed
--   ✓ No conditional logic
--   Example: INSERT INTO target SELECT * FROM source;
--
-- USE STORED PROCEDURE WHEN:
--   ✓ Multiple SQL statements need to execute in sequence
--   ✓ Conditional logic (IF/ELSE) is needed
--   ✓ Dynamic SQL with parameters
--   ✓ Error handling with TRY/CATCH
--   ✓ Complex transformations
--   ✓ Reusability across multiple tasks
-- =============================================================================
