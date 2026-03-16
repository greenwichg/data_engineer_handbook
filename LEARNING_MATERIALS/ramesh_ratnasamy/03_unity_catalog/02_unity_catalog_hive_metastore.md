# Unity Catalog Object Model

## Introduction

Welcome back. Now that we understand what Unity Catalog is at a high level, let's take a look at the **Unity Catalog object model**.

---

## Object Model Hierarchy

Unity Catalog uses a hierarchical structure to organize metadata and data objects.

### Hierarchy Overview

```
Metastore (Top Level)
    │
    ├─── Catalog
    │     │
    │     ├─── Schema/Database
    │     │     │
    │     │     ├─── Volumes (Managed/External)
    │     │     ├─── Tables (Managed/External)
    │     │     ├─── Views
    │     │     └─── Functions
    │     │
    │     └─── [Additional Schemas...]
    │
    ├─── Storage Credentials
    ├─── External Locations
    ├─── Connections
    ├─── Shares
    ├─── Recipients
    ├─── Providers
    │
    └─── hive_metastore (Pseudo Catalog for Legacy)
          └─── [Schemas, Tables, Views, Functions]
```

---

## Object Types: Detailed Explanation

### 1. Metastore

#### What is Metastore?

The **top-level container** for all metadata in Unity Catalog.

#### ⚠️ Important Distinction:

**Do NOT confuse:**
- Unity Catalog Metastore
- Hive Metastore

**They are two completely different objects.**

#### Key Characteristics:

| Characteristic | Details |
|---------------|---------|
| **Level** | Databricks account level |
| **Per Region** | One Metastore per AWS region |
| **Workspace Attachment** | One or more workspaces can attach to same Metastore |
| **Default Storage** | Can be paired with an S3 bucket at creation |
| **Relationship** | All other objects hang off the Metastore |

#### Storage Configuration:

**At creation time:**
- Can be paired with an S3 bucket
- Provides default storage location
- Used for managed tables and volumes

---

### 2. Catalog

#### What is Catalog?

A **logical container** within the Metastore to organize datasets.

#### New Concept ⭐

**Important Note:**
- Catalog is a **new concept** introduced by Unity Catalog
- Legacy Hive Metastore **did not have** the concept of catalogs

#### Purpose:

Organize data logically based on your requirements.

#### Common Organization Patterns:

| Pattern | Example Catalogs |
|---------|-----------------|
| **By Business Unit** | `sales_catalog`, `marketing_catalog`, `finance_catalog` |
| **By Environment** | `dev_catalog`, `test_catalog`, `prod_catalog` |
| **By Project** | `project_a_catalog`, `project_b_catalog` |
| **By Data Domain** | `customer_catalog`, `product_catalog`, `transaction_catalog` |

#### Structure:

Each catalog may contain **one or more schemas or databases**.

---

### 3. Schema / Database

#### What is Schema?

The **next level container** within catalogs.

#### Important Terminology Update

**Synonymous Terms:**
- Schema
- Database

**Historical Context:**
- Past documentation: Used term "database"
- Current recommendation: Use term "schema"

**Why the Change?**
- Avoid confusion with database systems and platforms
- Align with SQL standards
- Clearer terminology

#### ⭐ Best Practice:

**Recommended:**
```sql
CREATE SCHEMA my_schema;
```

**Still Works (but discouraged):**
```sql
CREATE DATABASE my_schema;
```

**Recommendation:** Start using the term **"schema"** rather than "database".

#### What Schemas Contain:

Each schema may contain one or more:
- Volumes
- Tables
- Views
- Functions

---

### 4. Volumes

#### What are Volumes?

**Logical volumes** that provide a high-level abstraction to paths in Amazon S3.

#### Types of Volumes:

##### Managed Volumes

**Definition:**
Fully managed by Unity Catalog.

**How It Works:**

| Aspect | Details |
|--------|---------|
| **Access Management** | Unity Catalog manages access via Unity Catalog when in Databricks |
| **Cloud Provider Access** | Unity Catalog also manages access via Cloud Provider account |
| **Ownership** | Fully owned and managed by Unity Catalog |
| **Lifecycle** | Databricks controls entire lifecycle |

