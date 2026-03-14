# Introduction to Unity Catalog

## Welcome to a New Section

Welcome to a new section of the course.

### What We'll Cover:

In this section I'll give you:

1. **Introduction to Unity Catalog** - Databricks' recommended solution for data governance
2. **Configuration Guide** - How to configure Unity Catalog objects for data engineering solutions

---

## Understanding Physical Data Architecture

So far we have been talking about the **Medallion Architecture** at a conceptual level.

### What We Haven't Covered Yet:

We haven't discussed:
- Where and how data in a Data Lakehouse is physically stored
- How Databricks enables access to the data
- What objects can be created from the data (tables, views, etc.)

### What We Need to Learn:

**To implement Data Lakehouse solutions, we need to understand:**
- Physical data architecture in Databricks
- Data access methods
- Object creation and management

---

## Data Engineering Requirements

### Core Requirements:

Any data engineering project requires the ability to:

1. **Read Data** - From storage solutions
2. **Transform Data** - Apply necessary transformations
3. **Write Data** - Store transformed data back to storage

### Storage Solutions in Databricks

**Databricks Capabilities:**
- Can read and write data from a variety of storage solutions
- Focus: **Cloud object storage** (most common for Data Lakehouses)

### Cloud Object Storage by Provider:

| Cloud Provider | Storage Service |
|---------------|----------------|
| **Azure** | Azure Data Lake Storage (ADLS) Gen2 |
| **AWS** | S3 |
| **Google Cloud** | Google Cloud Storage (GCS) |

**For This Course:**
- We're working in Azure
- Storage: **ADLS Gen2**
- Compute Engine: **Apache Spark**

---

## Evolution of Data Access in Databricks

### Timeline Overview

Databricks has evolved its data access approach over time:

```
+=============================+          +=============================+
|   Launch ---> 2022          |          |   Late 2022 ---> Present    |
|                             |          |                             |
|    LEGACY SOLUTION          |  ------> |    UNITY CATALOG            |
|    - DBFS                   |          |    (Recommended)            |
|    - Hive Metastore         |          |    - Volumes                |
|    - Workspace-level only   |          |    - Account-level govnce   |
+=============================+          +=============================+
```

### The Shift: Workspace-Level to Account-Level Governance

```
  LEGACY (Workspace-Level)                 UNITY CATALOG (Account-Level)
+---------------------------+          +----------------------------------+
| Workspace A               |          |        Databricks Account        |
|  +-------+  +-------+    |          |  +----------------------------+  |
|  | Hive  |  | DBFS  |    |          |  |      Unity Catalog         |  |
|  | Meta  |  |       |    |          |  |      Metastore             |  |
|  +-------+  +-------+    |          |  +----------------------------+  |
+---------------------------+          |       /          |          \    |
                                       |      /           |           \   |
| Workspace B               |          | +------+    +------+    +------+|
|  +-------+  +-------+    |          | | WS A |    | WS B |    | WS C ||
|  | Hive  |  | DBFS  |    |          | +------+    +------+    +------+|
|  | Meta  |  |       |    |          +----------------------------------+
|  +-------+  +-------+    |
+---------------------------+          All workspaces share one metastore
                                       per region = CENTRALIZED governance
Each workspace has its OWN
metastore = SILOED governance
```

### Legacy Solution (Original)

**Components:**
- Databricks File System (DBFS)
- Hive Metastore

**Status:**
- Widely adopted in industry
- Still supported for backward compatibility
- Considered legacy by Databricks
- Challenges with data security and governance

### Unity Catalog (Current Recommendation)

**Launch:** Late 2022

**Purpose:**
- Address challenges of legacy solution
- Provide robust data governance
- Better data security

**Databricks Recommendation:**
Use **Unity Catalog for all new projects**

---

## Course Coverage Plan

### Legacy Solution Coverage

**Why Learn the Legacy Solution?**

Despite being considered legacy:
- Widely used in the industry
- Fully supported by Databricks for backward compatibility
- Most documentation still references it
- May appear on exam (a few questions)

**Recommendation:** You should be aware of the legacy solution.

### This Section's Focus

**What We'll Cover:**

