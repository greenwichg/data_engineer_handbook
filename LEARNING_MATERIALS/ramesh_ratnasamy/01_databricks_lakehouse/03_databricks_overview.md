# Introduction to Databricks

## Overview

Welcome back. Now that we have an understanding of the Data Lakehouse platform, let me give you an introduction to Databricks—the platform that helps us build Data Lakehouses.

We'll start with a high-level overview of Databricks in this lesson, then explore its key components in more detail in upcoming lessons.

### What is Databricks?

At the core of Databricks is the open-source distributed compute engine called **Apache Spark**, which is widely used in the industry for building big data and machine learning projects.

**Key Facts:**
- Founded by the creators of Apache Spark
- Makes working with Spark easier by providing essential management layers
- Available on all major cloud platforms:
  - Microsoft Azure
  - AWS
  - Google Cloud

```
+====================================================================+
|              DATABRICKS HIGH-LEVEL OVERVIEW                          |
+====================================================================+
|                                                                     |
|           +-------------------------------------------+             |
|           |           DATABRICKS PLATFORM             |             |
|           +-------------------------------------------+             |
|           |                                           |             |
|           |  +----------+  +----------+  +----------+ |             |
|           |  | Notebooks |  | Workflows|  | SQL      | |             |
|           |  | IDE       |  | (Jobs)   |  | Analytics| |             |
|           |  +----------+  +----------+  +----------+ |             |
|           |                                           |             |
|           |  +----------+  +----------+  +----------+ |             |
|           |  | Delta    |  | Unity    |  | MLflow   | |             |
|           |  | Lake     |  | Catalog  |  | (ML)     | |             |
|           |  +----------+  +----------+  +----------+ |             |
|           |                                           |             |
|           |  +----------+  +----------+  +----------+ |             |
|           |  | Delta    |  | Photon   |  | Databricks| |            |
|           |  | Live Tbl |  | Engine   |  | IQ (AI)  | |             |
|           |  +----------+  +----------+  +----------+ |             |
|           |                                           |             |
|           |  +---------------------------------------+|             |
|           |  |  Optimized Apache Spark Runtime        ||             |
|           |  +---------------------------------------+|             |
|           +-------------------------------------------+             |
|                          |                                          |
|           +--------------+--------------+                           |
|           |              |              |                           |
|     +-----+------+ +----+------+ +-----+------+                    |
|     | Azure      | | AWS       | | Google     |                    |
|     | (1st party)| |           | | Cloud      |                    |
|     +------------+ +-----------+ +------------+                    |
+=====================================================================+
```

---

## Apache Spark: The Foundation

### What is Apache Spark?

Apache Spark is a **fast, unified analytical engine** designed for big data processing and machine learning.

**History:**
- Originally developed at UC Berkeley in 2009
- Open-sourced in 2010
- Became an Apache Software Foundation project in 2013
- Has seen significant adoption since

**Industry Usage:**

Companies like Yahoo, eBay, and Netflix use Spark for large-scale data processing, handling **petabytes of data** on clusters with **thousands of nodes**.

### Why Spark? Advantages Over Hadoop

Spark was designed to address the limitations of Hadoop, which was the widely used big data processing engine at the time.

**Hadoop's Limitations:**
- Slow and inefficient for interactive computing tasks
- Poor performance for iterative computing tasks

**Spark's Advantages:**
- Simpler and faster APIs
- **Up to 100 times faster** than Hadoop for large-scale data processing
- Utilizes in-memory computing and various optimizations

```
+====================================================================+
|              HADOOP MapReduce vs APACHE SPARK                        |
+====================================================================+
|                                                                     |
|  HADOOP MapReduce                                                   |
|  +--------+    +--------+    +--------+    +--------+              |
|  | Map    |--->| DISK   |--->| Reduce |--->| DISK   |              |
|  | Stage  |    | Write  |    | Stage  |    | Write  |              |
|  +--------+    +--------+    +--------+    +--------+              |
|       |             ^             |             ^                   |
|       +--Slow I/O---+             +--Slow I/O---+                   |
|                                                                     |
|  APACHE SPARK                                                       |
|  +--------+    +--------+    +--------+    +--------+              |
|  | Stage  |--->| Stage  |--->| Stage  |--->| Stage  |              |
|  |   1    |    |   2    |    |   3    |    |   4    |              |
|  +--------+    +--------+    +--------+    +--------+              |
|       |             ^             |             ^                   |
|       +--IN-MEMORY--+             +--IN-MEMORY--+                   |
|                                                                     |
|  Result: Spark is up to 100x faster for iterative workloads        |
+=====================================================================+
```