**Benefits:**
- Simplified management
- Automatic access control
- Integrated governance

##### External Volumes

**Definition:**
Represent existing data in cloud storage managed **outside of Databricks** but registered in Databricks Unity Catalog.

**How It Works:**

| Aspect | Details |
|--------|---------|
| **Data Location** | Existing data in cloud storage |
| **Data Management** | Managed outside Databricks |
| **Access Control** | Unity Catalog controls access via Databricks |
| **Registration** | Registered in Unity Catalog |

**Typical Use Case:**
- Receive data from external applications (other than Databricks)
- Want to use that data in Databricks
- Don't want Databricks to own the data lifecycle

**Example Scenario:**
```
External Application → Writes to S3
                     ↓
          External Volume in Unity Catalog
                     ↓
          Databricks reads the data
```

---

### 5. Tables

#### What are Tables?

Collections of data organized by **rows and columns**.

#### Types of Tables:

##### Managed Tables

**Definition:**
Owned by Databricks Unity Catalog.

**What Unity Catalog Manages:**

| Managed Component | Description |
|------------------|-------------|
| **Metadata** | Table schema, properties, statistics |
| **Data** | The actual data files |
| **Lifecycle** | Creation, modification, deletion |

**When You Drop a Managed Table:**
- ✅ Table definition deleted
- ✅ **Data files also deleted**
- ⚠️ Data is permanently removed

**Important Restriction:**
- All managed tables in Unity Catalog are **Delta tables**
- ❌ Cannot create managed tables with formats: Parquet, CSV, JSON
- ✅ For other formats, must use **external tables**

##### External Tables

**Definition:**
Only **metadata** is managed by Databricks Unity Catalog.

**What Unity Catalog Manages:**

| Component | Managed by Unity Catalog? | Managed by Cloud Provider? |
|-----------|-------------------------|--------------------------|
| **Metadata** | ✅ Yes | ❌ No |
| **Data** | ❌ No | ✅ Yes |

**When You Drop an External Table:**
- ✅ Table definition deleted (metadata removed)
- ✅ **Data files remain intact**
- ℹ️ Data is left alone in cloud storage

**Use Cases:**

Perfect for scenarios where:
- Another solution produces the data:
  - AWS Glue
  - Fivetran
  - Other ETL tools
- Databricks only consumes the data
- You don't want Databricks to own the data

**Example Workflow:**
```
1. AWS Glue/Fivetran produces data → S3
2. Create external table in Databricks
3. Query and analyze data in Databricks
4. Drop table → Data remains in S3
```

**Additional Flexibility:**
- ✅ Can use various file formats (Parquet, CSV, JSON, etc.)
- ✅ Data persists independently of Databricks

#### Comparison: Managed vs. External Tables

| Aspect | Managed Tables | External Tables |
|--------|---------------|----------------|
| **Metadata Management** | Unity Catalog | Unity Catalog |
| **Data Management** | Unity Catalog | Cloud Provider |
| **File Format** | Delta only | Any format (Parquet, CSV, JSON, etc.) |
| **Drop Behavior** | Deletes data | Keeps data |
| **Best For** | Databricks-owned workflows | External data sources |
| **Data Lifecycle** | Controlled by Databricks | Independent of Databricks |

**Note:** Don't worry if you haven't fully understood the difference yet. This will be demonstrated with examples in later lessons.

---

### 6. Views

#### What are Views?

Virtual tables based on queries over one or more tables.

**Characteristics:**
- Store query logic, not data
- Computed dynamically when accessed
- Can simplify complex queries
- Can restrict access to specific columns/rows

---

### 7. Functions

#### What are Functions?

Reusable routines that can be called from SQL or DataFrame operations.

**Use Cases:**
- Encapsulate transformation logic
- Standardize calculations
- Promote code reuse
- Simplify complex operations

---

### 8. Storage Credentials

#### What are Storage Credentials?

Objects that hold credentials for accessing external cloud services.