1. **Introduction to Accessing Data via Unity Catalog**
2. **Unity Catalog Object Model**
3. **Configure Databricks Workspace** for Unity Catalog
4. **Prepare for Future Lessons** - Make it easier to understand solutions

### Later Section Coverage

**Data Governance Section:**
- In-depth Unity Catalog data governance capabilities
- Advanced security features
- Audit logging
- Data lineage

---

## Legacy Solution: DBFS and Hive Metastore

### Core Components

The legacy solution consists of two main components:

1. **Databricks File System (DBFS)**
2. **Hive Metastore**

---

## Databricks File System (DBFS)

### What is DBFS?

A **distributed file system** that's fully integrated within Databricks.

### Key Characteristics

**Abstraction Layer:**
- Provides abstraction over cloud storage
- Works with Azure Data Lake Storage, AWS S3, GCS
- Simplifies access to cloud storage

### How DBFS Works in Azure

**Mounting Example:**
1. Mount a container from Azure Data Lake Storage into DBFS
2. Access it like a shared drive on your computer
3. Simple file access without complex authentication

### Accessing DBFS

**From a Notebook:**

| Access Method | Description |
|--------------|-------------|
| **Spark API** | Programmatic access via Spark |
| **dbutils.fs** | File system utility (covered earlier) |
| **%fs magic command** | Quick file operations |

**From Databricks:**
- Databricks cluster
- Databricks job

### Best Use Case

**Ideal For:**
- Accessing files in cloud storage
- **Especially**: Files containing **unstructured data**

---

## Hive Metastore

### What is Hive Metastore?

A metadata repository for **structured and semi-structured data**.

### When to Use Hive Metastore

**Use Case:**
If your files are structured or semi-structured, you may want to access them via **tables** instead of raw files.

**This is where Hive Metastore comes in.**

### How Hive Metastore Works

#### 1. Table Creation

**Process:**
- Create tables over data in cloud storage
- Hive Metastore registers the tables

#### 2. Metadata Storage

**Information Stored:**
- Column names
- Data types
- Partitions
- Schema information
- Storage location

#### 3. Query Capability

**Benefits:**
- Query data through SQL queries
- Similar to traditional databases
- Familiar interface for analysts

### Hive Metastore Objects

**What You Can Create:**

| Object Type | Purpose |
|------------|---------|
| **Tables** | Structured data access |
| **Views** | Summaries of filtered data |
| **Functions** | Abstract transformation logic |

### Security Features

**Access Control:**
- Restrict or grant access to Metastore objects
- Based on user roles
- Basic role-based access control

---

## Limitations of Legacy Solution

### Adoption and Usage

**Industry Adoption:**
- Widely adopted
- Used by customers for **over 7 years**
- Proven technology

### Identified Limitations

Despite widespread use, the legacy solution has limitations:

#### 1. Limited Access Control

**Problem:**
- Lack of fine-grained access control
- No row-level access control
- No column-level access control

**Impact:**
Cannot restrict access to specific rows or columns within a table.

#### 2. No Audit Logging

**Problem:**
- Limited audit capabilities
- Difficult to track who accessed what data

**Impact:**
Compliance and security concerns.

#### 3. No Data Lineage

**Problem:**
- No built-in data lineage tracking
- Difficult to trace data flow

**Impact:**
Cannot easily track data origins and transformations.

#### 4. Multi-Cloud Limitations

**Problem:**
- Support challenges for multi-cloud environments
- Not optimized for cross-cloud scenarios

**Impact:**
Complex setup for organizations using multiple cloud providers.

---

## Unity Catalog: The Modern Solution

### Introduction

**Launch:** Late 2022

**Purpose:** Address limitations of the legacy solution (Hive Metastore and DBFS).

### Core Capabilities

Unity Catalog provides comprehensive data access and governance.

---

## Unity Catalog Objects

### 1. Tables and Views

**Similar to Hive Metastore:**
- Create tables on structured data
- Create views for summaries and filtered data

### 2. Functions

**Purpose:**
- Abstract transformation logic
- Reusable data transformations

### 3. Volumes (New!)

**What is a Volume?**

An **abstraction layer** on top of files in cloud storage.

**Purpose:**
- **Recommended approach** for reading and writing files in Lakehouse
- **Especially for**: Files containing unstructured data