### Key Features of Spark

1. **Distributed Computing Platform**: Runs on distributed systems
2. **Unified Engine**: Supports both batch and streaming workloads
3. **Built-in Libraries**:
   - SQL queries
   - Machine learning
   - Graph processing
4. **Versatility**: Enables developers to build complex workflows efficiently

```
+====================================================================+
|              APACHE SPARK UNIFIED ENGINE                              |
+====================================================================+
|                                                                     |
|                    +---------------------+                          |
|                    |    Spark Core        |                          |
|                    | (RDD, Task Sched,   |                          |
|                    |  Memory Mgmt, I/O)  |                          |
|                    +----------+----------+                          |
|                               |                                     |
|         +----------+----------+----------+----------+               |
|         |          |          |          |          |               |
|    +----+----+ +---+---+ +---+---+ +----+---+ +---+----+          |
|    | Spark   | | Spark | | Spark | | Spark  | | Struct. |          |
|    | SQL     | |  ML   | |GraphX | |Streaming| |Streaming|         |
|    |         | |(MLlib)| |       | |(legacy)| | (modern)|          |
|    +---------+ +-------+ +-------+ +--------+ +--------+          |
|    | DataFrames| Models | | Graph | | DStreams| | Micro-  |         |
|    | Datasets | Pipelines| Algos | |        | | batch + |          |
|    | SQL      | Feature | | Pregel| |        | | cont.   |          |
|    |          | Engrg  | |       | |        | | process.|          |
|    +---------+ +-------+ +-------+ +--------+ +--------+          |
|                                                                     |
|  Languages supported: Python, Scala, Java, R, SQL                  |
+=====================================================================+
```

---

## How Databricks Enhances Spark

While Spark is powerful, setting up clusters, managing security, and using third-party tools to write programs can be quite challenging. **This is where Databricks comes in.**

### 1. Simplified Cluster Management

**Easy Cluster Creation:**
- Spin up clusters with just a few clicks
- Choose from different runtime options:
  - General purpose use
  - Memory-optimized processing
  - GPU support for machine learning tasks

### 2. Integrated Development Environment

**Jupyter-Style Notebook IDE** that allows you to:
- Create and run applications
- Collaborate with colleagues
- Connect with version control tools (Git)

### 3. Administrative Controls

Manage user access to:
- Workspaces
- Clusters
- Ensure secure usage

### 4. Optimized Spark Runtime

**Databricks Spark Runtime:**
- Highly optimized for the Databricks platform
- **Up to 5 times faster** than vanilla Apache Spark

### 5. Photon Query Engine

A vectorized query engine providing:
- Extremely fast query performance
- **Up to 8 times improvement** on standard Databricks runtime

### 6. Data Management and Governance

**Metastore Options:**
- Hive Metastore
- Unity Catalog (preferred)

**Capabilities:**
- Create and manage databases and tables
- Data lineage support
- Improved governance

### 7. Delta Lake

Offers robust support for:
- **ACID transactions**
- Data reliability
- Data integrity

### 8. Delta Live Tables

A **declarative ETL framework** that helps create reliable data pipelines with ease.

### 9. Databricks Workflows

Built-in feature for:
- Scheduling tasks and pipelines
- Orchestrating workflows as required

### 10. Databricks SQL

Provides data analysts with a **SQL-based analytical environment** to:
- Explore data
- Create dashboards
- Schedule regular dashboard refreshes

### 11. Managed MLflow

Helps manage the **machine learning lifecycle**, including:
- Experimentation
- Model deployment
- Model registry

### 12. Databricks IQ (Latest Addition)

An **AI assistant** that helps:
- Develop and debug code
- Add commands
- Create dashboards

