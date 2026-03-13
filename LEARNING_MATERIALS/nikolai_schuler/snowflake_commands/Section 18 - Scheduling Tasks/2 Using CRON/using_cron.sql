-- =============================================================================
-- SECTION 18.2: USING CRON EXPRESSIONS FOR TASK SCHEDULING
-- =============================================================================
--
-- OBJECTIVE:
--   Learn how to use CRON expressions for precise, calendar-based task
--   scheduling with timezone support.
--
-- WHAT YOU WILL LEARN:
--   1. CRON syntax and the 5-field format
--   2. Common CRON patterns for production pipelines
--   3. Timezone-aware scheduling
--   4. CRON vs simple interval scheduling
--
-- CRON EXPRESSION FORMAT:
-- ┌──────────────────────────────────────────────────────────────────────────┐
-- │  # __________ minute (0-59)                                             │
-- │  # | ________ hour (0-23)                                               │
-- │  # | | ______ day of month (1-31, or L for last)                        │
-- │  # | | | ____ month (1-12, JAN-DEC)                                     │
-- │  # | | | | __ day of week (0-6, SUN-SAT, or L for last)                 │
-- │  # | | | | |                                                            │
-- │  # * * * * *                                                            │
-- └──────────────────────────────────────────────────────────────────────────┘
--
-- CRON SPECIAL CHARACTERS:
-- ┌──────────────────────┬──────────────────────────────────────────────────┐
-- │ Character            │ Meaning                                          │
-- ├──────────────────────┼──────────────────────────────────────────────────┤
-- │ *                    │ Every value (wildcard)                            │
-- │ ,                    │ List of values (e.g., 7,10 = 7 and 10)           │
-- │ -                    │ Range of values (e.g., 9-17 = 9 through 17)      │
-- │ L                    │ Last (last day of month or last X-day of month)  │
-- └──────────────────────┴──────────────────────────────────────────────────┘
--
-- CRON vs SIMPLE INTERVAL:
-- ┌──────────────────────┬──────────────────────┬──────────────────────────┐
-- │ Aspect               │ Simple Interval      │ CRON                     │
-- ├──────────────────────┼──────────────────────┼──────────────────────────┤
-- │ Syntax               │ 'n MINUTE'           │ 'USING CRON expr tz'    │
-- │ Time reference       │ Relative (from start)│ Absolute (wall clock)    │
-- │ Timezone support     │ No                   │ Yes (explicit timezone)  │
-- │ Day-of-week control  │ No                   │ Yes                      │
-- │ Best for             │ Frequent intervals   │ Business-hour schedules  │
-- └──────────────────────┴──────────────────────┴──────────────────────────┘
--
-- KEY INTERVIEW CONCEPTS:
--   - Always specify timezone explicitly in CRON expressions
--   - CRON is preferred for production pipelines (predictable timing)
--   - Simple interval is easier for "every N minutes" patterns
--   - L in day-of-week means "last occurrence" (e.g., 5L = last Friday)
-- =============================================================================


-- =============================================
-- STEP 1: Simple interval task (recap)
-- =============================================
CREATE OR REPLACE TASK CUSTOMER_INSERT
    WAREHOUSE = COMPUTE_WH
    SCHEDULE  = '60 MINUTE'
AS
    INSERT INTO CUSTOMERS(CREATE_DATE) VALUES(CURRENT_TIMESTAMP);


-- =============================================
-- STEP 2: CRON-based task
-- =============================================
-- Run at 7 AM and 10 AM on the last Friday of every month (UTC)
CREATE OR REPLACE TASK CUSTOMER_INSERT
    WAREHOUSE = COMPUTE_WH
    SCHEDULE  = 'USING CRON 0 7,10 * * 5L UTC'
AS
    INSERT INTO CUSTOMERS(CREATE_DATE) VALUES(CURRENT_TIMESTAMP);

-- BREAKDOWN: 0 7,10 * * 5L UTC
--   0     = minute 0 (on the hour)
--   7,10  = at 7 AM and 10 AM
--   *     = every day of month
--   *     = every month
--   5L    = last Friday of the month (5=Friday, L=last)
--   UTC   = timezone


-- =============================================
-- STEP 3: Common CRON patterns
-- =============================================

-- Every minute (most frequent possible)
-- SCHEDULE = 'USING CRON * * * * * UTC'

-- Every day at 6 AM UTC
-- SCHEDULE = 'USING CRON 0 6 * * * UTC'

-- Every hour from 9 AM to 5 PM on Sundays (Pacific time)
-- SCHEDULE = 'USING CRON 0 9-17 * * SUN America/Los_Angeles'

-- Every weekday at midnight UTC
-- SCHEDULE = 'USING CRON 0 0 * * MON-FRI UTC'

-- First day of every month at 3 AM UTC
-- SCHEDULE = 'USING CRON 0 3 1 * * UTC'

-- Every 15 minutes during business hours (9-17) on weekdays
-- SCHEDULE = 'USING CRON 0,15,30,45 9-17 * * MON-FRI UTC'


-- =============================================
-- STEP 4: Task with CRON at 9 AM and 5 PM daily
-- =============================================
CREATE OR REPLACE TASK CUSTOMER_INSERT
    WAREHOUSE = COMPUTE_WH
    SCHEDULE  = 'USING CRON 0 9,17 * * * UTC'
AS
    INSERT INTO CUSTOMERS(CREATE_DATE) VALUES(CURRENT_TIMESTAMP);


-- =============================================================================
-- CONCEPT GAP: TIMEZONE BEST PRACTICES
-- =============================================================================
-- ALWAYS specify a timezone in CRON expressions.
--
-- COMMON TIMEZONES:
--   UTC                    → Universal (recommended for data pipelines)
--   America/New_York       → US Eastern (handles DST automatically)
--   America/Los_Angeles    → US Pacific
--   Europe/London          → UK
--   Asia/Tokyo             → Japan
--
-- WHY UTC IS RECOMMENDED:
--   - No daylight saving time changes
--   - Consistent across seasons
--   - Standard for data engineering pipelines
--   - Avoids DST-related scheduling issues (tasks may skip or double-run)
-- =============================================================================


-- =============================================================================
-- CONCEPT GAP: CRON GOTCHAS
-- =============================================================================
-- 1. DAY-OF-WEEK + DAY-OF-MONTH:
--    If both are specified, Snowflake uses OR logic (not AND).
--    '0 6 1 * MON' = 6 AM on the 1st AND on every Monday
--
-- 2. MINIMUM GRANULARITY:
--    CRON can schedule down to 1-minute intervals.
--    For sub-minute scheduling, you'll need external tools.
--
-- 3. MISSED RUNS:
--    If a task is suspended during its scheduled time, it does NOT
--    retroactively execute missed runs. They are simply skipped.
--
-- 4. OVERLAPPING RUNS:
--    If a task run takes longer than the interval, the next run is
--    SKIPPED (not queued). This prevents cascading overloads.
-- =============================================================================
