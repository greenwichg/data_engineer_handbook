-- =============================================================================
-- SECTION 10.70: CREATE STORAGE INTEGRATION & STAGE (GCP)
-- =============================================================================
--
-- OBJECTIVE:
--   Learn how to create a storage integration and stage for Google Cloud
--   Storage (GCS), following the same pattern as AWS and Azure.
--
-- WHAT YOU WILL LEARN:
--   1. Creating a GCS storage integration
--   2. Describing the integration to get the service account
--   3. Creating file format and stage objects for GCS
--
-- GCS SETUP FLOW (CONCEPT GAP FILLED):
--   1. Create STORAGE INTEGRATION in Snowflake with STORAGE_PROVIDER = GCS
--   2. DESC INTEGRATION to get STORAGE_GCP_SERVICE_ACCOUNT email
--   3. In GCP Console, go to the GCS bucket > Permissions
--   4. Grant the Snowflake service account "Storage Object Viewer" role
--      (or "Storage Object Admin" for read/write including unload)
--   5. Create STAGE using the integration
--
-- KEY INTERVIEW CONCEPTS:
--   - STORAGE_PROVIDER = GCS for Google Cloud Storage
--   - STORAGE_ALLOWED_LOCATIONS uses gcs:// URL scheme
--   - DESC INTEGRATION reveals the service account email for GCS IAM
--   - Grant Snowflake's service account appropriate roles in GCS
--   - GCS integration is simpler than AWS (no trust policy editing)
-- =============================================================================


-- =============================================
-- STEP 1: Create the GCS storage integration
-- =============================================
CREATE STORAGE INTEGRATION gcp_integration
    TYPE                      = EXTERNAL_STAGE
    STORAGE_PROVIDER          = GCS
    ENABLED                   = TRUE
    STORAGE_ALLOWED_LOCATIONS = (
        'gcs://bucket/path',         -- CSV data path
        'gcs://bucket/path2'         -- JSON data path
    );

-- NOTE: Unlike AWS, GCS doesn't need a role ARN.
-- Snowflake creates a service account automatically.


-- =============================================
-- STEP 2: Get the service account for GCS permissions
-- =============================================
DESC STORAGE INTEGRATION gcp_integration;

-- KEY OUTPUT:
--   STORAGE_GCP_SERVICE_ACCOUNT = 'a]b@project.iam.gserviceaccount.com'
--   -> Grant this service account access to your GCS bucket
--   -> GCS Console > Bucket > Permissions > Add Member
--   -> Role: "Storage Object Viewer" (read) or "Storage Object Admin" (read+write)


-- =============================================================================
-- CONCEPT GAP: GCS vs AWS vs AZURE - SETUP COMPLEXITY COMPARISON
-- =============================================================================
-- GCS:   Simplest  - Just grant service account on bucket (1 step after DESC)
-- Azure: Moderate  - Consent URL + IAM role assignment (2 steps after DESC)
-- AWS:   Most work - Edit IAM trust policy with ARN + external ID (2 steps)
--
-- All three follow the same Snowflake SQL pattern:
--   CREATE STORAGE INTEGRATION -> DESC INTEGRATION -> Cloud-side config -> CREATE STAGE
-- =============================================================================