```
+====================================================================+
|       DATABRICKS COMPONENTS: CAPABILITY MAP                          |
+====================================================================+
|                                                                     |
|  DATA ENGINEERING         DATA SCIENCE / ML       DATA ANALYTICS    |
|  +------------------+    +------------------+    +----------------+ |
|  | Delta Lake       |    | MLflow           |    | Databricks SQL | |
|  | Delta Live Tables|    | Spark MLlib      |    | Dashboards     | |
|  | Auto Loader      |    | Feature Store    |    | SQL Warehouse  | |
|  | Workflows (Jobs) |    | Model Serving    |    | Alerts         | |
|  | Structured       |    | Experiment       |    | Query History  | |
|  |   Streaming      |    |   Tracking       |    |                | |
|  +------------------+    +------------------+    +----------------+ |
|                                                                     |
|  GOVERNANCE               COMPUTE                 AI / LLM          |
|  +------------------+    +------------------+    +----------------+ |
|  | Unity Catalog    |    | All-Purpose      |    | Databricks IQ  | |
|  | Data Lineage     |    |   Clusters       |    | Model Serving  | |
|  | Access Control   |    | Job Clusters     |    | Vector Search  | |
|  | Audit Logs       |    | SQL Warehouses   |    | Foundation     | |
|  | Data Discovery   |    | Serverless       |    |   Model APIs   | |
|  +------------------+    +------------------+    +----------------+ |
+=====================================================================+
```

---

## Cloud Platform Integration

Databricks is available on all three major cloud platforms:
- Microsoft Azure
- AWS
- Google Cloud

### Azure: First-Party Service

The integration between cloud platforms and Databricks is quite similar, **except Azure hosts Databricks as a first-party service**.

**Benefits on Azure:**
- Unified billing
- Direct support from Microsoft for all services (both Azure services and Databricks)

### Common Integrations Across All Platforms

#### 1. Security and Governance

Leverages cloud provider services:
- Azure Active Directory
- AWS Identity and Access Management (IAM)
- Google Cloud IAM

#### 2. Storage Services

Integrates with:
- Azure Data Lake Storage Gen2
- AWS S3
- Google Cloud Storage

#### 3. Compute Resources

Underlying virtual machines for Databricks clusters are provided by the cloud providers themselves.

#### 4. Monitoring Services

Can use cloud provider monitoring services to:
- Track Databricks workloads
- Analyze performance

#### 5. DevOps Integration

Integrates with DevOps services such as:
- Azure DevOps
- AWS DevOps tools
- Google Cloud Build

**Purpose**: Enable Continuous Integration and Continuous Deployment (CI/CD)

```
+====================================================================+
|         DATABRICKS CLOUD INTEGRATION COMPARISON                      |
+====================================================================+
|                                                                     |
|              Azure            AWS              GCP                  |
|  +-----------+--------------+-----------------+---------------+     |
|  | Deployment| 1st-party    | 3rd-party       | 3rd-party     |    |
|  |           | service      | integration     | integration   |     |
|  +-----------+--------------+-----------------+---------------+     |
|  | Storage   | ADLS Gen2    | S3              | GCS           |     |
|  +-----------+--------------+-----------------+---------------+     |
|  | Identity  | Azure AD /   | AWS IAM         | Google IAM    |     |
|  |           | Entra ID     |                 |               |     |
|  +-----------+--------------+-----------------+---------------+     |
|  | Billing   | Unified      | Separate        | Separate      |     |
|  |           | (Azure bill) | (Databricks     | (Databricks   |     |
|  |           |              |  account)       |  account)     |     |
|  +-----------+--------------+-----------------+---------------+     |
|  | Networking| VNet         | VPC             | VPC           |     |
|  |           | injection    | peering         | peering       |     |
|  +-----------+--------------+-----------------+---------------+     |
|  | Key Vault | Azure Key    | AWS KMS         | Cloud KMS     |     |
|  |           | Vault        |                 |               |     |
|  +-----------+--------------+-----------------+---------------+     |
|  | Monitoring| Azure Monitor| CloudWatch      | Cloud         |     |
|  |           |              |                 | Monitoring    |     |
|  +-----------+--------------+-----------------+---------------+     |
|  | DevOps    | Azure DevOps | CodePipeline    | Cloud Build   |     |
|  +-----------+--------------+-----------------+---------------+     |
+=====================================================================+
```

---

## Summary

Databricks is a **Spark-based, unified data analytics platform** that's optimized for each of the major cloud providers.

### What We've Covered:

- Databricks builds on Apache Spark's powerful foundation
- Provides essential management layers and optimizations
- Offers comprehensive tools for the entire data lifecycle
- Seamlessly integrates with major cloud platforms

### What's Next:

In the forthcoming lessons, we will delve deeper into each of Databricks' components and see them in action.

---

## CONCEPT GAP: Databricks Architecture -- Control Plane vs Data Plane

Understanding the separation between the Control Plane and Data Plane is a key certification exam topic. Databricks uses a split architecture where the platform management and data processing are separated.

