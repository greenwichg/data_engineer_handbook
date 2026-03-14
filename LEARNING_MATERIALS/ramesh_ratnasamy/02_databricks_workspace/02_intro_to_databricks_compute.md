# Databricks Compute Resources

## Introduction to Compute in Databricks

In this lesson, we're going to dive deeper into the computing resources available in Databricks to run data engineering workloads.

### What is Compute?

In Databricks, **compute** essentially refers to a **cluster of virtual machines**.

**Important Note**: You'll often hear the terms "compute" and "cluster" used interchangeably - they refer to the same thing.

### Cluster Architecture

In a cluster, there are typically:
- **Driver Node**: Orchestrates the tasks
- **Worker Node(s)**: Perform the actual processing (one or more nodes)

Together, these nodes allow Databricks clusters to run various workloads such as:
- ETL (Extract, Transform, Load)
- Data science tasks
- Machine learning applications

---

## Two Types of Compute

As we saw in the architecture diagram, Databricks offers two types of compute:

1. **Serverless Compute**: On-demand and managed by Databricks
2. **Classic Compute**: Configured and provisioned by the user

---

## Serverless Compute

### Overview

Serverless compute is a **fully managed service** provisioned and managed by Databricks.

### Key Characteristics:

**Resource Location:**
- Compute resources are provisioned in the **Databricks Cloud account**

**Pre-allocated Resources:**
- Databricks keeps a pool of virtual machines available for clusters
- Clusters start **immediately**
- Very little time required for cluster to become available

**Automatic Configuration:**
- Databricks configures the cluster with the **latest runtime** available
- Scales the cluster up and down using intelligence from **AI models**

**Resource Management:**
- Once a task completes, Databricks automatically releases resources back to the pool
- Customers are only charged for the **duration the cluster was up and running**

### Main Benefits:

1. **Reduced Cluster Start Time**: Instant availability from pre-allocated pool
2. **Increased Productivity**: Less time waiting for clusters
3. **Expected Lower Cost**: 
   - Reduced idle time
   - Reliance on Databricks AI for auto-scaling
4. **Reduced Administrative Effort**: Less configuration and maintenance required

### Current Limitations:

**⚠️ Preview Feature Status:**

Serverless compute is mostly a **preview feature** in Databricks at the moment with some limitations:

- Lack of support for Scala in notebooks
- Lack of billing attribution to workloads using tags
- Other preview-related restrictions

**Exam Note**: As it's a preview feature, you may not see many questions on serverless compute in the exam.

---

## Classic Compute

### Overview

Classic compute is **totally controlled by the customer**.

### Customer Responsibilities:

- Configure and manage the cluster
- Full control over:
  - Software version to use
  - Type of compute nodes
  - Number of nodes to allocate
  - Size of nodes

---

## Two Types of Classic Compute

### 1. All-Purpose Cluster

**Creation Method:**
- Created manually via:
  - Graphical User Interface (GUI)
  - CLI (Command Line Interface)
  - API

### 2. Job Cluster

**Creation Method:**
- Created automatically when an automated job starts to execute
- Job must be configured to use a job cluster

---

## All-Purpose vs. Job Clusters: Detailed Comparison

### Lifecycle and Persistence

| Aspect | All-Purpose Cluster | Job Cluster |
|--------|-------------------|-------------|
| **Persistence** | Persistent | Ephemeral |
| **Termination** | Can be terminated and restarted at any point | Terminated at end of job |
| **Restart Capability** | Can be restarted | Cannot be restarted; no longer usable once job completes |

### Use Cases

| Aspect | All-Purpose Cluster | Job Cluster |
|--------|-------------------|-------------|
| **Suitable For** | Interactive and ad hoc analytical workloads | Automated workloads (ETL pipelines, ML workloads at regular intervals) |
| **Workload Type** | Interactive analysis and ad hoc work | Repeated production workloads |

### Sharing and Collaboration

| Aspect | All-Purpose Cluster | Job Cluster |
|--------|-------------------|-------------|
| **User Access** | Can be shared among many users | Isolated just for the job being executed |
| **Collaboration** | Good for collaborative analysis | Single-purpose execution |

### Cost

| Aspect | All-Purpose Cluster | Job Cluster |
|--------|-------------------|-------------|
| **Cost** | More expensive to run | Less expensive |

---

## Summary

### When to Use Each Type:

**All-Purpose Clusters:**
- ✅ Interactive analysis
- ✅ Ad hoc work
- ✅ Collaborative analysis
- ✅ Exploratory data analysis
- ❌ More expensive

**Job Clusters:**
- ✅ Repeated production workloads
- ✅ Scheduled ETL pipelines
- ✅ Automated machine learning tasks
- ✅ Cost-effective for production
- ❌ Not suitable for interactive work

