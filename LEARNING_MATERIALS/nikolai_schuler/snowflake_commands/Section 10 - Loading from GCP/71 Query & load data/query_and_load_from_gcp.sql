-- =============================================================================
-- SECTION 10.71: QUERY & LOAD DATA FROM GCS
-- =============================================================================
--
-- OBJECTIVE:
--   Learn how to preview staged files from GCS and load data into a
--   Snowflake table - demonstrating that COPY INTO is cloud-agnostic.
--
-- WHAT YOU WILL LEARN:
--   1. Querying staged CSV files from GCS with positional notation
--   2. Creating a properly-typed table and loading data
--   3. The cloud-agnostic nature of Snowflake's COPY INTO
--
-- KEY INTERVIEW CONCEPTS:
--   - SELECT $1,$2,...$N FROM @stage previews files before loading
--   - COPY INTO is IDENTICAL across AWS, Azure, and GCP
--   - COPY INTO is idempotent by default (won't reload same files)
--   - Always preview staged data before loading
--
-- CLOUD-AGNOSTIC DATA LOADING (CONCEPT GAP FILLED):
--   Once a stage is configured, the COPY INTO syntax is identical:
--     COPY INTO my_table FROM @my_stage;
--   This works regardless of whether the stage points to S3, Azure, or GCS.
--   The cloud-specific details are encapsulated in the integration + stage.
-- =============================================================================


-- =============================================
-- STEP 1: Preview staged data
-- =============================================
SELECT
    $1, $2, $3, $4, $5, $6, $7, $8, $9, $10,
    $11, $12, $13, $14, $15, $16, $17, $18, $19, $20
FROM @demo_db.public.stage_gcp;


-- =============================================
-- STEP 2: Create table and load data
-- =============================================
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

-- Load from GCS stage (same syntax as S3 or Azure!)
COPY INTO HAPPINESS
FROM @demo_db.public.stage_gcp;

-- Validate
SELECT * FROM HAPPINESS;
-- =============================================================================