```
+====================================================================+
|       DATABRICKS ARCHITECTURE: CONTROL PLANE vs DATA PLANE           |
+====================================================================+
|                                                                     |
|  +-------------------------------+                                  |
|  |       CONTROL PLANE           |  (Managed by Databricks)        |
|  |       (Databricks account)    |                                  |
|  |                               |                                  |
|  |  +----------+  +----------+  |                                  |
|  |  | Web UI   |  | REST     |  |                                  |
|  |  | (Portal) |  | APIs     |  |                                  |
|  |  +----------+  +----------+  |                                  |
|  |  +----------+  +----------+  |                                  |
|  |  | Notebook  |  | Cluster  |  |                                  |
|  |  | Service   |  | Manager  |  |                                  |
|  |  +----------+  +----------+  |                                  |
|  |  +----------+  +----------+  |                                  |
|  |  | Job       |  | Unity    |  |                                  |
|  |  | Scheduler |  | Catalog  |  |                                  |
|  |  +----------+  +----------+  |                                  |
|  +---------------+---------------+                                  |
|                  |                                                   |
|                  | (Secure connection)                               |
|                  v                                                   |
|  +-------------------------------+                                  |
|  |        DATA PLANE             |  (In YOUR cloud subscription)   |
|  |   (Customer's cloud account)  |                                  |
|  |                               |                                  |
|  |  +----------+  +----------+  |                                  |
|  |  | Cluster  |  | Cluster  |  |  <-- VMs in your account        |
|  |  | (Driver) |  | (Workers)|  |                                  |
|  |  +----------+  +----------+  |                                  |
|  |  +---------------------------+|                                  |
|  |  |  Cloud Object Storage     ||  <-- Your S3/ADLS/GCS          |
|  |  |  (Data stays here)        ||                                  |
|  |  +---------------------------+|                                  |
|  +-------------------------------+                                  |
|                                                                     |
|  KEY SECURITY POINT:                                                |
|  Your data NEVER leaves your cloud account.                         |
|  Only metadata and commands travel to the control plane.            |
+=====================================================================+
```

### Why This Matters

- **Data sovereignty**: Customer data remains in the customer's cloud account
- **Security**: Only metadata (not data) crosses the boundary to Databricks
- **Compliance**: Meets regulatory requirements where data must stay in specific regions
- **Cost**: Compute costs appear on the customer's cloud bill (except for Databricks licensing)

---

## CONCEPT GAP: Databricks Cluster Types and Compute Options

Choosing the right compute resource is a frequent exam and interview topic.

```
+====================================================================+
|         DATABRICKS COMPUTE OPTIONS                                   |
+====================================================================+
|                                                                     |
|  +---------------------+   +---------------------+                 |
|  | ALL-PURPOSE CLUSTER |   |    JOB CLUSTER      |                 |
|  |                     |   |                     |                 |
|  | - Interactive use   |   | - Automated jobs    |                 |
|  | - Notebooks, IDE    |   | - Created per job   |                 |
|  | - Shared by users   |   | - Terminated after  |                 |
|  | - Manual start/stop |   |   job completes     |                 |
|  | - Higher cost       |   | - Lower cost        |                 |
|  | - Dev & exploration |   | - Production runs   |                 |
|  +---------------------+   +---------------------+                 |
|                                                                     |
|  +---------------------+   +---------------------+                 |
|  |   SQL WAREHOUSE     |   |    SERVERLESS       |                 |
|  |                     |   |                     |                 |
|  | - SQL workloads     |   | - No cluster mgmt  |                 |
|  | - BI tool queries   |   | - Instant start     |                 |
|  | - Auto-scaling      |   | - Pay per use       |                 |
|  | - Dashboards        |   | - Available for     |                 |
|  | - T-shirt sizing    |   |   notebooks, jobs,  |                 |
|  |   (XS to 4XL)      |   |   SQL warehouses    |                 |
|  +---------------------+   +---------------------+                 |
+=====================================================================+
```

| Feature | All-Purpose Cluster | Job Cluster | SQL Warehouse | Serverless |
|---|---|---|---|---|
| **Use case** | Development, exploration | Production jobs | SQL analytics, BI | Any (notebooks, jobs, SQL) |
| **Lifecycle** | Manual start/stop | Auto-created per job, auto-terminated | Auto-start/stop | Managed by Databricks |
| **Sharing** | Multi-user | Single job | Multi-user | Varies |
| **Cost** | Higher (always on) | Lower (ephemeral) | Usage-based | Pay per use |
| **Cluster management** | User managed | Auto-managed | Auto-managed | Fully managed |
| **Startup time** | Minutes | Minutes | Minutes | Seconds |
| **Autoscaling** | Optional | Optional | Built-in | Built-in |

