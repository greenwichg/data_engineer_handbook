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

*End of lesson*