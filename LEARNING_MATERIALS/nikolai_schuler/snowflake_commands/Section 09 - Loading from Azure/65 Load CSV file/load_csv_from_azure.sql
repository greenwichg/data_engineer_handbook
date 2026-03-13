-- =============================================================================
-- SECTION 9.65: LOAD CSV DATA FROM AZURE BLOB STORAGE
-- =============================================================================
--
-- OBJECTIVE:
--   Learn how to preview staged CSV data and load it into a Snowflake table
--   from Azure Blob Storage.
--
-- WHAT YOU WILL LEARN:
--   1. Querying staged CSV files with $1, $2, ... positional notation
--   2. Creating a properly-typed table for the data
--   3. Loading data with COPY INTO from Azure stage
--
-- KEY INTERVIEW CONCEPTS:
--   - $1..$N positional column references for staged CSV data
--   - COPY INTO from Azure stage works identically to S3/GCS
--   - Column types must match the data being loaded
--   - COPY INTO is cloud-agnostic once the stage is configured
--
-- IMPORTANT: The COPY INTO syntax is IDENTICAL regardless of cloud provider.
-- The only difference is in the stage/integration setup. This is a key
-- Snowflake design principle: decouple compute from storage.
-- =============================================================================


-- =============================================
-- STEP 1: Preview staged data
-- =============================================
-- Query files directly from the stage to verify format and content.
-- $1 = first column, $2 = second column, etc.

SELECT
    $1, $2, $3, $4, $5, $6, $7, $8, $9, $10,
    $11, $12, $13, $14, $15, $16, $17, $18, $19, $20
FROM @demo_db.public.stage_azure;

-- INTERVIEW TIP: Always preview staged data before creating the target table.
-- This helps you determine: column count, data types, and data quality.


-- =============================================
-- STEP 2: Create the target table
-- =============================================
-- World Happiness Report data with proper numeric types.

CREATE OR REPLACE TABLE happiness (
    country_name                              VARCHAR,
    regional_indicator                        VARCHAR,
    ladder_score                              NUMBER(4,3),
    standard_error                            NUMBER(4,3),
    upperwhisker                              NUMBER(4,3),
    lowerwhisker                              NUMBER(4,3),
    logged_gdp                                NUMBER(5,3),
    social_support                            NUMBER(4,3),
    healthy_life_expectancy                   NUMBER(5,3),
    freedom_to_make_life_choices              NUMBER(4,3),
    generosity                                NUMBER(4,3),
    perceptions_of_corruption                 NUMBER(4,3),
    ladder_score_in_dystopia                  NUMBER(4,3),
    explained_by_log_gpd_per_capita           NUMBER(4,3),
    explained_by_social_support               NUMBER(4,3),
    explained_by_healthy_life_expectancy      NUMBER(4,3),
    explained_by_freedom_to_make_life_choices NUMBER(4,3),
    explained_by_generosity                   NUMBER(4,3),
    explained_by_perceptions_of_corruption    NUMBER(4,3),
    dystopia_residual                         NUMBER(4,3)
);


-- =============================================
-- STEP 3: Load data from Azure stage
-- =============================================
-- Since file format is attached to the stage, no format needed here.

COPY INTO HAPPINESS
FROM @demo_db.public.stage_azure;

-- Validate
SELECT * FROM HAPPINESS;
-- =============================================================================
