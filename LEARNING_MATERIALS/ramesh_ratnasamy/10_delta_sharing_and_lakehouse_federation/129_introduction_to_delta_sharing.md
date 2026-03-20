# Introduction to Delta Sharing

## Introduction

Alright, let's talk about Delta Sharing -- one of the most powerful features in the Databricks
ecosystem for securely sharing data across organizations. In the real world, data doesn't live in
a vacuum. You often need to share datasets with partners, customers, vendors, or other teams that
might be on completely different platforms. Traditionally, this has been painful -- you'd export
CSVs, set up SFTP servers, build custom APIs, or copy data into another system. All of these
approaches are fragile, insecure, and create stale copies of data everywhere.

Delta Sharing solves this problem by providing an open protocol for secure, real-time data sharing.
The key word here is "open" -- it's not locked into Databricks. Any client that supports the Delta
Sharing protocol can consume shared data, whether they're on Databricks, Apache Spark, pandas,
Power BI, or any other tool.

## What Is Delta Sharing?

Delta Sharing is an open protocol developed by Databricks for secure data sharing. It allows a data
provider to share live Delta Lake tables with data recipients without copying the data.

```
Delta Sharing Overview:

┌──────────────────────────────────────────────────────────────────┐
│                       DELTA SHARING                              │
│                                                                  │
│   An open protocol for secure, real-time data sharing            │
│                                                                  │
│   Key Properties:                                                │
│   - Open protocol (not proprietary to Databricks)                │
│   - No data copying (recipients read directly from source)       │
│   - Secure (token-based authentication, fine-grained access)     │
│   - Cross-platform (works with any Delta Sharing client)         │
│   - Real-time (recipients always see the latest data)            │
│   - Centrally managed (provider controls access)                 │
│                                                                  │
└──────────────────────────────────────────────────────────────────┘
```

## How Delta Sharing Works

```
Delta Sharing Architecture:

  DATA PROVIDER                              DATA RECIPIENT
  (Databricks workspace)                     (Any platform)

  ┌──────────────────────┐                   ┌──────────────────────┐
  │                      │                   │                      │
  │  Delta Lake Tables   │                   │  Consumer Client     │
  │  ┌────────────────┐  │                   │                      │
  │  │ sales_data     │  │   Delta Sharing   │  - Databricks        │
  │  │ customer_info  │  │   Protocol        │  - Apache Spark      │
  │  │ product_catalog│  │ ────────────────▶ │  - pandas            │
  │  └────────────────┘  │   (REST API +     │  - Power BI          │
  │                      │    credential)    │  - Tableau           │
  │  Unity Catalog       │                   │  - Any REST client   │
  │  (manages shares)    │                   │                      │
  │                      │                   └──────────────────────┘
  └──────────────────────┘

  The recipient does NOT get a copy of the data.
  They get secure, read-only access to the live data.
```

## Two Sharing Models

Databricks supports two distinct models for Delta Sharing:

```
Delta Sharing Models:

┌────────────────────────────────────────────────────────────────┐
│              DATABRICKS-TO-DATABRICKS SHARING                  │
│                                                                │
│  Provider: Databricks workspace                                │
│  Recipient: Another Databricks workspace                       │
│                                                                │
│  ┌──────────────┐   Unity Catalog    ┌──────────────┐          │
│  │  Provider     │ ─────────────────▶│  Recipient    │          │
│  │  Workspace    │   (managed by UC) │  Workspace    │          │
│  └──────────────┘                    └──────────────┘          │
│                                                                │
│  Features:                                                     │
│  - Managed entirely through Unity Catalog                      │
│  - No credential files needed                                  │
│  - Recipient sees shared data as a catalog in their workspace  │
│  - Supports tables, volumes, views, models, and notebooks      │
│  - Provider can audit recipient access                         │
│  - Automatic authentication via Databricks account             │
│                                                                │
└────────────────────────────────────────────────────────────────┘

┌────────────────────────────────────────────────────────────────┐
│                   OPEN DELTA SHARING                            │
│                                                                │
│  Provider: Databricks workspace                                │
│  Recipient: Any platform (non-Databricks)                      │
│                                                                │
│  ┌──────────────┐   Credential File  ┌──────────────┐          │
│  │  Provider     │ ─────────────────▶│  Recipient    │          │
│  │  Workspace    │   (.share file)   │  (Any client) │          │
│  └──────────────┘                    └──────────────┘          │
│                                                                │
│  Features:                                                     │
│  - Uses activation links and credential files                  │
│  - Recipient downloads a .share file with connection details   │
│  - Works with open-source delta-sharing libraries              │
│  - Supports tables and partitions                              │
│  - Cross-platform (Spark, pandas, Power BI, etc.)              │
│  - Token-based authentication                                  │
│                                                                │
└────────────────────────────────────────────────────────────────┘
```

## Delta Sharing Components

```
Key Components:

┌──────────────────────────────────────────────────────────────────┐
│                                                                  │
│  SHARE                                                           │
│  ├── A named object that contains the data assets to share       │
│  ├── Created by the provider in Unity Catalog                    │
│  └── Can contain tables, views, volumes, models, notebooks       │
│                                                                  │
│  RECIPIENT                                                       │
│  ├── Represents the entity receiving the shared data             │
│  ├── Can be a Databricks workspace or an external client         │
│  └── Has an authentication type (Databricks or token-based)      │
│                                                                  │
│  PROVIDER                                                        │
│  ├── The Databricks workspace that owns and shares the data      │
│  ├── Controls what data is shared and with whom                  │
│  └── Manages access through Unity Catalog                        │
│                                                                  │
│  Relationship:                                                   │
│                                                                  │
│  PROVIDER ──creates──▶ SHARE ──granted to──▶ RECIPIENT           │
│              │                                    │               │
│              │         Contains:                  │               │
│              │         - Tables                   │               │
│              │         - Views                    │               │
│              │         - Volumes                  │               │
│              │         - Models                   │               │
│              │         - Notebooks                │               │
│              │                                    │               │
│              └── Unity Catalog manages ───────────┘               │
│                                                                  │
└──────────────────────────────────────────────────────────────────┘
```