---

## CONCEPT GAP: Databricks Runtime Versions

Understanding the different Databricks Runtime options is important for choosing the right runtime for your workload.

| Runtime | Description | Use Case |
|---|---|---|
| **Databricks Runtime (DBR)** | Standard runtime with Apache Spark, Delta Lake, and pre-installed libraries | General data engineering and analytics |
| **Databricks Runtime ML** | DBR + pre-installed ML libraries (TensorFlow, PyTorch, scikit-learn, XGBoost) | Machine learning and deep learning |
| **Databricks Runtime for Photon** | DBR + Photon vectorized query engine | SQL-heavy workloads needing maximum performance |
| **Databricks Runtime Light** | Lightweight runtime without Delta Lake extras | Jobs that do not need Delta Lake features |
| **Long Term Support (LTS)** | Supported for 2+ years with bug and security fixes | Production workloads requiring stability |

### Runtime Selection Best Practices

- **Production pipelines**: Always use LTS versions for stability
- **SQL-heavy workloads**: Enable Photon for up to 8x performance improvement
- **ML projects**: Use the ML runtime to avoid manual library installation
- **Cost optimization**: Match the runtime to the workload -- do not use ML runtime for simple ETL

---

## CONCEPT GAP: Databricks Workspace Organization

Understanding the workspace hierarchy is essential for managing Databricks projects effectively.

```
+====================================================================+
|         DATABRICKS WORKSPACE HIERARCHY                               |
+====================================================================+
|                                                                     |
|  Databricks Account                                                 |
|  +--------------------------------------------------------------+  |
|  |                                                                |  |
|  |  Workspace 1 (Dev)        Workspace 2 (Prod)                  |  |
|  |  +-----------------------+ +-----------------------+          |  |
|  |  | +---+ +---+ +------+ | | +---+ +---+ +------+ |          |  |
|  |  | |Note| |Repos| |Clust| | | |Note| |Repos| |Clust| |       |  |
|  |  | |books| |    | |ers | | | |books| |    | |ers | |          |  |
|  |  | +---+ +---+ +------+ | | +---+ +---+ +------+ |          |  |
|  |  | +------+ +----------+| | +------+ +----------+|          |  |
|  |  | |Jobs  | |SQL Wrhse || | |Jobs  | |SQL Wrhse ||          |  |
|  |  | +------+ +----------+| | +------+ +----------+|          |  |
|  |  +-----------------------+ +-----------------------+          |  |
|  |                                                                |  |
|  |  Unity Catalog (shared across workspaces)                     |  |
|  |  +----------------------------------------------------------+ |  |
|  |  | Metastore --> Catalogs --> Schemas --> Tables/Views/Funcs | |  |
|  |  +----------------------------------------------------------+ |  |
|  +--------------------------------------------------------------+  |
+=====================================================================+
```

### Key Organizational Concepts

- **Account**: The top-level entity. One per organization.
- **Workspaces**: Isolated environments within an account. Typically separated by environment (dev, staging, prod) or team.
- **Unity Catalog Metastore**: Shared across workspaces, providing a single governance layer.
- **Repos**: Git integration for version-controlled notebooks and code.

---

## CONCEPT GAP: Databricks vs Other Lakehouse Platforms

Understanding how Databricks compares to competitors is valuable for interviews.

| Feature | Databricks | Snowflake | AWS (Lake Formation + Athena + Glue) | Microsoft Fabric |
|---|---|---|---|---|
| **Core engine** | Apache Spark | Proprietary (SnowPark for Spark-like) | Serverless (Presto/Trino for queries) | Multiple engines |
| **Open source** | Heavy (Spark, Delta, MLflow) | Minimal | Moderate | Minimal |
| **Storage format** | Delta Lake (open) | Proprietary | Parquet/Iceberg | Delta Lake |
| **Multi-cloud** | Yes (Azure, AWS, GCP) | Yes (Azure, AWS, GCP) | AWS only | Azure primarily |
| **ML support** | Excellent (MLflow, notebooks) | Growing (SnowPark ML) | SageMaker integration | Built-in |
| **Streaming** | Native (Structured Streaming) | Limited (Snowpipe) | Kinesis/Glue Streaming | Event streams |
| **Governance** | Unity Catalog | Built-in | Lake Formation | Purview |
| **BI integration** | SQL Warehouses, direct connect | Native dashboards | QuickSight | Power BI native |
| **Pricing model** | DBU-based | Credit-based | Pay-per-query/use | CU-based |

