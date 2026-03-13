-- =============================================================================
-- SECTION 9.63: CREATE STORAGE INTEGRATION (Azure Blob Storage)
-- =============================================================================
--
-- OBJECTIVE:
--   Learn how to create a storage integration for Azure Blob Storage / ADLS Gen2,
--   establishing a trust relationship between Snowflake and Azure AD.
--
-- WHAT YOU WILL LEARN:
--   1. Creating an Azure storage integration with AZURE_TENANT_ID
--   2. Describing the integration to get the consent URL
--   3. Azure-specific setup steps for granting access
--
-- AZURE SETUP FLOW (CONCEPT GAP FILLED):
--   1. Create STORAGE INTEGRATION in Snowflake with AZURE_TENANT_ID
--   2. DESC INTEGRATION to get:
--      - AZURE_CONSENT_URL: URL to grant Snowflake access in Azure AD
--      - AZURE_MULTI_TENANT_APP_NAME: Snowflake's app identity
--   3. Open the consent URL in a browser and grant permissions
--   4. In Azure Portal, assign "Storage Blob Data Contributor" role to
--      Snowflake's service principal on the storage account
--   5. Create STAGE using the integration
--
-- KEY INTERVIEW CONCEPTS:
--   - STORAGE_PROVIDER = AZURE for Azure Blob / ADLS Gen2
--   - AZURE_TENANT_ID identifies the Azure Active Directory tenant
--   - STORAGE_ALLOWED_LOCATIONS uses azure:// URL scheme
--   - DESC INTEGRATION provides consent URL and multi-tenant app name
--   - After creation, must grant Snowflake access via Azure consent URL
--
-- AZURE URL FORMAT:
--   azure://<storage_account>.blob.core.windows.net/<container>/<path>
-- =============================================================================


-- =============================================
-- STEP 1: Set context
-- =============================================
USE DATABASE DEMO_DB;


-- =============================================
-- STEP 2: Create the Azure storage integration
-- =============================================
-- AZURE_TENANT_ID: Found in Azure Portal > Azure Active Directory > Overview

CREATE STORAGE INTEGRATION azure_integration
    TYPE                      = EXTERNAL_STAGE
    STORAGE_PROVIDER          = AZURE
    ENABLED                   = TRUE
    AZURE_TENANT_ID           = '9ecede0b-0e07-4da4-8047-e0672d6e403e'  -- Your Azure AD tenant ID
    STORAGE_ALLOWED_LOCATIONS = (
        'azure://storageaccountsnow.blob.core.windows.net/snowflakecsv',
        'azure://storageaccountsnow.blob.core.windows.net/snowflakejson'
    );

-- STORAGE_ALLOWED_LOCATIONS: Whitelist of Azure containers/paths.
-- Stages using this integration can ONLY access these locations.


-- =============================================
-- STEP 3: Describe the integration for Azure setup
-- =============================================
DESC STORAGE INTEGRATION azure_integration;

-- KEY OUTPUT:
--   AZURE_CONSENT_URL          - Open this URL in browser to grant access
--   AZURE_MULTI_TENANT_APP_NAME - Snowflake's registered app in Azure AD
--
-- AFTER CONSENT:
--   Go to Azure Portal > Storage Account > Access Control (IAM)
--   Add role assignment:
--     Role: "Storage Blob Data Contributor" (for read/write)
--       or: "Storage Blob Data Reader" (for read-only)
--     Assign to: The Snowflake service principal from AZURE_MULTI_TENANT_APP_NAME


-- =============================================================================
-- CONCEPT GAP: AZURE vs AWS vs GCP INTEGRATION COMPARISON
-- =============================================================================
-- ┌─────────────┬───────────────────┬────────────────────┬──────────────────┐
-- │ Feature     │ AWS               │ Azure              │ GCP              │
-- ├─────────────┼───────────────────┼────────────────────┼──────────────────┤
-- │ Provider    │ S3                │ AZURE              │ GCS              │
-- │ Auth method │ IAM Role ARN      │ Azure AD Tenant ID │ Service Account  │
-- │ URL scheme  │ s3://             │ azure://           │ gcs://           │
-- │ Grant step  │ Edit IAM trust    │ Consent URL +      │ Grant service    │
-- │             │ policy            │ IAM role assignment │ account in GCS  │
-- │ Key output  │ AWS_IAM_USER_ARN  │ AZURE_CONSENT_URL  │ Service account  │
-- │ from DESC   │ + EXTERNAL_ID     │ + APP_NAME         │ email            │
-- └─────────────┴───────────────────┴────────────────────┴──────────────────┘
-- =============================================================================
