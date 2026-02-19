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

## Conclusion

You should now have a good understanding of:
- The difference between serverless and classic compute
- The two types of classic compute clusters
- When to use all-purpose vs. job clusters
- The benefits and limitations of each compute option

---

*End of lesson*