**Purpose:**
- Securely store authentication information
- Access cloud storage locations
- Manage permissions centrally

**Example Use Case:**
Hold credentials for accessing an Amazon S3 bucket or other AWS services.

---

### 9. External Locations

#### What are External Locations?

Objects that, combined with storage credentials, allow access to cloud storage or data lakes **other than** the default storage attached to the Metastore.

**Relationship:**
```
Storage Credential + External Location = Access to External Storage
```

**Purpose:**
- Access additional storage locations
- Connect to data lakes beyond default Metastore storage
- Centralized access management

---

### 10. Connections

#### What are Connections?

Credentials that give **read-only access** to external databases in database systems.

**Supported Database Systems:**
- MySQL
- PostgreSQL
- SQL Server
- And others

**How It Works:**

```
1. Create Connection in Unity Catalog
   ↓
2. Store database credentials securely
   ↓
3. Access external database via Lakehouse Federation
   ↓
4. Query external data as if it's in Databricks
```

**Use Case:**
- Query data from operational databases
- Join external data with lakehouse data
- Avoid data duplication

---

### 11. Delta Sharing Objects

Unity Catalog introduced three objects to handle **Delta Sharing**:

#### Share

**Purpose:**
Define what data to share with external parties.

#### Recipient

**Purpose:**
Define who receives the shared data.

#### Provider

**Purpose:**
Manage the sharing relationship and permissions.

**Delta Sharing:**
- Enables secure data sharing
- Across organizations
- Without copying data
- Live access to fresh data

---

### 12. Hive Metastore (Pseudo Catalog)

#### Purpose of Backward Compatibility

**Important:**
Using Unity Catalog doesn't mean you **can't** access Legacy Hive Metastore.

**Databricks Commitment:**
- ✅ 100% backward compatibility with Hive Metastore
- ✅ Existing workloads continue to work

#### How It Works

**Implementation:**
Achieved via a **pseudo catalog** called `hive_metastore`.

**Automatic Creation:**
- Automatically created by Databricks
- Present in **every** Databricks workspace

#### What You Can Do

**Objects Supported in hive_metastore:**

| Object Type | Supported |
|------------|-----------|
| **Schemas/Databases** | ✅ Yes |
| **Tables** | ✅ Yes (Managed & External) |
| **Views** | ✅ Yes |
| **Functions** | ✅ Yes |

**Creation:**
Similar to creating them via Unity Catalog.

#### Limitations

**What You DON'T Get:**

Objects created under `hive_metastore` catalog **do not** receive Unity Catalog benefits:
- ❌ Better governance
- ❌ Data lineage
- ❌ Enhanced data security
- ❌ Fine-grained access control
- ❌ Audit logging

**⚠️ Recommendation:**
**Refrain from using Hive Metastore for any new projects.**

Use it only for:
- Legacy compatibility
- Existing workloads
- Backward compatibility scenarios

---

## Namespace Conventions

### Three-Level Namespace (Unity Catalog)

With the hierarchical object structure, you must use a **three-level namespace** to access objects.

#### Syntax:

```sql
catalog.schema.object_name
```

#### Examples:

**Access a Table:**
```sql
SELECT * FROM my_catalog.my_schema.my_table;
```

**Access a View:**
```sql
SELECT * FROM sales_catalog.monthly.revenue_view;
```

**Access a Function:**
```sql
SELECT my_catalog.transformations.clean_name('John Doe');
```

**Access Legacy Tables in hive_metastore:**
```sql
SELECT * FROM hive_metastore.default.legacy_table;
```

### Two-Level Namespace (Legacy - Without Unity Catalog)

**When Unity Catalog is NOT enabled:**

If a Databricks workspace is not enabled with Unity Catalog, you can use a **two-level namespace**.

#### Why?

The `hive_metastore` catalog is your **default catalog**, so it's implicit.

#### Syntax:

```sql
schema.table_name
```

#### Example:

```sql
SELECT * FROM default.my_table;
```

**Equivalent to:**
```sql
SELECT * FROM hive_metastore.default.my_table;
```