## Creating a Share

```sql
-- Create a share
CREATE SHARE IF NOT EXISTS customer_analytics_share
COMMENT 'Shared customer analytics data for partner access';

-- Add tables to the share
ALTER SHARE customer_analytics_share
ADD TABLE production.analytics.customer_summary;

ALTER SHARE customer_analytics_share
ADD TABLE production.analytics.monthly_revenue
PARTITION (region = 'us-east');  -- Share only specific partitions

-- Add a view to the share (Databricks-to-Databricks only)
ALTER SHARE customer_analytics_share
ADD VIEW production.analytics.customer_dashboard_view;

-- View what's in a share
SHOW ALL IN SHARE customer_analytics_share;

-- Remove a table from a share
ALTER SHARE customer_analytics_share
REMOVE TABLE production.analytics.customer_summary;
```

## Creating a Recipient

```sql
-- Create a Databricks-to-Databricks recipient
CREATE RECIPIENT IF NOT EXISTS partner_workspace
USING ID 'databricks-account-id:metastore-id'
COMMENT 'Partner company Databricks workspace';

-- Create an Open Delta Sharing recipient (token-based)
CREATE RECIPIENT IF NOT EXISTS external_partner
COMMENT 'External partner using open delta sharing';
-- This generates an activation link for the recipient

-- Grant a share to a recipient
GRANT SELECT ON SHARE customer_analytics_share TO RECIPIENT partner_workspace;

-- View recipients
SHOW RECIPIENTS;

-- View grants on a share
SHOW GRANTS ON SHARE customer_analytics_share;
```

## Recipient Activation (Open Sharing)

```
Open Delta Sharing Activation Flow:

  Provider                              Recipient
  ────────                              ─────────

  1. CREATE RECIPIENT
     external_partner
          │
          ▼
  2. Activation link
     generated
          │
          ├──── sends link via email ────▶ 3. Recipient clicks
          │     or secure channel              activation link
          │                                        │
          │                                        ▼
          │                               4. Downloads .share
          │                                  credential file
          │                                        │
          │                                        ▼
          │                               5. Uses .share file
          │                                  with Delta Sharing
          │                                  client library
          │                                        │
          │                                        ▼
          │                               6. Reads shared data
          │                                  (pandas, Spark, etc.)
          │
  Provider can audit
  all recipient access
```

## The .share Credential File

```
Example .share file (JSON format):

{
  "shareCredentialsVersion": 1,
  "endpoint": "https://<workspace-url>/api/2.0/delta-sharing/",
  "bearerToken": "<access-token>",
  "expirationTime": "2025-12-31T00:00:00.000Z"
}

This file contains:
- endpoint:        The Delta Sharing server URL
- bearerToken:     Authentication token
- expirationTime:  When the token expires (can be rotated)

IMPORTANT: Treat this file like a password -- it grants access to shared data!
```

## Security and Governance

```
Delta Sharing Security Model:

┌──────────────────────────────────────────────────────────────────┐
│                     PROVIDER CONTROLS                            │
│                                                                  │
│  ┌──────────────────────────────────────────────────────────┐    │
│  │ What to share                                            │    │
│  │ - Specific tables, views, volumes                        │    │
│  │ - Specific partitions of a table                         │    │
│  │ - Column-level access (via views)                        │    │
│  └──────────────────────────────────────────────────────────┘    │
│                                                                  │
│  ┌──────────────────────────────────────────────────────────┐    │
│  │ Who can access                                           │    │
│  │ - Named recipients with explicit grants                  │    │
│  │ - Revoke access at any time                              │    │
│  │ - Token expiration and rotation                          │    │
│  └──────────────────────────────────────────────────────────┘    │
│                                                                  │
│  ┌──────────────────────────────────────────────────────────┐    │
│  │ Audit and monitoring                                     │    │
│  │ - Track who accessed what data and when                  │    │
│  │ - Unity Catalog audit logs                               │    │
│  │ - IP access lists (restrict by IP)                       │    │
│  └──────────────────────────────────────────────────────────┘    │
│                                                                  │
│  Recipients get READ-ONLY access -- they cannot modify           │
│  the provider's data                                             │
│                                                                  │
└──────────────────────────────────────────────────────────────────┘
```

## Key Exam Points

1. **Delta Sharing** is an open protocol for secure, real-time data sharing -- no data copying
2. **Two models**: Databricks-to-Databricks (managed by UC) and Open Sharing (credential file)
3. **Three key objects**: Share (what), Recipient (who), Provider (owner)
4. **Shares can contain**: tables, views, volumes, models, and notebooks
5. **Partition sharing** allows sharing only specific partitions of a table
6. **Recipients get read-only access** -- they cannot modify the provider's data
7. **Open Sharing uses .share files** with bearer tokens for authentication
8. **Databricks-to-Databricks sharing** is seamless -- recipient sees shared data as a catalog
9. **Unity Catalog manages** all sharing -- governance, access control, and auditing
10. **Delta Sharing is open source** -- not locked into Databricks; any compatible client can consume shared data