---

## Cluster Architecture Diagram

```
┌─────────────────────────────────────────────────────────────────────┐
│                     DATABRICKS CLUSTER                               │
│                                                                      │
│  ┌──────────────────────┐      ┌──────────────────────────────────┐ │
│  │     DRIVER NODE       │      │         WORKER NODES              │ │
│  │                       │      │                                   │ │
│  │  - Orchestrates tasks │      │  ┌───────────┐  ┌───────────┐   │ │
│  │  - Runs SparkContext  │─────▶│  │ Worker 1  │  │ Worker 2  │   │ │
│  │  - Parses queries     │      │  │ (Executor)│  │ (Executor)│   │ │
│  │  - Plans execution    │      │  └───────────┘  └───────────┘   │ │
│  │  - Collects results   │      │  ┌───────────┐  ┌───────────┐   │ │
│  │                       │◀─────│  │ Worker 3  │  │ Worker N  │   │ │
│  │                       │      │  │ (Executor)│  │ (Executor)│   │ │
│  └──────────────────────┘      │  └───────────┘  └───────────┘   │ │
│                                  └──────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────────────┘
```

---

## Compute Type Decision Flow

```
                        ┌─────────────────────┐
                        │  Need Compute?       │
                        └──────────┬──────────┘
                                   │
                    ┌──────────────┴──────────────┐
                    ▼                              ▼
          ┌─────────────────┐            ┌─────────────────┐
          │  Serverless      │            │  Classic         │
          │  (Managed by DB) │            │  (User-managed)  │
          └─────────────────┘            └────────┬────────┘
                                                   │
                                    ┌──────────────┴──────────────┐
                                    ▼                              ▼
                          ┌─────────────────┐           ┌──────────────────┐
                          │  All-Purpose     │           │  Job Cluster      │
                          │  (Interactive)   │           │  (Automated)      │
                          │                  │           │                   │
                          │  - Ad hoc work   │           │  - ETL pipelines  │
                          │  - Dev/testing   │           │  - Scheduled jobs │
                          │  - Shared usage  │           │  - Cost-effective │
                          │  - Persistent    │           │  - Ephemeral      │
                          └─────────────────┘           └──────────────────┘
```

---

## CONCEPT GAP: SQL Warehouses (Databricks SQL Compute)

The original lesson covers clusters but omits an important compute type: **SQL Warehouses** (formerly SQL Endpoints).

- **SQL Warehouses** are a specialized compute resource optimized for SQL analytics and BI workloads.
- They are separate from All-Purpose and Job clusters and are managed via the "SQL Warehouses" tab in the Databricks workspace.
- Types of SQL Warehouses:
  - **Classic SQL Warehouse**: Runs in the customer's subscription, user-configurable.
  - **Serverless SQL Warehouse**: Runs in the Databricks subscription, instant startup, auto-scales.
  - **Pro SQL Warehouse**: Enhanced classic warehouse with additional features like query federation.
- SQL Warehouses support only SQL workloads (no Python, Scala, or R).
- They are the recommended compute type for **Databricks SQL dashboards**, **alerts**, and **BI tool connections** (e.g., Tableau, Power BI).

| Feature | All-Purpose Cluster | Job Cluster | SQL Warehouse |
|---------|-------------------|-------------|---------------|
| **Workload type** | Interactive, multi-language | Automated jobs | SQL analytics/BI |
| **Languages** | Python, SQL, Scala, R | Python, SQL, Scala, R | SQL only |
| **Lifecycle** | Persistent | Ephemeral (per job) | Persistent or auto-stop |
| **Sharing** | Multi-user | Single job | Multi-user (concurrent queries) |
| **Photon** | Optional | Optional | Enabled by default |
| **Best for** | Development, exploration | Production pipelines | Dashboards, reports, BI |

---

## CONCEPT GAP: Delta Live Tables (DLT) Compute

Delta Live Tables pipelines use their own managed compute that is distinct from all-purpose or job clusters:

- **DLT pipelines** automatically provision and manage their own clusters.
- Users define pipeline configuration (e.g., number of workers, auto-scaling) but do not directly create or manage the cluster.
- DLT pipelines can run in **Triggered** mode (batch) or **Continuous** mode (streaming).
- The DLT compute is optimized for running the declarative ETL framework and includes automatic error handling, data quality expectations, and lineage tracking.

---

## CONCEPT GAP: Cluster Pools

Cluster Pools reduce cluster startup time for classic compute:

- A **pool** is a set of idle, ready-to-use VM instances.
- When a cluster is created using a pool, it draws VMs from the pool instead of provisioning new ones from the cloud provider.
- This reduces startup time from several minutes to under a minute.
- Pools can be configured with min/max idle instances and auto-termination for idle instances.
- Unlike serverless compute (which is fully managed by Databricks), pools are managed by the customer within their own subscription.

```
┌────────────────────────────────────────────┐
│              CLUSTER POOL                   │
│                                             │
│   ┌──────┐  ┌──────┐  ┌──────┐  ┌──────┐  │
│   │ Idle │  │ Idle │  │ Idle │  │ Idle │  │
│   │  VM  │  │  VM  │  │  VM  │  │  VM  │  │
│   └──┬───┘  └──┬───┘  └──────┘  └──────┘  │
│      │         │                            │
└──────┼─────────┼────────────────────────────┘
       │         │
       ▼         ▼
┌─────────────────────────┐
│  New Cluster (fast start)│
│  Driver + Workers drawn  │
│  from pool               │
└─────────────────────────┘
```

---

## Conclusion

You should now have a good understanding of:
- The difference between serverless and classic compute
- The two types of classic compute clusters
- When to use all-purpose vs. job clusters
- The benefits and limitations of each compute option

---

## KEY INTERVIEW QUESTIONS AND ANSWERS

### Q1: What is the difference between an All-Purpose cluster and a Job cluster?
**A:** All-Purpose clusters are **persistent** and **interactive** -- they can be started, stopped, and restarted manually. They support multi-user collaboration and are ideal for development, ad hoc analysis, and exploration. Job clusters are **ephemeral** -- they are created automatically when a scheduled job starts and terminated when the job completes. They cannot be restarted or shared. Job clusters are less expensive because Databricks offers a lower DBU rate for automated (job) workloads compared to interactive (all-purpose) workloads.

### Q2: When would you choose Serverless Compute over Classic Compute?
**A:** Serverless Compute is ideal when you need fast cluster startup times (seconds vs. minutes), want to minimize administrative overhead (no VM type or scaling configuration), or need compute for SQL Warehouse workloads. Classic Compute is preferred when you require full control over VM types, custom libraries via init scripts, VNet injection for strict network isolation, Scala support, or spot instances for cost optimization.

### Q3: What is a SQL Warehouse and how does it differ from an All-Purpose cluster?
**A:** A SQL Warehouse is a compute resource specifically optimized for SQL analytics and BI workloads. Unlike All-Purpose clusters that support Python, SQL, Scala, and R, SQL Warehouses only support SQL. They have Photon enabled by default for accelerated query performance, support concurrent multi-user query execution, and are designed to connect with BI tools like Tableau and Power BI. They come in Classic, Pro, and Serverless variants.

### Q4: What are Cluster Pools and how do they improve performance?
**A:** Cluster Pools are sets of pre-provisioned, idle VM instances maintained in the customer's cloud subscription. When a new cluster is created using a pool, it draws VMs from the pool instead of provisioning new instances from the cloud provider, reducing startup time from several minutes to under a minute. Pools can be configured with minimum and maximum idle instance counts and have their own auto-termination settings for idle instances.

### Q5: Why are Job clusters less expensive than All-Purpose clusters?
**A:** Job clusters cost less for two reasons: (1) Databricks charges a lower DBU rate for automated/job workloads compared to interactive/all-purpose workloads, and (2) Job clusters are ephemeral -- they exist only for the duration of the job execution and are automatically terminated afterward, so there is no idle time cost. All-Purpose clusters, by contrast, may run idle between interactive uses, accumulating charges.

### Q6: What compute resources does a Delta Live Tables pipeline use?
**A:** DLT pipelines automatically provision and manage their own dedicated compute. Users define pipeline configuration parameters (number of workers, auto-scaling settings) but do not directly create or manage the underlying cluster. This compute is optimized for the declarative ETL framework and supports both Triggered (batch) and Continuous (streaming) execution modes with automatic error handling and data quality enforcement.

### Q7: Can multiple users share a Job cluster?
**A:** No. A Job cluster is isolated to the specific job being executed. It is created when the job starts, runs only that job's workload, and is terminated when the job completes. It cannot be shared with other users or workloads. For shared compute, use an All-Purpose cluster with Shared Access Mode, or a SQL Warehouse for concurrent SQL queries.

### Q8: What is the role of the Driver Node vs. Worker Nodes in a Databricks cluster?
**A:** The **Driver Node** runs the SparkContext, parses user code, creates the execution plan (logical and physical), coordinates task distribution to workers, and collects final results. **Worker Nodes** run Executors that execute the actual data processing tasks assigned by the driver. Each worker processes a partition of the data in parallel. The driver is always an on-demand instance, while workers can optionally use spot/preemptible instances for cost savings.

---

*End of lesson*