### When Unity Catalog is Enabled

**Important:**
When you enable a Databricks workspace with Unity Catalog, you **must use the three-level namespace**.

**Why?**
- Multiple catalogs exist
- Must specify which catalog
- No default catalog assumption

---

## Namespace Comparison

### Without Unity Catalog

| Namespace Level | Component |
|----------------|-----------|
| **Level 1** | Schema |
| **Level 2** | Table/View/Function |

**Example:** `schema.table`

### With Unity Catalog

| Namespace Level | Component |
|----------------|-----------|
| **Level 1** | Catalog |
| **Level 2** | Schema |
| **Level 3** | Table/View/Function |

**Example:** `catalog.schema.table`

---

## Complete Object Model Diagram

```
┌─────────────────────────────────────────────────────────────────┐
│                        METASTORE                                │
│                    (Account Level)                              │
│  ┌──────────────────────────────────────────────────────────┐   │
│  │                   Unity Catalog Objects                  │   │
│  │                                                          │   │
│  │  ┌────────────┐  ┌────────────┐  ┌────────────┐          │   │
│  │  │  Catalog   │  │  Catalog   │  │  Catalog   │          │   │
│  │  │   (dev)    │  │   (test)   │  │   (prod)   │          │   │
│  │  │            │  │            │  │            │          │   │
│  │  │ ┌────────┐ │  │            │  │            │          │   │
│  │  │ │ Schema │ │  │            │  │            │          │   │
│  │  │ │        │ │  │            │  │            │          │   │
│  │  │ │├Volumes│ │  │            │  │            │          │   │
│  │  │ │├Tables │ │  │            │  │            │          │   │
│  │  │ │├Views  │ │  │            │  │            │          │   │
│  │  │ │└Funcs  │ │  │            │  │            │          │   │
│  │  │ └────────┘ │  │            │  │            │          │   │
│  │  └────────────┘  └────────────┘  └────────────┘          │   │
│  │                                                          │   │
│  │  ┌───────────────────┐  ┌──────────────────┐             │   │
│  │  │Storage Credentials│  │External Locations│             │   │
│  │  └───────────────────┘  └──────────────────┘             │   │
│  │                                                          │   │
│  │  ┌───────────┐  ┌───────┐  ┌──────────┐  ┌──────────┐    │   │
│  │  │Connections│  │Shares │  │Recipients│  │Providers │    │   │
│  │  └───────────┘  └───────┘  └──────────┘  └──────────┘    │   │
│  └──────────────────────────────────────────────────────────┘   │
│                                                                 │
│  ┌────────────────────────────────────────────────────────────┐ │
│  │              hive_metastore (Pseudo Catalog)               │ │
│  │                    Legacy Compatibility                    │ │
│  │                                                            │ │
│  │  ┌────────┐  ┌────────┐  ┌────────┐                        │ │
│  │  │ Schema │  │ Schema │  │ Schema │                        │ │
│  │  │(Tables)│  │(Tables)│  │(Tables)│                        │ │
│  │  │(Views) │  │(Views) │  │(Views) │                        │ │
│  │  │(Funcs) │  │(Funcs) │  │(Funcs) │                        │ │
│  │  └────────┘  └────────┘  └────────┘                        │ │
│  └────────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────────┘
```

---

## Quick Reference: All Object Types

### Primary Data Objects

| Object | Level | Purpose | Types |
|--------|-------|---------|-------|
| **Metastore** | Top | Container for all metadata | - |
| **Catalog** | 2nd | Logical grouping | - |
| **Schema** | 3rd | Container within catalog | - |
| **Volume** | 4th | File storage abstraction | Managed, External |
| **Table** | 4th | Structured data | Managed (Delta only), External (any format) |
| **View** | 4th | Virtual table | - |
| **Function** | 4th | Reusable logic | - |

### Access & Security Objects

| Object | Purpose |
|--------|---------|
| **Storage Credential** | Cloud service authentication |
| **External Location** | Access to external storage |
| **Connection** | External database access |

### Sharing Objects

