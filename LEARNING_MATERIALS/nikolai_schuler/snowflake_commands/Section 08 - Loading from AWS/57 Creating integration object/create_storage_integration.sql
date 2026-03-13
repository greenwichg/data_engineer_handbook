-- =============================================================================
-- SECTION 8.57: CREATE STORAGE INTEGRATION (AWS S3)
-- =============================================================================
--
-- OBJECTIVE:
--   Learn how to create a storage integration object for secure, credential-free
--   access to AWS S3 using IAM roles instead of hardcoded access keys.
--
-- WHAT YOU WILL LEARN:
--   1. What a storage integration is and why it's needed
--   2. Creating a storage integration with IAM role ARN
--   3. Describing the integration to get the external ID
--   4. The trust relationship setup between Snowflake and AWS
--
-- STORAGE INTEGRATION vs DIRECT CREDENTIALS (CONCEPT GAP FILLED):
-- ┌──────────────────────────┬──────────────────────────────────────────────┐
-- │ Direct Credentials       │ Storage Integration                         │
-- │ (Section 4 approach)     │ (Production approach)                       │
-- ├──────────────────────────┼──────────────────────────────────────────────┤
-- │ aws_key_id + secret in   │ IAM Role ARN in integration object          │
-- │ stage definition         │                                             │
-- │ Credentials visible in   │ No credentials exposed in SQL               │
-- │ SQL code                 │                                             │
-- │ Manual key rotation      │ Automatic via IAM role assumption           │
-- │ Per-stage credentials    │ Shared across multiple stages               │
-- │ Any role can create      │ Requires ACCOUNTADMIN                       │
-- │ OK for demos/learning    │ Required for production                     │
-- └──────────────────────────┴──────────────────────────────────────────────┘
--
-- KEY INTERVIEW CONCEPTS:
--   - Storage integrations avoid storing credentials in stage definitions
--   - STORAGE_AWS_ROLE_ARN links to the IAM role for cross-account access
--   - STORAGE_ALLOWED_LOCATIONS restricts which S3 paths can be accessed
--   - DESC INTEGRATION reveals the external_id for IAM trust policy
--   - Integration objects are ACCOUNT-LEVEL objects (require ACCOUNTADMIN)
--
-- AWS SETUP FLOW (CONCEPT GAP FILLED):
--   1. Create IAM Role in AWS with S3 access policy
--   2. Create STORAGE INTEGRATION in Snowflake with the role ARN
--   3. DESC INTEGRATION to get STORAGE_AWS_IAM_USER_ARN and STORAGE_AWS_EXTERNAL_ID
--   4. Update the IAM Role trust policy with Snowflake's ARN and external ID
--   5. Create STAGE using the integration (no credentials needed)
-- =============================================================================


-- =============================================
-- STEP 1: Create the storage integration
-- =============================================
-- Requires ACCOUNTADMIN role.

CREATE OR REPLACE STORAGE INTEGRATION s3_int
    TYPE                      = EXTERNAL_STAGE
    STORAGE_PROVIDER          = S3
    ENABLED                   = TRUE
    STORAGE_AWS_ROLE_ARN      = ''  -- Replace with your IAM Role ARN
                                    -- Format: arn:aws:iam::123456789012:role/my-snowflake-role
    STORAGE_ALLOWED_LOCATIONS = (
        's3://<your-bucket-name>/<your-path>/',     -- CSV data path
        's3://<your-bucket-name>/<your-path>/'      -- JSON data path
    )
    COMMENT = 'Integration for S3 data loading - production pipeline';

-- STORAGE_ALLOWED_LOCATIONS acts as a whitelist.
-- Stages using this integration can ONLY access these paths.
-- This is a security guardrail to prevent unauthorized data access.

-- CONCEPT GAP FILLED - STORAGE_BLOCKED_LOCATIONS:
-- You can also specify blocked paths (blacklist):
-- STORAGE_BLOCKED_LOCATIONS = ('s3://my-bucket/sensitive/')
-- This prevents access to specific subpaths even if the parent is allowed.


-- =============================================
-- STEP 2: Describe the integration
-- =============================================
-- Get the Snowflake-generated values needed for AWS IAM trust policy.

DESC INTEGRATION s3_int;

-- IMPORTANT OUTPUT COLUMNS:
--   STORAGE_AWS_IAM_USER_ARN   - Snowflake's IAM user ARN (add to trust policy)
--   STORAGE_AWS_EXTERNAL_ID    - External ID for secure role assumption
--
-- You must add BOTH values to your AWS IAM Role's Trust Relationship:
-- {
--   "Version": "2012-10-17",
--   "Statement": [{
--     "Effect": "Allow",
--     "Principal": {"AWS": "<STORAGE_AWS_IAM_USER_ARN>"},
--     "Action": "sts:AssumeRole",
--     "Condition": {
--       "StringEquals": {"sts:ExternalId": "<STORAGE_AWS_EXTERNAL_ID>"}
--     }
--   }]
-- }


-- =============================================================================
-- CONCEPT GAP: STORAGE INTEGRATION FOR ALL CLOUD PROVIDERS
-- =============================================================================
-- AWS S3:
--   STORAGE_PROVIDER = S3
--   STORAGE_AWS_ROLE_ARN = 'arn:aws:iam::...:role/...'
--   URL scheme: s3://bucket/path/
--
-- Azure Blob / ADLS Gen2:
--   STORAGE_PROVIDER = AZURE
--   AZURE_TENANT_ID = 'your-tenant-id'
--   URL scheme: azure://account.blob.core.windows.net/container/
--
-- Google Cloud Storage:
--   STORAGE_PROVIDER = GCS
--   (No role ARN needed - uses Snowflake service account)
--   URL scheme: gcs://bucket/path/
--
-- INTERVIEW TIP: Storage integrations are the recommended approach for ALL
-- cloud providers. They centralize security, enable credential rotation,
-- and follow the principle of least privilege.
-- =============================================================================
