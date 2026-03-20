# Databricks Open Delta Sharing Demo

## Introduction

Now let's look at the other side of Delta Sharing -- Open Delta Sharing. This is where the
recipient is NOT on Databricks. Maybe they're using plain Apache Spark, pandas in a Jupyter
notebook, Power BI, Tableau, or any other tool that supports the Delta Sharing protocol. The
key difference from Databricks-to-Databricks sharing is that the recipient needs a credential
file (a .share file) to authenticate, since there's no shared Databricks account to handle
authentication automatically.

This is what makes Delta Sharing truly "open" -- anyone can consume shared data regardless
of their platform.

## Open Sharing Architecture

```
Open Delta Sharing:

  PROVIDER                                RECIPIENT
  (Databricks)                            (Any Platform)

  ┌──────────────────┐                    ┌──────────────────────┐
  │                  │                    │                      │
  │  Delta Lake      │    REST API        │  delta-sharing-      │
  │  Tables          │◀──────────────────│  python               │
  │                  │    (authenticated  │                      │
  │  Unity Catalog   │     via bearer     │  OR                  │
  │  (Shares,        │     token from     │                      │
  │   Recipients)    │     .share file)   │  delta-sharing-      │
  │                  │                    │  spark                │
  │  Delta Sharing   │                    │                      │
  │  Server          │                    │  OR                  │
  │                  │                    │                      │
  └──────────────────┘                    │  Power BI / Tableau  │
                                          │                      │
                                          │  OR                  │
                                          │                      │
                                          │  Any REST client     │
                                          └──────────────────────┘
```

## Step 1: Create Share and Add Tables (Provider)

```sql
-- On the PROVIDER workspace (same as before)

CREATE SHARE IF NOT EXISTS open_analytics_share
COMMENT 'Analytics data shared via open protocol';

-- Add tables
ALTER SHARE open_analytics_share
ADD TABLE production.analytics.customer_summary;

ALTER SHARE open_analytics_share
ADD TABLE production.analytics.monthly_revenue
PARTITION (year = '2025');  -- Only share 2025 data
```

## Step 2: Create an Open Sharing Recipient

```sql
-- Create a recipient WITHOUT USING ID (this makes it an open sharing recipient)
CREATE RECIPIENT IF NOT EXISTS external_analytics_team
COMMENT 'External analytics team using pandas/Spark';

-- This generates an activation link
-- View the activation link
DESCRIBE RECIPIENT external_analytics_team;

-- Output includes:
-- ┌─────────────────────┬──────────────────────────────────────────┐
-- │ property            │ value                                    │
-- ├─────────────────────┼──────────────────────────────────────────┤
-- │ name                │ external_analytics_team                  │
-- │ authentication_type │ TOKEN                                    │
-- │ activation_link     │ https://<workspace>.databricks.com/...   │
-- │ active              │ false (not yet activated)                │
-- └─────────────────────┴──────────────────────────────────────────┘
```

## Step 3: Recipient Activation

```
Activation Flow:

  Provider sends activation link to recipient
  (via email, Slack, or other secure channel)
       │
       ▼
  Recipient opens the activation link in their browser
       │
       ▼
  ┌──────────────────────────────────────────────────┐
  │                                                  │
  │  Delta Sharing Activation                        │
  │                                                  │
  │  You've been invited to access shared data.      │
  │                                                  │
  │  [ Download Credential File ]                    │
  │                                                  │
  │  This link can only be used ONCE.                │
  │  Store the credential file securely.             │
  │                                                  │
  └──────────────────────────────────────────────────┘
       │
       ▼
  Recipient downloads the .share file
  (one-time download -- link expires after use)
```

## Step 4: The .share Credential File

```
Downloaded file: config.share

{
  "shareCredentialsVersion": 1,
  "endpoint": "https://<workspace-url>/api/2.0/delta-sharing/",
  "bearerToken": "dapi_abc123def456...",
  "expirationTime": "2026-03-20T00:00:00.000Z"
}

IMPORTANT:
- This file is like a password -- store it securely!
- The activation link can only be used once
- If the recipient loses the file, the provider must
  rotate the token (generate a new activation link)
```

## Step 5: Grant Share to Recipient

```sql
-- Back on the PROVIDER workspace
GRANT SELECT ON SHARE open_analytics_share TO RECIPIENT external_analytics_team;
```

## Step 6: Consume Shared Data (Recipient Side)

### Using Python (pandas)

```python
# Install: pip install delta-sharing
import delta_sharing

# Path to the .share credential file
profile_file = "/path/to/config.share"

# List all available shares
client = delta_sharing.SharingClient(profile_file)
shares = client.list_shares()
print(shares)
# [Share(name='open_analytics_share')]

# List schemas in a share
schemas = client.list_schemas(shares[0])
print(schemas)

# List tables in a schema
tables = client.list_tables(schemas[0])
print(tables)

# Load a shared table into a pandas DataFrame
table_url = f"{profile_file}#open_analytics_share.analytics.customer_summary"
df = delta_sharing.load_as_pandas(table_url)
print(df.head())

#    customer_id  region    total_spend  segment
# 0  C001         us-east   45230.50     premium
# 1  C002         us-west   12450.75     standard
# 2  C003         eu-west   67890.00     premium
```

### Using Apache Spark

```python
# In a Spark session (non-Databricks)
from pyspark.sql import SparkSession

spark = SparkSession.builder \
    .appName("DeltaSharingConsumer") \
    .config("spark.jars.packages", "io.delta:delta-sharing-spark_2.12:1.0.0") \
    .getOrCreate()

profile_file = "/path/to/config.share"

# Read shared table as a Spark DataFrame
df = spark.read.format("deltaSharing") \
    .load(f"{profile_file}#open_analytics_share.analytics.monthly_revenue")

df.show()
# +-------+--------+-----------+------+
# | month | region | revenue   | year |
# +-------+--------+-----------+------+
# | Jan   | us-east| 1250000.00| 2025 |
# | Jan   | us-west|  980000.00| 2025 |
# +-------+--------+-----------+------+

# Run analytics on the shared data
df.groupBy("region") \
  .agg({"revenue": "sum"}) \
  .orderBy("sum(revenue)", ascending=False) \
  .show()
```

## Token Management

```sql
-- PROVIDER: Rotate a recipient's token (invalidates the old token)
ALTER RECIPIENT external_analytics_team ROTATE TOKEN;

-- This generates a new activation link
-- The old .share file will stop working
-- The recipient must download a new credential file

-- PROVIDER: View recipient token expiration
DESCRIBE RECIPIENT external_analytics_team;
```

```
Token Rotation Flow:

  Old token active ──▶ ALTER RECIPIENT ROTATE TOKEN ──▶ Old token invalid
                                    │
                                    ▼
                           New activation link
                           generated
                                    │
                                    ▼
                           Recipient downloads
                           new .share file
                                    │
                                    ▼
                           New token active
```

## Key Exam Points

1. **Open Delta Sharing** is for recipients NOT on Databricks
2. **Recipient authentication** uses a .share credential file with a bearer token
3. **Activation link is one-time use** -- can only be downloaded once
4. **delta-sharing-python** library loads data into pandas DataFrames
5. **delta-sharing-spark** library loads data into Spark DataFrames
6. **Token rotation** with `ALTER RECIPIENT ROTATE TOKEN` invalidates the old token
7. **The .share file should be treated like a password** -- store securely
8. **Open sharing supports tables** -- views, volumes, models require Databricks-to-Databricks
9. **Data is read-only** -- recipients cannot modify the provider's tables
10. **URL format** for loading: `<profile_file>#<share>.<schema>.<table>`
