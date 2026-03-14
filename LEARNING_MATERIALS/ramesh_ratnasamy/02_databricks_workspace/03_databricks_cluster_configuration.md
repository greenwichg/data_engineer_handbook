# Databricks Cluster Configuration Options

## Introduction

As we discussed in the last lesson, classic compute allows us to configure the cluster ourselves, but it's not straightforward.

Databricks presents us with a variety of options to configure the cluster. In this lesson, I'll walk you through each one of these in detail.

---

## 1. Cluster Type: Single Node vs. Multi-Node

### Multi-Node Cluster

**Architecture:**
- Includes **one driver node** and **one or more worker nodes**

**How it Works:**
- When you run a Spark job, the driver node distributes tasks to worker nodes
- Allows for parallel execution
- Provides **horizontal scalability** based on workload demands

**Best For:**
- Large-scale workloads
- Production ETL pipelines
- Distributed processing

### Single Node Cluster

**Architecture:**
- Contains **only a driver node**
- No worker nodes

**How it Works:**
- Still supports Spark workloads
- The same node acts as both master and worker
- **Cannot be horizontally scaled**

**Limitations:**
- Unsuitable for large-scale ETL workloads
- Incompatible with process isolation
- Not intended for shared usage among multiple users or workloads

**Best For:**
- Lightweight machine learning tasks
- Data analysis tasks that don't require distributed computing
- Development and testing

**⚠️ Databricks Recommendation:**
Always use **multi-node clusters** when shared compute is needed to avoid conflicts.

---

## 2. Access Mode

A **security feature** that controls who can use the compute and what data they can access.

### Three Types of Access Modes:

### Single User Access Mode

| Aspect | Details |
|--------|---------|
| **User Access** | Only a single user can access the cluster |
| **Language Support** | All four languages: Python, SQL, Scala, and R |
| **Use Case** | Individual development work |

### Shared Access Mode

| Aspect | Details |
|--------|---------|
| **User Access** | Multiple users can share the cluster |
| **Process Isolation** | ✅ Yes - each process operates in its own environment |
| **Security** | Prevents one process from accessing another process's data or credentials |
| **Availability** | Only on **premium workspaces** |
| **Language Support** | Python and SQL (Scala support added recently for Unity Catalog enabled workspaces from Databricks Runtime 13.3 onwards) |
| **Recommendation** | ⭐ **Recommended for production workloads** |

### No Isolation Shared Mode

| Aspect | Details |
|--------|---------|
| **User Access** | Allows cluster sharing |
| **Process Isolation** | ❌ No |
| **Task Preemption** | ❌ No - failures or resource overuse by one user can affect others |
| **Availability** | Both standard and premium workspaces |
| **Language Support** | All four languages: Python, SQL, Scala, and R |
| **Recommendation** | Not recommended for production |

**🎯 Production Recommendation:**
Use **Shared Access Mode** as it offers:
- Process isolation
- Task preemption
- Better security and reliability

---

## 3. Databricks Runtime

Databricks runtimes are the **set of core libraries** that run on Databricks clusters.

### Two Types of Runtimes:

### Databricks Runtime

**Includes:**
- Optimized version of Apache Spark
- Various supporting libraries

### Databricks Runtime ML

**Includes:**
- Everything in Databricks Runtime
- Popular machine learning libraries:
  - PyTorch
  - Keras
  - TensorFlow
  - XGBoost
  - And more

### Photon Option

Both runtimes allow you to **enable or disable Photon**:
- A vectorized query engine
- Accelerates Apache Spark workloads

---

## 4. Auto Termination

A useful feature to **prevent unnecessary costs** on idle clusters.

### How it Works:

- Automatically terminates a cluster if it remains unused for a specified period
- **Default**: 120 minutes (2 hours)
- **Configurable Range**: 10 to 43,200 minutes (30 days)

### Purpose:

Prevent costs from clusters that are left running but not being used.

---

## 5. Auto Scaling

### Configuration (Multi-Node Clusters Only):

When creating a multi-node cluster, you can specify:
- **Minimum number of nodes**
- **Maximum number of nodes**

### How it Works:

- Automatically adjusts the number of nodes based on workload
- Optimizes cluster utilization

