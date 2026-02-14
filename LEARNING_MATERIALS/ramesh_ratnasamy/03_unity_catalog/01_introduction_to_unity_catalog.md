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
- ❓ Where and how data in a Data Lakehouse is physically stored
- ❓ How Databricks enables access to the data
- ❓ What objects can be created from the data (tables, views, etc.)

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
Launch → 2022                          Late 2022 → Present
┌─────────────────────┐               ┌──────────────────┐
│   Legacy Solution   │    →          │  Unity Catalog   │
│  - DBFS             │               │  (Recommended)   │
│  - Hive Metastore   │               │                  │
└─────────────────────┘               └──────────────────┘
```

### Legacy Solution (Original)

**Components:**
- Databricks File System (DBFS)
- Hive Metastore

**Status:**
- ✅ Widely adopted in industry
- ✅ Still supported for backward compatibility
- ⚠️ Considered legacy by Databricks
- ⚠️ Challenges with data security and governance

### Unity Catalog (Current Recommendation)

**Launch:** Late 2022

**Purpose:**
- Address challenges of legacy solution
- Provide robust data governance
- Better data security

**Databricks Recommendation:**
⭐ Use **Unity Catalog for all new projects**

---

## Course Coverage Plan

### Legacy Solution Coverage

**Why Learn the Legacy Solution?**

Despite being considered legacy:
- ✅ Widely used in the industry
- ✅ Fully supported by Databricks for backward compatibility
- ✅ Most documentation still references it
- ✅ May appear on exam (a few questions)

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
- ✅ Databricks cluster
- ✅ Databricks job

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
- ✅ Widely adopted
- ✅ Used by customers for **over 7 years**
- ✅ Proven technology

### Identified Limitations

Despite widespread use, the legacy solution has limitations:

#### 1. Limited Access Control

**Problem:**
- ❌ Lack of fine-grained access control
- ❌ No row-level access control
- ❌ No column-level access control

**Impact:**
Cannot restrict access to specific rows or columns within a table.

#### 2. No Audit Logging

**Problem:**
- ❌ Limited audit capabilities
- ❌ Difficult to track who accessed what data

**Impact:**
Compliance and security concerns.

#### 3. No Data Lineage

**Problem:**
- ❌ No built-in data lineage tracking
- ❌ Difficult to trace data flow

**Impact:**
Cannot easily track data origins and transformations.

#### 4. Multi-Cloud Limitations

**Problem:**
- ❌ Support challenges for multi-cloud environments
- ❌ Not optimized for cross-cloud scenarios

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
- ✅ Create tables on structured data
- ✅ Create views for summaries and filtered data

### 2. Functions

**Purpose:**
- Abstract transformation logic
- Reusable data transformations

### 3. Volumes (New!) ⭐

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
- ✅ Files (via Volumes)
- ✅ Table objects (via Tables/Views)

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
| **Unified Access** | ❌ Separate systems | ✅ Single unified system |
| **Fine-grained Access** | ❌ Limited | ✅ Row/column level |
| **Audit Logging** | ❌ Limited | ✅ Comprehensive |
| **Data Lineage** | ❌ Not built-in | ✅ Built-in |
| **Multi-cloud** | ⚠️ Limited | ✅ Full support |
| **Governance** | ⚠️ Basic | ✅ Advanced |

### Object Types Comparison

| Object | Legacy (Hive Metastore) | Unity Catalog |
|--------|------------------------|---------------|
| **Tables** | ✅ Supported | ✅ Supported |
| **Views** | ✅ Supported | ✅ Supported |
| **Functions** | ✅ Supported | ✅ Supported |
| **Volumes** | ❌ Not available | ✅ New feature |

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
┌─────────────────────────────────────┐
│      Databricks Workspace          │
│                                     │
│  ┌──────────┐      ┌─────────────┐│
│  │   DBFS   │      │    Hive     ││
│  │ (Files)  │      │  Metastore  ││
│  │          │      │  (Tables)   ││
│  └────┬─────┘      └──────┬──────┘│
│       │                   │        │
└───────┼───────────────────┼────────┘
        │                   │
        ▼                   ▼
┌─────────────────────────────────────┐
│   Azure Data Lake Storage Gen2     │
└─────────────────────────────────────┘
```

### Unity Catalog Architecture

```
┌─────────────────────────────────────┐
│      Databricks Workspace          │
│                                     │
│  ┌─────────────────────────────┐  │
│  │     Unity Catalog           │  │
│  │  ┌─────────┐  ┌──────────┐ │  │
│  │  │ Volumes │  │  Tables  │ │  │
│  │  │ (Files) │  │  Views   │ │  │
│  │  │         │  │ Functions│ │  │
│  │  └────┬────┘  └─────┬────┘ │  │
│  │       └─────────────┘      │  │
│  │      Unified Access         │  │
│  └──────────────┬──────────────┘  │
│                 │                  │
└─────────────────┼──────────────────┘
                  │
                  ▼
┌─────────────────────────────────────┐
│   Azure Data Lake Storage Gen2     │
└─────────────────────────────────────┘
```

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

*End of lesson*