# Data Governance using Unity Catalog

## Introduction

Now let's dive into how Unity Catalog specifically implements data governance. We covered Unity
Catalog's basics in Section 3, but here we're focusing on the governance features -- how UC
provides centralized access control, data discovery, auditing, and lineage across your entire
Databricks estate.

Unity Catalog is the governance layer that sits across all Databricks workspaces. Before UC,
each workspace had its own isolated metastore (the Hive metastore), which meant governance was
fragmented -- access controls, table metadata, and audit logs were siloed per workspace. UC
eliminates this by providing a single, centralized metastore that spans all workspaces in an
account.

## Centralized Governance Model

```
Before Unity Catalog:                    With Unity Catalog:

Workspace A         Workspace B          ┌────────────────────────┐
┌──────────┐       ┌──────────┐          │    UNITY CATALOG       │
│ Hive     │       │ Hive     │          │    METASTORE           │
│ Metastore│       │ Metastore│          │    (Account-level)     │
│          │       │          │          │                        │
│ Own ACLs │       │ Own ACLs │          │  Centralized ACLs      │
│ Own tables│      │ Own tables│         │  Centralized lineage   │
│ No lineage│      │ No lineage│         │  Centralized audit     │
│ No audit  │      │ No audit  │         │                        │
└──────────┘       └──────────┘          │  ┌──────┐  ┌──────┐   │
                                          │  │ WS A │  │ WS B │   │
Isolated ✗                                │  └──────┘  └──────┘   │
                                          └────────────────────────┘
                                          Unified ✓
```

## Three-Level Namespace

Unity Catalog organizes data into a three-level hierarchy:

```
Unity Catalog Namespace:

  ┌─────────────────────────────────────────────┐
  │                 METASTORE                   │
  │            (account-level)                  │
  │                                             │
  │  ┌──────────────────────────────────────┐   │
  │  │            CATALOG                   │   │
  │  │     (e.g., production, staging)      │   │
  │  │                                      │   │
  │  │  ┌───────────────────────────────┐   │   │
  │  │  │          SCHEMA               │   │   │
  │  │  │   (e.g., finance, marketing)  │   │   │
  │  │  │                               │   │   │
  │  │  │  ┌─────────────────────────┐  │   │   │
  │  │  │  │ TABLE / VIEW / FUNCTION │  │   │   │
  │  │  │  │ VOLUME / MODEL          │  │   │   │
  │  │  │  └─────────────────────────┘  │   │   │
  │  │  └───────────────────────────────┘   │   │
  │  └──────────────────────────────────────┘   │
  └─────────────────────────────────────────────┘

Reference: catalog.schema.table
Example:   production.finance.transactions
```

## Access Control with Unity Catalog

### Principals

Access is granted to **principals** -- the entities that can be given permissions:

```
Principals in Unity Catalog:

┌─────────────────────┬──────────────────────────────────────────┐
│ Principal Type      │ Description                              │
├─────────────────────┼──────────────────────────────────────────┤
│ User                │ Individual user (email-based identity)   │
│ Group               │ Collection of users and/or other groups  │
│ Service Principal   │ Machine identity for automated jobs      │
└─────────────────────┴──────────────────────────────────────────┘

Best Practice: Grant permissions to GROUPS, not individual users.
This makes access management scalable and auditable.
```

### Privileges

Unity Catalog uses a SQL-based privilege model:

```sql
-- Grant read access to a table
GRANT SELECT ON TABLE production.finance.transactions TO analysts;

-- Grant write access
GRANT MODIFY ON TABLE production.finance.transactions TO data_engineers;

-- Grant usage on catalog and schema (required to access objects within)
GRANT USE CATALOG ON CATALOG production TO analysts;
GRANT USE SCHEMA ON SCHEMA production.finance TO analysts;

-- Grant all privileges on a schema
GRANT ALL PRIVILEGES ON SCHEMA production.finance TO finance_team;

-- Revoke access
REVOKE SELECT ON TABLE production.finance.transactions FROM analysts;
```

### Privilege Hierarchy

```
Privilege Inheritance:

  USE CATALOG on "production"
       │
       ├── Allows seeing the catalog exists
       │   Does NOT grant access to schemas or tables within
       │
       ▼
  USE SCHEMA on "production.finance"
       │
       ├── Allows seeing the schema exists
       │   Does NOT grant access to tables within
       │
       ▼
  SELECT on "production.finance.transactions"
       │
       └── Allows reading data from the table

ALL THREE are needed to query the table!

GRANT USE CATALOG ON CATALOG production TO analysts;
GRANT USE SCHEMA ON SCHEMA production.finance TO analysts;
GRANT SELECT ON TABLE production.finance.transactions TO analysts;
```