### Best For:

- Unpredictable workloads
- Workloads that fluctuate during processing

---

## 6. Spot Instances

### Overview:

An option to save costs by using spare cloud capacity.

### Key Points:

**Driver Nodes:**
- Always **on-demand** nodes
- Cannot use spot instances

**Worker Nodes:**
- Can opt for spot instances
- Offered at a cheaper price

### What Are Spot Instances?

- Unused VMs or spare capacity in the cloud
- Offered at a discounted price
- **Risk**: Could be evicted if another customer acquires the instance at the usual price

### Databricks Handling:

When spot instances become unavailable, Databricks will:
1. Attempt to acquire replacement spot instances
2. Switch to on-demand instances as a fallback

---

## 7. Cluster VM Types

Azure offers a range of VM types, which Databricks groups into specific categories.

### Memory Optimized

**Best For:**
- Memory-intensive workloads
- Machine learning workloads that cache large datasets

### Compute Optimized

**Best For:**
- Structured streaming applications where peak-time processing rates are critical
- Distributed analytics workloads
- Data science workloads

### Storage Optimized

**Best For:**
- Use cases requiring high disk throughput and I/O

### General Purpose

**Best For:**
- Enterprise-grade applications
- Analytical workloads with in-memory caching

### GPU Accelerated

**Best For:**
- Deep learning models that are both data and compute intensive

### Selection:

Choose any VM type based on your specific workload requirements.

---

## 8. Cluster Policies

### The Problem:

With so many configuration options, creating clusters can become:
- Overwhelming for engineers
- Result in oversized clusters that exceed budget constraints

### The Solution: Cluster Policies

Databricks offers cluster policies to help prevent these issues.

### How Cluster Policies Work:

**Administrators can:**
- Set restrictions on cluster configurations
- Assign policies to specific users or groups

### Example: Personal Compute Policy

When applied, this policy:
- ✅ Restricts users to creating only **single-node clusters**
- ✅ Defaults to the **ML runtime**
- ✅ Limits the **node types** available
- ✅ Sets **auto termination to 20 minutes**

### Benefits:

1. **Simplifies the user interface**
2. **Reduces administrator involvement** in every decision
3. **Controls costs** by limiting cluster size
4. **Ensures compliance** with organizational standards

---

## Summary

You now have a comprehensive understanding of all the configuration options available when creating a Databricks cluster:

1. **Cluster Type**: Single node vs. multi-node
2. **Access Mode**: Single user, shared, or no isolation shared
3. **Databricks Runtime**: Standard or ML with Photon option
4. **Auto Termination**: Automatic shutdown of idle clusters
5. **Auto Scaling**: Dynamic node allocation
6. **Spot Instances**: Cost savings on worker nodes
7. **VM Types**: Optimized for different workload types
8. **Cluster Policies**: Administrative controls and cost management

### What's Next:

In the next lesson, we'll create a cluster using these configuration options.

---

## Access Mode Decision Diagram

```
                    ┌──────────────────────────┐
                    │  How many users need      │
                    │  access to this cluster?   │
                    └────────────┬───────────────┘
                                 │
              ┌──────────────────┼──────────────────┐
              ▼                  ▼                   ▼
   ┌──────────────────┐ ┌───────────────┐  ┌────────────────────┐
   │  Single User      │ │  Multiple     │  │  Multiple Users    │
   │                    │ │  Users        │  │  (No security      │
   │  All 4 languages  │ │  (Need        │  │   requirements)    │
   │  Single user only │ │   isolation)  │  │                    │
   └──────────────────┘ └───────┬───────┘  └────────────────────┘
                                │                     │
                                ▼                     ▼
                      ┌─────────────────┐  ┌────────────────────┐
                      │  Shared Mode     │  │ No Isolation Shared│
                      │  (Premium only)  │  │ (Standard+Premium) │
                      │  Python + SQL    │  │ All 4 languages    │
                      │  Process isolat. │  │ No isolation       │
                      │  RECOMMENDED     │  │ NOT recommended    │
                      └─────────────────┘  └────────────────────┘
```

---

## Runtime Version Lifecycle

