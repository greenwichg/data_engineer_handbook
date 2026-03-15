# Legacy Privilege Model

## Introduction

This is a short but important topic. Before Unity Catalog, Databricks used a different access
control system called the **legacy privilege model** (also known as the **Hive metastore-based
access control** or **workspace-level access control**). You need to understand what it was,
why it was replaced, and how it differs from Unity Catalog's model. This comes up on the exam
as a comparison question.

## The Legacy Model

The legacy privilege model was tied to the **Hive metastore** -- the original metadata store
in Databricks workspaces:

```
Legacy Privilege Model:

┌──────────────────────────────────────────────────────────┐
│                WORKSPACE A                               │
│                                                          │
│  ┌──────────────────────────────────────────────────┐   │
│  │              HIVE METASTORE                      │   │
│  │                                                  │   │
│  │  Two-level namespace:                            │   │
│  │    database.table                                │   │
│  │    (e.g., finance.transactions)                  │   │
│  │                                                  │   │
│  │  Access control via:                             │   │
│  │    - Table ACLs (workspace admin enables)        │   │
│  │    - Cluster-level permissions                   │   │
│  │                                                  │   │
│  └──────────────────────────────────────────────────┘   │
│                                                          │
│  Scope: This workspace ONLY                              │
│  No cross-workspace sharing                              │
│  No centralized governance                               │
└──────────────────────────────────────────────────────────┘
```

## Key Differences: Legacy vs Unity Catalog

```
┌──────────────────────────┬───────────────────────┬────────────────────────┐
│ Feature                  │ Legacy (Hive)         │ Unity Catalog          │
├──────────────────────────┼───────────────────────┼────────────────────────┤
│ Namespace                │ Two-level             │ Three-level            │
│                          │ (database.table)      │ (catalog.schema.table) │
├──────────────────────────┼───────────────────────┼────────────────────────┤
│ Scope                    │ Single workspace      │ Cross-workspace        │
│                          │                       │ (account-level)        │
├──────────────────────────┼───────────────────────┼────────────────────────┤
│ Data lineage             │ Not available         │ Built-in, automatic    │
├──────────────────────────┼───────────────────────┼────────────────────────┤
│ Audit logging            │ Basic                 │ Comprehensive          │
│                          │                       │ (system tables)        │
├──────────────────────────┼───────────────────────┼────────────────────────┤
│ Row/column security      │ Dynamic views only    │ Native row filters,    │
│                          │                       │ column masks, and      │
│                          │                       │ dynamic views          │
├──────────────────────────┼───────────────────────┼────────────────────────┤
│ Storage management       │ Manual (mount points) │ Managed + external     │
│                          │                       │ locations              │
├──────────────────────────┼───────────────────────┼────────────────────────┤
│ Identity federation      │ Workspace-level       │ Account-level          │
│                          │                       │ (IAM, SSO)             │
├──────────────────────────┼───────────────────────┼────────────────────────┤
│ Data sharing             │ Not built-in          │ Delta Sharing          │
├──────────────────────────┼───────────────────────┼────────────────────────┤
│ Governed asset types     │ Tables, views         │ Tables, views,         │
│                          │                       │ functions, volumes,    │
│                          │                       │ models, connections    │
├──────────────────────────┼───────────────────────┼────────────────────────┤
│ Access control model     │ Table ACLs            │ SQL GRANT/REVOKE       │
│                          │ (cluster-dependent)   │ (enforced everywhere)  │
├──────────────────────────┼───────────────────────┼────────────────────────┤
│ Status                   │ Legacy/deprecated     │ Current standard       │
└──────────────────────────┴───────────────────────┴────────────────────────┘
```

## Legacy Table ACLs

In the legacy model, table access control worked like this:

```sql
-- Legacy table ACL syntax (Hive metastore)
-- Note: required cluster to have "Table Access Control" enabled

GRANT SELECT ON TABLE finance.transactions TO `alice@company.com`;
GRANT SELECT ON DATABASE finance TO `analysts`;
DENY SELECT ON TABLE finance.salary TO `analysts`;

-- Two-level namespace (no catalog level)
USE DATABASE finance;
SELECT * FROM transactions;
```

```
Legacy ACL Limitations:

1. Only enforced on clusters with Table ACL mode enabled
   → Users on non-ACL clusters could bypass all permissions!

2. Workspace-scoped
   → Permissions didn't carry across workspaces
   → Had to manage ACLs separately in each workspace

3. Cluster-dependent security
   → Different cluster types had different security guarantees
   → Admin had to ensure correct cluster configuration

4. No fine-grained access
   → No native row-level or column-level security
   → Required creating views as workarounds
```

## Mount Points (Legacy Storage Access)

The legacy model used **mount points** to access cloud storage:

```python
# Legacy approach: mount an S3 bucket
dbutils.fs.mount(
    source="s3://my-data-bucket/landing",
    mount_point="/mnt/landing",
    extra_configs={"fs.s3a.access.key": "...", "fs.s3a.secret.key": "..."}
)

# Then access data via the mount point
df = spark.read.json("/mnt/landing/orders/")
```

```
Mount Points vs External Locations:

Mount Points (Legacy):
  ✗ Credentials stored in plain text or secret scopes
  ✗ Any user with cluster access can read mounted data
  ✗ No Unity Catalog governance on the data
  ✗ No audit trail for file access
  ✗ Workspace-specific (each workspace mounts separately)

External Locations (Unity Catalog):
  ✓ Credentials managed by storage credentials (IAM roles)
  ✓ Access controlled by GRANT/REVOKE
  ✓ Full audit trail
  ✓ Cross-workspace governance
  ✓ Fine-grained permissions (READ FILES, WRITE FILES)
```

## Migration from Legacy to Unity Catalog

```
Migration Path:

Step 1: Enable Unity Catalog on the account
Step 2: Create a UC metastore and attach to workspaces
Step 3: Migrate Hive metastore tables to UC catalogs
        - Managed tables: SYNC or recreate
        - External tables: register with external locations
Step 4: Replicate access controls using GRANT statements
Step 5: Update notebooks/jobs to use three-level namespace
Step 6: Replace mount points with external locations / volumes
Step 7: Deprecate legacy Hive metastore usage

The hive_metastore catalog:
  → Legacy tables still appear under "hive_metastore" catalog in UC
  → Acts as a compatibility bridge during migration
  → Three-level reference: hive_metastore.database.table
  → Should be migrated to a proper UC catalog over time
```

## Key Exam Points

1. **Legacy model uses two-level namespace** (database.table); **UC uses three-level**
   (catalog.schema.table)
2. **Legacy ACLs are workspace-scoped**; **UC governance is account-scoped** (cross-workspace)
3. **Legacy ACLs only enforced on Table ACL-enabled clusters** -- a major security gap
4. **UC enforces permissions on all compute types** (SQL warehouses, shared clusters,
   single-user clusters)
5. **Mount points are legacy**; **external locations** are the UC replacement
6. **hive_metastore catalog** provides backward compatibility for legacy tables in UC
7. **Legacy model lacks**: lineage, comprehensive audit logging, Delta Sharing, row/column
   security, cross-workspace governance
8. **Migration involves**: registering tables in UC, converting mount points to external
   locations, updating namespace references
9. **Unity Catalog is the current standard** -- the legacy model is deprecated for new
   deployments
10. **The exam may test**: why UC is better than the legacy model, or ask you to identify
    which features are UC-only vs available in both