This is critical for the exam -- granting SELECT on a table is not enough. The user also
needs USE CATALOG and USE SCHEMA to navigate to it.

### Common Privileges

```
┌────────────────┬──────────────────────────────────────────────┐
│ Privilege      │ What It Allows                               │
├────────────────┼──────────────────────────────────────────────┤
│ USE CATALOG    │ See that the catalog exists, browse schemas  │
│ USE SCHEMA     │ See that the schema exists, browse objects   │
│ SELECT         │ Read data from a table or view               │
│ MODIFY         │ Insert, update, delete data in a table       │
│ CREATE TABLE   │ Create tables in a schema                    │
│ CREATE SCHEMA  │ Create schemas in a catalog                  │
│ CREATE CATALOG │ Create catalogs in the metastore             │
│ ALL PRIVILEGES │ Grants all applicable privileges             │
│ EXECUTE        │ Run a function or stored procedure           │
│ READ FILES     │ Read files from a volume                     │
│ WRITE FILES    │ Write files to a volume                      │
└────────────────┴──────────────────────────────────────────────┘
```

### Ownership

Every securable object in Unity Catalog has an **owner**:

```
Ownership Rules:

1. The creator of an object is its initial owner
2. Owners have ALL PRIVILEGES on their objects
3. Ownership can be transferred:
   ALTER TABLE production.finance.transactions SET OWNER TO finance_team;
4. Only the owner or metastore admin can transfer ownership
5. Account admins and metastore admins can manage all objects
```

## Managed vs External Tables in Governance

```
Governance Implications:

┌─────────────────┬──────────────────────────────────────────────┐
│ Managed Tables  │ External Tables                              │
├─────────────────┼──────────────────────────────────────────────┤
│ Data stored in  │ Data stored in your own S3/GCS bucket       │
│ UC-managed      │                                              │
│ storage         │                                              │
├─────────────────┼──────────────────────────────────────────────┤
│ DROP TABLE      │ DROP TABLE removes metadata only             │
│ removes data    │ (data remains in cloud storage)              │
│ and metadata    │                                              │
├─────────────────┼──────────────────────────────────────────────┤
│ Access fully    │ Access governed by UC + cloud IAM            │
│ governed by UC  │ (both must allow access)                     │
├─────────────────┼──────────────────────────────────────────────┤
│ Simpler         │ More complex governance                      │
│ governance      │ (two permission layers)                      │
└─────────────────┴──────────────────────────────────────────────┘
```

## Data Sharing with Unity Catalog

Unity Catalog supports secure data sharing across Databricks workspaces and even with
non-Databricks consumers using **Delta Sharing**:

```
Data Sharing Models:

1. Cross-Workspace Sharing (within same account):
   → Same metastore, same catalogs
   → Users in any workspace can access shared data
   → Just grant appropriate permissions

2. Delta Sharing (across organizations):

   Provider                            Recipient
   ┌──────────────────┐               ┌──────────────────┐
   │ Databricks       │   SHARE       │ Databricks       │
   │ Workspace        │──────────────▶│ Workspace        │
   │                  │               │ (or any client   │
   │ CREATE SHARE     │   Delta       │  supporting      │
   │ ADD TABLE TO     │   Sharing     │  Delta Sharing)  │
   │ SHARE            │   Protocol    │                  │
   └──────────────────┘               └──────────────────┘

   → Open protocol (doesn't require Databricks on recipient side)
   → Read-only access for recipients
   → Provider controls what's shared and with whom
```

## Key Exam Points

1. **Unity Catalog provides centralized governance** across all workspaces in an account
2. **Three-level namespace**: catalog.schema.table (all three levels required for access)
3. **USE CATALOG + USE SCHEMA + SELECT** are all needed to query a table
4. **Grant to groups, not users** -- this is the recommended best practice
5. **Principals**: users, groups, and service principals
6. **Ownership** grants all privileges; creator is the default owner
7. **Managed tables** have simpler governance (UC controls everything); **external tables**
   require both UC and cloud IAM permissions
8. **Delta Sharing** enables cross-organization data sharing using an open protocol
9. **SQL-based privilege model**: GRANT, REVOKE, SHOW GRANTS
10. **Metastore admins** and **account admins** have elevated privileges for governance management