**Benefits:**
- Unified access control
- Consistent governance model
- Simplified file management

---

## Unified Solution Benefits

### Key Advantage

Unity Catalog provides a **unified solution** for accessing:
- Files (via Volumes)
- Table objects (via Tables/Views)

**Result:**
Streamlines access control requirements - one governance model for all data types.

---

## Unity Catalog Additional Benefits

Beyond basic object access, Unity Catalog offers:

### 1. Data Lineage

**Capabilities:**
- Track data origins
- Trace transformations
- Understand data flow

### 2. Data Security

**Enhanced Security:**
- Fine-grained access control
- Row-level security
- Column-level security
- Attribute-based access control

### 3. Data Governance

**Comprehensive Governance:**
- Audit logging
- Compliance support
- Policy enforcement
- Centralized management

**Note:** These features will be covered in detail under the **Data Governance section** of the course.

---

## Comparison: Legacy vs. Unity Catalog

### Access Methods Comparison

| Feature | Legacy Solution | Unity Catalog |
|---------|----------------|---------------|
| **File Access** | DBFS (mount points) | Volumes |
| **Table Access** | Hive Metastore | Unity Catalog Metastore |
| **Unified Access** | Separate systems | Single unified system |
| **Fine-grained Access** | Limited | Row/column level |
| **Audit Logging** | Limited | Comprehensive |
| **Data Lineage** | Not built-in | Built-in |
| **Multi-cloud** | Limited | Full support |
| **Governance** | Basic | Advanced |
| **Governance Scope** | Workspace-level | Account-level |
| **Delta Sharing** | Not available | Built-in |

### Object Types Comparison

| Object | Legacy (Hive Metastore) | Unity Catalog |
|--------|------------------------|---------------|
| **Tables** | Supported | Supported |
| **Views** | Supported | Supported |
| **Functions** | Supported | Supported |
| **Volumes** | Not available | New feature |

---

## What's Coming in This Section

### Learning Objectives

By the end of this section, you will:

1. **Understand Unity Catalog Object Model**
   - Object hierarchy
   - Relationships between objects
   - Naming conventions

2. **Create Unity Catalog Metastore**
   - Step-by-step setup
   - Configuration requirements
   - Best practices

3. **Configure Unity Catalog**
   - Gain access to cloud storage
   - Set up storage layer for Data Lakehouse
   - Prepare for future sections

### Preparation for Future Sections

**Goal:**
Configure our Databricks workspace to use Unity Catalog now, so it will be easier to understand solutions in forthcoming lessons.

---

## Architecture Overview

### Legacy Architecture

```
+-------------------------------------+
|      Databricks Workspace           |
|                                     |
|  +-----------+    +---------------+ |
|  |   DBFS    |    |     Hive      | |
|  |  (Files)  |    |   Metastore   | |
|  |           |    |   (Tables)    | |
|  +-----+-----+    +-------+------+ |
|        |                  |         |
+--------+------------------+---------+
         |                  |
         v                  v
+-------------------------------------+
|   Azure Data Lake Storage Gen2      |
+-------------------------------------+
```

### Unity Catalog Architecture

```
+-------------------------------------------+
|        Databricks Account                 |
|                                           |
|  +-------------------------------------+ |
|  |        Unity Catalog Metastore      | |
|  |                                     | |
|  |  +----------+  +-----------+        | |
|  |  | Volumes  |  |  Tables   |        | |
|  |  | (Files)  |  |  Views    |        | |
|  |  |          |  | Functions |        | |
|  |  +----+-----+  +-----+----+        | |
|  |       +---------------+             | |
|  |       Unified Access                | |
|  +----------------+--------------------+ |
|                   |                       |
|   +--------+  +--------+  +--------+    |
|   |  WS 1  |  |  WS 2  |  |  WS 3  |    |
|   +--------+  +--------+  +--------+    |
+-------------------------------------------+
                    |
                    v
+-------------------------------------------+
|   Azure Data Lake Storage Gen2            |
+-------------------------------------------+
```

---

## CONCEPT GAP: Unity Catalog vs Other Governance Tools

### Comparison with Apache Atlas