```
┌─────────────────────────────────────────────────────────────────────┐
│                  DATABRICKS RUNTIME LIFECYCLE                        │
│                                                                      │
│  Release ──────► GA ──────► LTS Designation ──────► End of Support  │
│                                                                      │
│  ┌─────────────────────────────────────────────────────────────────┐ │
│  │  Standard Runtime    │ Released frequently, shorter support     │ │
│  ├──────────────────────┼─────────────────────────────────────────┤ │
│  │  LTS Runtime         │ Every ~6 months, supported for 2 years  │ │
│  ├──────────────────────┼─────────────────────────────────────────┤ │
│  │  ML Runtime          │ Adds PyTorch, TensorFlow, XGBoost, etc. │ │
│  ├──────────────────────┼─────────────────────────────────────────┤ │
│  │  Photon-enabled      │ Vectorized C++ engine on top of runtime │ │
│  └──────────────────────┴─────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────────────┘
```

---

## CONCEPT GAP: Photon Engine Deep Dive

Photon is frequently tested on Databricks certification exams:

- **Photon** is a **vectorized query engine** written in C++ that runs natively on Databricks clusters.
- It replaces parts of the Spark execution engine (specifically the Spark SQL and DataFrame operations) with highly optimized native code.
- Photon provides the greatest performance improvement for:
  - Scan-heavy workloads (reading large Delta tables)
  - Aggregations and joins
  - Data ingestion and ETL
  - SQL-heavy analytics
- Photon is **not** a separate runtime; it is an **acceleration layer** that can be enabled on any Databricks Runtime.
- Photon workloads are billed at a higher DBU rate, but total cost often decreases because queries finish faster.
- Photon is **enabled by default** on SQL Warehouses.

---

## CONCEPT GAP: Databricks Runtime Versions in Detail

Understanding runtime components is important for certification:

| Component | Databricks Runtime | Databricks Runtime ML |
|-----------|-------------------|----------------------|
| Apache Spark (optimized) | Yes | Yes |
| Delta Lake | Yes | Yes |
| Ubuntu OS | Yes | Yes |
| Java / Scala / Python / R | Yes | Yes |
| GPU support libraries | No | Yes |
| PyTorch | No | Yes |
| TensorFlow / Keras | No | Yes |
| XGBoost | No | Yes |
| Horovod (distributed training) | No | Yes |
| MLflow (pre-installed) | No | Yes |

- **LTS runtimes** receive bug fixes and security patches for 2 years. Use LTS for production.
- **Non-LTS runtimes** are supported for approximately 6 months. Use for experimentation and accessing new features.
- **Runtime version numbering**: e.g., 15.4 LTS means major version 15, minor version 4, Long Term Support.

---

## CONCEPT GAP: Cluster Policies in Detail

Cluster policies are an important governance feature:

- **Policy definition**: Cluster policies are defined as JSON documents that specify constraints on cluster configuration attributes.
- **Types of constraints**:
  - **Fixed**: The attribute is set to a specific value and cannot be changed (e.g., `"type": "fixed", "value": "Standard_DS3_v2"`).
  - **Allowlist**: Restricts the attribute to a list of allowed values.
  - **Range**: Sets minimum/maximum values (e.g., number of workers between 1 and 10).
  - **Unlimited**: No restriction on the attribute.
- **Default policies** provided by Databricks:
  - Personal Compute (single-node only)
  - Power User Compute
  - Job Compute
  - Legacy Shared Compute
- **Permissions**: Admins create policies and assign them to users/groups. Users with a policy can only create clusters within those policy constraints.

---

## Comprehensive Configuration Comparison Table

| Configuration | Options | Default | Impact |
|---------------|---------|---------|--------|
| **Cluster Type** | Single-node, Multi-node | Multi-node | Scalability, workload suitability |
| **Access Mode** | Single User, Shared, No Isolation | Single User | Security, language support, sharing |
| **Runtime** | Standard, ML, with/without Photon | Latest LTS | Available libraries, performance |
| **Auto Termination** | 10-43,200 minutes | 120 minutes | Cost control |
| **Auto Scaling** | Min/Max workers | Enabled (2-8) | Resource optimization |
| **Spot Instances** | On/Off for workers | Off | Cost savings vs. reliability |
| **VM Type** | Memory/Compute/Storage/General/GPU | General Purpose | Performance profile |
| **Cluster Policy** | Unrestricted or custom | Unrestricted | Governance, cost control |