| Object | Purpose |
|--------|---------|
| **Share** | Define shared data |
| **Recipient** | Define data recipients |
| **Provider** | Manage sharing |

### Legacy Object

| Object | Purpose |
|--------|---------|
| **hive_metastore** | Backward compatibility catalog |

---

## Summary

### Key Takeaways:

1. **Metastore** is the top-level container (one per region)
2. **Catalogs** organize data logically (new Unity Catalog concept)
3. **Schemas** are containers within catalogs (use this term, not "database")
4. **Volumes** provide file access (managed vs. external)
5. **Tables** store structured data (managed Delta only, external any format)
6. **Three-level namespace** required: `catalog.schema.object`
7. **hive_metastore** provides legacy compatibility
8. **Don't use hive_metastore** for new projects

### What Makes Unity Catalog Powerful:

| Feature | Legacy (Hive Metastore) | Unity Catalog |
|---------|------------------------|---------------|
| **Hierarchy** | 2-level | 3-level |
| **Catalogs** | ❌ No | ✅ Yes |
| **Volumes** | ❌ No | ✅ Yes |
| **Fine-grained Access** | ❌ Limited | ✅ Row/Column level |
| **Data Lineage** | ❌ No | ✅ Yes |
| **Audit Logging** | ❌ Limited | ✅ Comprehensive |
| **Delta Sharing** | ❌ No | ✅ Yes |

### Don't Worry If Overwhelmed!

**It's Normal:**
This may feel overwhelming if you're new to Databricks.

**What's Next:**
- Each object will be covered in detail
- Hands-on examples in upcoming lessons
- Focus on what's needed for certification exam
- Progressive learning approach

**You'll become comfortable with these concepts as we progress through the course!**

---

## CONCEPT GAP: Unity Catalog Permissions Model

Understanding the Unity Catalog permissions model is critical for certification exams. Unity Catalog uses a **hierarchical, inherited permissions model** similar to file system permissions.

### Securable Objects Hierarchy

```
┌─────────────────────────────────────────────────────────┐
│                     METASTORE                           │
│  Permissions: CREATE CATALOG, USE PROVIDER, SET SHARE   │
│                                                         │
│  ┌───────────────────────────────────────────────────┐  │
│  │                   CATALOG                         │  │
│  │  Permissions: USE CATALOG, CREATE SCHEMA          │  │
│  │                                                   │  │
│  │  ┌─────────────────────────────────────────────┐  │  │
│  │  │                 SCHEMA                      │  │  │
│  │  │  Permissions: USE SCHEMA, CREATE TABLE,     │  │  │
│  │  │               CREATE VOLUME, CREATE FUNCTION│  │  │
│  │  │                                             │  │  │
│  │  │  ┌──────────┐ ┌──────┐ ┌────────┐           │  │  │
│  │  │  │  TABLE   │ │ VIEW │ │FUNCTION│           │  │  │
│  │  │  │ SELECT   │ │      │ │EXECUTE │           │  │  │
│  │  │  │ MODIFY   │ │      │ │        │           │  │  │
│  │  │  └──────────┘ └──────┘ └────────┘           │  │  │
│  │  └─────────────────────────────────────────────┘  │  │
│  └───────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────┘
```

### Key Permission Inheritance Rules

- **USE CATALOG** is required before any object inside the catalog can be accessed
- **USE SCHEMA** is required before any object inside the schema can be accessed
- Permissions do NOT automatically cascade downward; you must grant at each level
- The owner of an object has ALL PRIVILEGES on that object

---

## CONCEPT GAP: Managed vs External Tables -- Data Lifecycle Deep Dive

This is a frequently tested topic on certification exams. Understanding precisely what happens to data at each lifecycle event is essential.

### Lifecycle Comparison