```
+---------------------------+---------------------------+
|      Apache Atlas         |      Unity Catalog        |
+---------------------------+---------------------------+
| Open-source               | Proprietary (Databricks)  |
| Metadata management only  | Metadata + access control |
| Requires separate setup   | Built into Databricks     |
| Works with Hadoop eco     | Works with Lakehouse      |
| Manual lineage config     | Automatic lineage         |
| No built-in ACLs          | Fine-grained ACLs         |
| Community support         | Enterprise support        |
+---------------------------+---------------------------+
```

### Comparison with AWS Glue Data Catalog

```
+---------------------------+---------------------------+
|   AWS Glue Data Catalog   |      Unity Catalog        |
+---------------------------+---------------------------+
| AWS-only                  | Multi-cloud               |
| Hive-compatible metastore | Extended 3-level namespace|
| No row/column security    | Row + column level sec.   |
| No built-in lineage       | Automatic lineage         |
| Works with Athena, EMR    | Works with Databricks     |
| IAM-based access          | UC grants + IAM           |
| No data sharing built-in  | Delta Sharing built-in    |
| Pay per request           | Included with Databricks  |
+---------------------------+---------------------------+
```

### Key Differentiator

Unity Catalog is unique because it combines **metadata management**, **access control**, **audit logging**, **data lineage**, and **data sharing** into a single, unified platform. Competing tools typically address only one or two of these areas.

---

## CONCEPT GAP: Workspace-Level vs Account-Level Governance

### The Fundamental Shift

The move from Hive Metastore to Unity Catalog represents a fundamental architectural shift from **workspace-level** to **account-level** governance.

```
  WORKSPACE-LEVEL (Legacy)             ACCOUNT-LEVEL (Unity Catalog)
+---------------------------+       +----------------------------------+
| Each workspace manages    |       | Single metastore per region      |
| its own:                  |       | manages ALL:                     |
|  - Metastore              |       |  - Metadata                      |
|  - Access controls        |       |  - Access controls               |
|  - Users/Groups           |       |  - Users/Groups                  |
|  - Audit logs             |       |  - Audit logs                    |
|                           |       |  - Lineage                       |
| PROBLEM:                  |       |                                  |
|  - Data silos             |       | BENEFIT:                         |
|  - Inconsistent policies  |       |  - Centralized governance        |
|  - No cross-WS sharing    |       |  - Consistent policies           |
|  - Duplicate data         |       |  - Cross-WS data sharing         |
+---------------------------+       +----------------------------------+
```

### Why Account-Level Matters

| Aspect | Workspace-Level | Account-Level |
|--------|----------------|---------------|
| **Policy consistency** | Each WS has own policies | Unified policies across all WS |
| **User management** | Per-workspace users | Account-level identity |
| **Data discovery** | Only within workspace | Across all workspaces |
| **Audit trail** | Fragmented per WS | Centralized audit |
| **Data sharing** | Complex, manual copies | Native Delta Sharing |

---

## CONCEPT GAP: Unity Catalog and Data Mesh Concepts

### What is Data Mesh?

Data Mesh is an organizational approach to data architecture that treats data as a product and decentralizes data ownership to domain teams.

### How Unity Catalog Supports Data Mesh

```
+-----------------------------------------------------------+
|               Unity Catalog Metastore                     |
|                                                           |
|  +-------------+  +-------------+  +-------------+       |
|  |  CATALOG:   |  |  CATALOG:   |  |  CATALOG:   |       |
|  |  sales      |  |  marketing  |  |  finance    |       |
|  |  (Domain 1) |  |  (Domain 2) |  |  (Domain 3) |       |
|  |             |  |             |  |             |       |
|  | Owned by    |  | Owned by    |  | Owned by    |       |
|  | Sales Team  |  | Mktg Team   |  | Finance Team|       |
|  +-------------+  +-------------+  +-------------+       |
|                                                           |
|  Cross-domain discovery + governed sharing via            |
|  Delta Sharing, grants, and unified lineage               |
+-----------------------------------------------------------+
```

**Data Mesh Principles Mapped to Unity Catalog:**

| Data Mesh Principle | Unity Catalog Feature |
|--------------------|-----------------------|
| Domain ownership | Catalogs per domain/team |
| Data as a product | Schemas with documentation, tags |
| Self-serve platform | Catalog Explorer, SQL interface |
| Federated governance | Centralized metastore + domain-level grants |