---

## KEY INTERVIEW QUESTIONS AND ANSWERS

### Q1: What is Databricks, and how does it relate to Apache Spark?
**A:** Databricks is a unified data analytics platform built on top of Apache Spark, founded by the creators of Spark. While Spark is the open-source distributed compute engine at the core, Databricks adds essential management layers including simplified cluster management, an integrated notebook IDE, optimized runtimes (up to 5x faster than vanilla Spark), the Photon query engine, Delta Lake for ACID transactions, Unity Catalog for governance, and workflow orchestration. It is available as a managed service on Azure, AWS, and GCP.

### Q2: What is the difference between the Control Plane and the Data Plane in Databricks?
**A:** The Control Plane is managed by Databricks and includes the web UI, REST APIs, notebook service, cluster manager, job scheduler, and Unity Catalog metadata. The Data Plane runs in the customer's own cloud subscription and includes the actual compute clusters (VMs) and cloud object storage where data resides. This separation ensures that customer data never leaves their cloud account -- only metadata and commands travel to the control plane -- which is critical for security and compliance.

### Q3: What are the different cluster types in Databricks, and when would you use each?
**A:** Databricks offers four main compute options: (1) All-Purpose Clusters for interactive development and exploration, shared among users, manually started and stopped; (2) Job Clusters for automated production jobs, created on-demand and terminated after the job completes, which is more cost-effective; (3) SQL Warehouses for SQL analytics, BI tool queries, and dashboards with built-in autoscaling; (4) Serverless compute for instant startup with no cluster management, available for notebooks, jobs, and SQL warehouses with pay-per-use pricing.

### Q4: How does Databricks integrate with cloud providers? What makes Azure different?
**A:** Databricks integrates with all three major cloud providers by leveraging their native services for storage (S3, ADLS Gen2, GCS), identity management (IAM, Azure AD, Google IAM), networking (VPCs/VNets), key management (KMS, Key Vault), and monitoring (CloudWatch, Azure Monitor). Azure is unique because it hosts Databricks as a first-party service, which provides unified billing through the Azure portal and direct Microsoft support for both Azure and Databricks issues, unlike AWS and GCP where billing and support are handled separately.

### Q5: What is the Photon query engine and when should you use it?
**A:** Photon is a high-performance vectorized query engine written in C++ that runs natively within the Databricks runtime. It provides up to 8x performance improvement over the standard Databricks runtime for SQL and DataFrame operations. You should enable Photon for SQL-heavy workloads, BI dashboard queries, and large-scale ETL jobs that involve scanning, filtering, and aggregating large datasets. Photon is compatible with the Spark API so no code changes are needed -- you simply select a Photon-enabled runtime when creating a cluster.

### Q6: What is Delta Live Tables (DLT) and how does it differ from regular Spark jobs?
**A:** Delta Live Tables is a declarative ETL framework where you define WHAT your pipeline should produce (target tables and their transformations) rather than HOW to execute it. DLT automatically manages task orchestration, error handling, data quality enforcement (via Expectations), and incremental processing. In contrast, regular Spark jobs require you to manually handle execution order, error recovery, state management, and checkpoint logic. DLT is purpose-built for implementing Medallion Architecture pipelines with built-in monitoring and quality metrics.

### Q7: What Databricks Runtime version should you use for production workloads?
**A:** For production workloads, you should always use a Long Term Support (LTS) runtime version, which is supported for 2+ years with bug fixes and security patches. Choose the standard Databricks Runtime for general data engineering, the ML Runtime for machine learning workloads (it includes pre-installed ML libraries), or the Photon-enabled runtime for SQL-heavy workloads. Avoid non-LTS versions in production as they have shorter support windows and may introduce breaking changes.

### Q8: How does Databricks compare to Snowflake for data engineering?
**A:** Databricks excels at data engineering with native Apache Spark for complex ETL, built-in streaming support via Structured Streaming, strong ML capabilities through MLflow and ML runtimes, and open-source foundations (Delta Lake, Spark, MLflow). Snowflake excels at SQL-based analytics with near-zero administration, simpler pricing, and easier onboarding for SQL-focused teams. Key differences: Databricks uses open formats (Delta/Parquet) while Snowflake uses proprietary storage; Databricks offers richer programmatic support (Python, Scala, R) while Snowflake centers on SQL; Databricks provides notebook-based development while Snowflake provides a SQL worksheet interface.

---

*Thank you*