```
MANAGED TABLE LIFECYCLE:
========================
  CREATE TABLE t1 (id INT, name STRING);
       │
       ▼
  ┌──────────────────────────────┐
  │  Metastore Default Storage   │
  │  or Catalog/Schema Storage   │
  │  ┌────────────────────────┐  │
  │  │  Delta files created   │  │
  │  │  (data + metadata)     │  │
  │  └────────────────────────┘  │
  └──────────────────────────────┘
       │
  DROP TABLE t1;
       │
       ▼
  ┌──────────────────────────────┐
  │  Data files: DELETED         │
  │  Metadata:   DELETED         │
  │  History:    DELETED         │
  └──────────────────────────────┘


EXTERNAL TABLE LIFECYCLE:
=========================
  CREATE TABLE t2 (id INT, name STRING)
  LOCATION 's3://bucket-name/path';
       │
       ▼
  ┌──────────────────────────────┐
  │  User-specified location     │
  │  ┌────────────────────────┐  │
  │  │  Data files at LOCATION│  │
  │  │  (any format)          │  │
  │  └────────────────────────┘  │
  └──────────────────────────────┘
       │
  DROP TABLE t2;
       │
       ▼
  ┌──────────────────────────────┐
  │  Data files: REMAIN INTACT   │
  │  Metadata:   DELETED         │
  │  Can re-register later       │
  └──────────────────────────────┘
```

---

## CONCEPT GAP: Unity Catalog vs Hive Metastore Feature Comparison

### Governance Capabilities Comparison

| Capability | Hive Metastore | Unity Catalog |
|-----------|---------------|---------------|
| **Table ACLs** | Basic (workspace-level) | Fine-grained (account-level) |
| **Row-level security** | Not supported | Supported via row filters |
| **Column masking** | Not supported | Supported via column masks |
| **Data lineage** | Not available | Automatic, built-in |
| **Audit logging** | Limited | Comprehensive system tables |
| **Cross-workspace access** | Not possible | Supported via shared metastore |
| **Delta Sharing** | Not available | Built-in |
| **Tags and classification** | Not available | Supported |
| **Identity federation** | Workspace-local | Account-level identity |
| **Centralized governance** | Per-workspace only | Across all workspaces |

### Data Access Patterns

```
HIVE METASTORE (Legacy):
┌──────────────┐     ┌──────────────┐
│ Workspace A  │     │ Workspace B  │
│ ┌──────────┐ │     │ ┌──────────┐ │
│ │  Hive    │ │     │ │  Hive    │ │
│ │ Metastore│ │     │ │ Metastore│ │
│ └──────────┘ │     │ └──────────┘ │
│  (isolated)  │     │  (isolated)  │
└──────────────┘     └──────────────┘
     No data sharing between workspaces


UNITY CATALOG:
┌──────────────────────────────────┐
│     Unity Catalog Metastore      │
│   (Shared across workspaces)     │
└──────────┬───────────┬───────────┘
           │           │
   ┌───────▼──┐  ┌─────▼────┐
   │Workspace │  │Workspace │
   │    A     │  │    B     │
   └──────────┘  └──────────┘
     Same data accessible from both
```

---

## CONCEPT GAP: Delta Sharing Protocol

Delta Sharing is an open protocol for secure data sharing that is tightly integrated with Unity Catalog. It is increasingly tested on certification exams.

### How Delta Sharing Works

```
┌─────────────────────┐          ┌─────────────────────┐
│    DATA PROVIDER    │          │    DATA RECIPIENT   │
│                     │          │                     │
│  Unity Catalog      │          │  Any platform:      │
│  ┌────────────────┐ │  Share   │  - Databricks       │
│  │  Share Object  │─┼─────────▶│  - Apache Spark    │
│  │  (tables/views)│ │          │  - Pandas           │
│  └────────────────┘ │          │  - Power BI         │
│  ┌────────────────┐ │          │  - Custom apps      │
│  │   Recipient    │ │          │                     │
│  │   Object       │ │          │  No data copying!   │
│  └────────────────┘ │          │  Read live data.    │
└─────────────────────┘          └─────────────────────┘
```

### Key Facts for Exams
- Delta Sharing is an **open-source protocol** (not proprietary)
- Recipients do NOT need to use Databricks
- Data is NOT copied; recipients read directly from provider storage
- Shares can include tables, views, and notebooks
- Providers control what data is shared and with whom