---

## KEY INTERVIEW QUESTIONS AND ANSWERS

### Q1: What is the difference between Single User and Shared access modes?
**A:** Single User access mode restricts a cluster to one user but supports all four languages (Python, SQL, Scala, R). Shared access mode allows multiple users to share the cluster with process isolation -- each user's processes run in separate environments, preventing one user from accessing another's data or credentials. Shared mode is only available on premium workspaces and traditionally supports Python and SQL (Scala was added for Unity Catalog-enabled workspaces from DBR 13.3+). Shared mode is recommended for production workloads because of its security guarantees.

### Q2: What is Photon and when should you enable it?
**A:** Photon is a vectorized query engine written in C++ that accelerates Spark SQL and DataFrame operations. It provides the greatest benefit for scan-heavy workloads, aggregations, joins, and large-scale ETL. Photon-enabled clusters have a higher DBU rate, but total cost often decreases because queries finish faster. Enable Photon for large-scale production workloads where query performance is critical. For small development workloads, the additional cost may not be justified. Photon is enabled by default on SQL Warehouses.

### Q3: Why would you choose an LTS runtime over the latest runtime version?
**A:** LTS (Long Term Support) runtimes are released every six months and supported with bug fixes and security patches for two years. They provide stability and predictability critical for production workloads. The latest (non-LTS) runtimes include newer features but have shorter support windows (~6 months) and may contain undiscovered issues. Best practice is to use LTS runtimes for production and non-LTS for development or when a specific new feature is needed.

### Q4: How do Cluster Policies help organizations manage costs?
**A:** Cluster Policies are JSON-based configurations that administrators create to restrict what users can configure when creating clusters. Policies can fix specific values (e.g., only single-node clusters), set allowlists (e.g., approved VM types), define ranges (e.g., max 10 workers), and set defaults (e.g., auto-termination at 20 minutes). This prevents over-provisioning, ensures cost compliance, simplifies the cluster creation UI for users, and reduces the need for admin involvement in every cluster creation decision.

### Q5: When would you disable auto-scaling on a cluster?
**A:** Disable auto-scaling for streaming workloads where the time to scale up nodes is unacceptable and consistent throughput is required, workloads with predictable and constant resource needs, or performance-sensitive jobs where adding/removing nodes could cause data shuffle overhead. When auto-scaling is disabled, set a fixed number of worker nodes that matches the expected workload requirements.

### Q6: What is the risk of using spot instances and how does Databricks handle it?
**A:** Spot instances (called Spot VMs on Azure, Spot Instances on AWS) use spare cloud capacity at significant discounts (up to 60-90% savings). The risk is that the cloud provider can reclaim (evict) these VMs with little notice when capacity is needed by on-demand customers. Databricks mitigates this by: (1) only allowing spot instances for worker nodes, keeping the driver on-demand to prevent job loss; (2) attempting to acquire replacement spot instances when eviction occurs; (3) falling back to on-demand instances if spot instances are unavailable. Use spot instances for fault-tolerant, non-time-critical workloads.

### Q7: What is the difference between Memory Optimized and Compute Optimized VM types?
**A:** Memory Optimized VMs have a high memory-to-CPU ratio and are best for workloads that cache large datasets in memory, such as machine learning training, large Delta table joins, or workloads with heavy broadcast variables. Compute Optimized VMs have a high CPU-to-memory ratio and are best for CPU-intensive workloads like structured streaming with high throughput requirements, distributed analytics with complex transformations, and data science workloads with heavy computation. Choose based on whether your workload is memory-bound or CPU-bound.

### Q8: Can you change a single-node cluster to a multi-node cluster after creation?
**A:** No. The cluster type (single-node vs. multi-node) is a fundamental architectural decision that cannot be changed after the cluster is created. To switch from single-node to multi-node, you must create a new cluster. However, other configurations like runtime version, node types, auto-termination settings, and advanced configurations can be edited on an existing cluster (some changes require a cluster restart).

---

*End of lesson*