---

## Summary

### Key Takeaways:

1. **Physical Data Architecture** is essential for implementing Data Lakehouse solutions
2. **Two Solutions** exist:
   - Legacy: DBFS + Hive Metastore
   - Modern: Unity Catalog (recommended)
3. **Legacy Solution** still relevant:
   - Widely used in industry
   - Supported for backward compatibility
   - May appear on exam
4. **Unity Catalog** provides:
   - Unified file and table access
   - Enhanced security and governance
   - Better access control
   - Data lineage capabilities
   - Account-level (not workspace-level) governance
5. **This Section** will prepare you:
   - Understanding Unity Catalog Object Model
   - Configuring Unity Catalog Metastore
   - Setting up cloud storage access

### What's Next:

In the upcoming lessons, we'll:
1. Learn the Unity Catalog Object Model in detail
2. Create and configure Unity Catalog Metastore
3. Set up cloud storage integration
4. Prepare the foundation for future data engineering work

**Let's get started!**

---

## KEY INTERVIEW QUESTIONS AND ANSWERS

### Q1: What is Unity Catalog and why was it introduced?

**A:** Unity Catalog is Databricks' unified governance solution launched in late 2022. It was introduced to address the limitations of the legacy Hive Metastore + DBFS approach, which lacked fine-grained access control (row/column level), audit logging, data lineage, and multi-cloud support. Unity Catalog provides a single platform for metadata management, access control, auditing, lineage, and data sharing.

### Q2: What are the key differences between the legacy solution (DBFS + Hive Metastore) and Unity Catalog?

**A:** Key differences include:
- **Governance scope**: Legacy is workspace-level; Unity Catalog is account-level
- **Access control**: Legacy has basic ACLs; Unity Catalog supports row-level and column-level security
- **File access**: Legacy uses DBFS mounts; Unity Catalog uses Volumes
- **Namespace**: Legacy uses 2-level (schema.object); Unity Catalog uses 3-level (catalog.schema.object)
- **Lineage**: Legacy has none built-in; Unity Catalog tracks lineage automatically
- **Audit**: Legacy has limited auditing; Unity Catalog has comprehensive audit logs
- **Data sharing**: Legacy requires data copies; Unity Catalog has Delta Sharing

### Q3: What is a Volume in Unity Catalog and how does it differ from DBFS?

**A:** A Volume is a Unity Catalog object that provides an abstraction layer over files in cloud storage. Unlike DBFS, Volumes are governed by Unity Catalog's access control, audit logging, and lineage tracking. Volumes are the recommended replacement for DBFS mount points for accessing unstructured and semi-structured files. DBFS operates at the workspace level while Volumes are managed at the account level through Unity Catalog.

### Q4: Can you still use Hive Metastore after enabling Unity Catalog?

**A:** Yes. Databricks provides 100% backward compatibility via a pseudo catalog called `hive_metastore`. This catalog is automatically present in every workspace. However, objects created under `hive_metastore` do not benefit from Unity Catalog features like lineage, fine-grained access control, or audit logging. Databricks recommends avoiding Hive Metastore for new projects.

### Q5: How does Unity Catalog support multi-cloud environments?

**A:** Unity Catalog provides a consistent governance layer regardless of the underlying cloud provider (AWS, Azure, GCP). It abstracts cloud-specific storage access through Storage Credentials and External Locations, and supports Delta Sharing for cross-cloud and cross-organization data sharing without data copying.

### Q6: How does Unity Catalog relate to Data Mesh architecture?

**A:** Unity Catalog supports Data Mesh principles by allowing domain teams to own their data via separate catalogs (domain ownership), providing self-serve data discovery through Catalog Explorer, enabling governed data sharing via Delta Sharing, and maintaining federated governance through centralized metastore policies combined with domain-level grants.

### Q7: What is the recommended approach for new Databricks projects -- legacy or Unity Catalog?

**A:** Databricks strongly recommends Unity Catalog for all new projects. The legacy solution (DBFS + Hive Metastore) is maintained only for backward compatibility. The exam expects you to know both but emphasizes Unity Catalog as the modern standard.

---

*End of lesson*