---

## KEY INTERVIEW QUESTIONS AND ANSWERS

### Q1: What is the difference between a Unity Catalog Metastore and a Hive Metastore?
**A:** The Unity Catalog Metastore is the top-level container in the Unity Catalog governance model, created at the Databricks account level with one per cloud region. It provides centralized governance, data lineage, fine-grained access control, and cross-workspace data sharing. The Hive Metastore is a legacy, workspace-level metadata store that lacks these governance features. They are completely separate systems; enabling Unity Catalog does not remove the Hive Metastore but makes it available as a pseudo-catalog called `hive_metastore` for backward compatibility.

### Q2: What is the three-level namespace in Unity Catalog and why is it important?
**A:** The three-level namespace follows the pattern `catalog.schema.object` (e.g., `prod_catalog.sales.customers`). It is required when Unity Catalog is enabled because multiple catalogs can exist, so you must specify which catalog contains the object. This replaces the legacy two-level namespace (`schema.object`) used with Hive Metastore. The three-level namespace enables better data organization, isolation, and governance across business units, environments, or projects.

### Q3: What happens when you drop a managed table vs. an external table in Unity Catalog?
**A:** When you drop a managed table, both the metadata and the underlying data files are deleted permanently. When you drop an external table, only the metadata (table definition) is removed from Unity Catalog; the underlying data files remain intact in cloud storage. This makes external tables suitable for scenarios where data is produced by external systems (AWS Glue, Fivetran) and you do not want Databricks to own the data lifecycle.

### Q4: Why can managed tables in Unity Catalog only be Delta format?
**A:** Unity Catalog requires managed tables to be in Delta format because Delta Lake provides ACID transactions, schema enforcement, time travel, and audit history capabilities that are essential for Unity Catalog's governance features. These features enable Unity Catalog to reliably manage the full data lifecycle including lineage tracking, access control enforcement, and data versioning. External tables can use any format (Parquet, CSV, JSON, etc.) since Unity Catalog only manages their metadata.

### Q5: Explain the role of the `hive_metastore` pseudo-catalog in Unity Catalog.
**A:** The `hive_metastore` is a pseudo-catalog automatically created in every Databricks workspace to provide 100% backward compatibility with the legacy Hive Metastore. It allows existing workloads to continue functioning after Unity Catalog is enabled. Objects created under `hive_metastore` do not benefit from Unity Catalog governance features such as fine-grained access control, data lineage, or audit logging. Databricks recommends refraining from using it for new projects and migrating existing objects to proper Unity Catalog catalogs.

### Q6: How does Unity Catalog handle cross-workspace data access?
**A:** Unity Catalog enables cross-workspace data access by having multiple workspaces in the same cloud region attach to a single Metastore. Since the Metastore is an account-level resource (not workspace-level), all attached workspaces share the same catalogs, schemas, and tables. This eliminates the data silos that existed with Hive Metastore, where each workspace had its own isolated metadata store and data could not be easily shared.

### Q7: What are Volumes in Unity Catalog and how do they differ from tables?
**A:** Volumes are logical abstractions over cloud storage containers that provide governance for non-tabular data (files). Unlike tables which organize data into rows and columns, volumes manage raw files such as CSVs, images, ML model artifacts, or any unstructured data. Managed volumes have their lifecycle fully controlled by Unity Catalog (data deleted on drop), while external volumes reference existing data in cloud storage managed outside Databricks (data persists on drop). Volumes were a new concept introduced with Unity Catalog.

### Q8: What is Delta Sharing and how does it relate to Unity Catalog?
**A:** Delta Sharing is an open-source protocol for secure data sharing integrated into Unity Catalog. It uses three objects: Shares (define what data to share), Recipients (define who receives data), and Providers (manage the sharing relationship). Key benefits include sharing data across organizations without copying it, supporting recipients on any platform (not just Databricks), and providing live access to fresh data. Recipients read data directly from the provider's storage, and all sharing is governed through Unity Catalog's permission model.

---

*End of lesson*
