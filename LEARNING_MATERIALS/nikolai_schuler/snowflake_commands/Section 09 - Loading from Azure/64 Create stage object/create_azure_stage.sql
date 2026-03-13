-- =============================================================================
-- SECTION 9.64: CREATE STAGE OBJECT (Azure Blob Storage)
-- =============================================================================
--
-- OBJECTIVE:
--   Learn how to create file format and stage objects for Azure Blob Storage,
--   combining the integration, URL, and file format into a reusable stage.
--
-- WHAT YOU WILL LEARN:
--   1. Creating a CSV file format for Azure data
--   2. Creating a stage that references the Azure integration
--   3. Listing files in the Azure stage to verify connectivity
--
-- KEY INTERVIEW CONCEPTS:
--   - Stage = integration + cloud URL + file format (all combined)
--   - Stage URL must fall within STORAGE_ALLOWED_LOCATIONS of the integration
--   - LIST @stage verifies connectivity and shows available files
--   - Named file format objects promote reuse across stages/COPY commands
--
-- STAGE COMPONENTS (CONCEPT GAP FILLED):
--   A stage combines three independent concerns:
--   1. AUTHENTICATION: Storage integration (how to connect)
--   2. LOCATION: URL pointing to cloud storage path (where to read)
--   3. FORMAT: File format object or inline options (how to parse)
--   This separation enables flexible reuse of each component.
-- =============================================================================


-- =============================================
-- STEP 1: Create file format for CSV
-- =============================================
CREATE OR REPLACE FILE FORMAT demo_db.public.fileformat_azure
    TYPE            = CSV
    FIELD_DELIMITER = ','
    SKIP_HEADER     = 1;


-- =============================================
-- STEP 2: Create stage with integration
-- =============================================
-- Stage combines: integration (auth) + URL (location) + file format (parsing)

CREATE OR REPLACE STAGE demo_db.public.stage_azure
    STORAGE_INTEGRATION = azure_integration
    URL                 = 'azure://storageaccountsnow.blob.core.windows.net/snowflakecsv'
    FILE_FORMAT         = fileformat_azure;

-- The URL must be within STORAGE_ALLOWED_LOCATIONS defined in the integration.
-- If the URL is outside the allowed list, stage creation will fail.


-- =============================================
-- STEP 3: Verify connectivity by listing files
-- =============================================
LIST @demo_db.public.stage_azure;

-- If this returns file names, the integration and stage are working correctly.
-- If it errors, check:
--   1. Azure consent was granted (DESC INTEGRATION for consent URL)
--   2. Storage Blob Data Contributor/Reader role is assigned
--   3. URL matches the allowed locations in the integration
-- =============================================================================
