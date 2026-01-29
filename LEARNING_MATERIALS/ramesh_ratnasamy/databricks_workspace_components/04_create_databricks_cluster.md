# Creating a Databricks Cluster: Step-by-Step Guide

## Introduction

Now that we understand what Databricks Compute is and how to configure one, let's switch over to the Databricks workspace and create the compute that's required for this course.

---

## Creating a New Cluster

### Navigation Steps:

1. Navigate to the **sidebar** in Databricks Workspace
2. Click on the **Compute icon**
3. Click on the **Create Compute** button under the **All-Purpose Compute** tab

### Naming Your Cluster:

- Databricks assigns a default name
- Click on the cluster name to change it
- **Example**: "course-cluster" to identify it's for this specific course

---

## Configuration Options Walkthrough

### 1. Compute Policy (Cluster Policy)

**Default Policies Available:**
- Four compute policies already provided by Databricks
- Any custom policies you create will also appear here

**For This Tutorial:**
- Select **"Unrestricted"** to explore all configuration options
- This allows us to understand each option better

---

### 2. Multi-Node vs. Single-Node Decision

#### For This Course:

**We'll create a Single-Node cluster because:**
- We're dealing with only a small amount of data
- Single-node clusters are cheaper to run
- Lower cost to complete the course

#### Multi-Node Configuration Options

Before selecting single-node, let's review multi-node options:

**Worker Nodes Configuration:**

| Setting | Description | Example |
|---------|-------------|---------|
| **Minimum Workers** | Workers allocated at startup | 2 nodes |
| **Maximum Workers** | Maximum workers allowed | 8 nodes |
| **Auto Scaling** | Workers added based on workload | Enabled by default |

**Benefits:**
- Pay only for additional capacity when needed
- Expenses limited to maximum specified (e.g., 8 nodes)

**Disabling Auto Scaling:**

**When to Disable:**
- Streaming workloads where scale-up time is unacceptable
- Workloads requiring consistent, predictable performance

**How to Disable:**
- Click the auto-scaling checkbox
- Set a fixed number of worker nodes (e.g., 8)

**Spot Instances Option:**

- ✅ Select checkbox to use unused Azure capacity
- ✅ Saves costs
- ⚠️ Risk of eviction when instances become unavailable
- **Recommendation**: Use only for non-critical workloads

---

### 3. Access Mode Selection

**For Single-Node Clusters:**

**Available Options:**
- Single User
- Shared (not supported for single-node)
- No Isolation Shared (not supported for single-node)

**Our Selection:**
- **Single User Access Mode** (only option for single-node)

**Note**: Databricks recommends Shared Access Mode when possible, but it's not supported for single-node compute.

---

### 4. Databricks Runtime Version

**Runtime Categories:**

Runtimes are grouped into:
- **Standard**: General data engineering workloads
- **ML**: Machine learning workloads (suffixed with "ML")

**Our Selection:**
- **Standard Runtime** (we're doing a data engineering course)

#### Understanding Runtime Versions

**LTS (Long Term Support):**
- Suffixed with "LTS"
- Released every 6 months
- Supported for 2 years with updates and fixes
- **Recommendation**: Use for production workloads

**Latest Versions:**
- Can be used for development workloads
- May have newer features but less stability

**For This Course:**
- **Runtime 15.4 LTS** (latest LTS option at time of recording)
- Provides stability for course content

---

### 5. Photon Acceleration

**What is Photon?**
- Highly performing vectorized query engine
- Accelerates query performance

**Cost Considerations:**

| Aspect | Details |
|--------|---------|
| **Cluster Cost** | More expensive with Photon enabled |
| **Large Workloads** | Likely to save cost overall (queries finish quicker) |
| **Small Workloads** | Not worth the additional cost |

**Our Selection:**
- **Unselect Photon acceleration** (we don't have large workloads)

---

### 6. Node Type Selection

**Available Categories:**
- General Purpose
- Storage Optimized
- Memory Optimized
- GPU Enabled

**Our Selection:**
- **DS3 v2** node
  - 16GB memory
  - 4 cores
  - Small, cost-effective option

**⚠️ Important Notes:**
- Some nodes may not be available in your region
- Select one without a warning sign
- DS3 v2 might not be available when you take this course
- **Alternative**: Select another node with 4 cores (that's all we need)

---

### 7. Auto Termination

**Purpose:**
- Terminates cluster after a period of inactivity
- Prevents unnecessary charges

**Configuration:**

| Setting | Recommendation |
|---------|----------------|
| **Checkbox** | ✅ Ensure it's ticked |
| **Minimum Value** | 10 minutes |
| **Recommended Value** | 20-30 minutes |

**Why 20-30 Minutes?**
- Time to watch a lesson
- Return to cluster for practice session
- Cluster still running
- Automatically terminates if no activity
- No charges after termination

**⚠️ Warning:**
If auto termination is not enabled, you must manually terminate the cluster or continue being charged.

---

### 8. Tags (Optional)

**Purpose:**
- Help with billing attribution
- Associate costs with specific projects

**Default Behavior:**
- Databricks automatically adds some tags
- You can add additional custom tags

---

### 9. Advanced Options

#### Spark Configuration

Specify additional Spark configurations for all workloads executed on this cluster.

#### Environment Variables

Set environment variables if needed.

#### Log Delivery

**Purpose:**
- Save logs to DBFS location
- Keep logs longer for compliance or investigations

**Configuration:**
- Specify DBFS location for log storage

#### Init Scripts

**Purpose:**
- Run initialization scripts when cluster starts
- **Example Use Case**: Install Python packages for consistent developer environment

---

## Creating the Cluster

### Final Steps:

1. Review all configurations
2. Click **"Create Compute"** button
3. Monitor creation progress

### Creation Process:

**Progress Indicators:**
- Icon shows cluster creation is in progress
- View **Event Log** to see detailed progress
- **Creation Time**: Approximately 4 minutes

**Cluster Status Indicators:**

| Indicator | Status |
|-----------|--------|
| **Creating Icon** | Cluster creation in progress |
| **Green Dot** | Cluster is running |

---

## Managing Your Cluster

### Cluster List View

**Navigation:**
- Go back to the Compute icon
- View all available clusters in the workspace

**Features:**

| Feature | Purpose |
|---------|---------|
| **Search Box** | Find specific clusters |
| **User Filter** | Filter by creator (you or specific user) |
| **Favorites** | Pin clusters and filter by "Only Pinned" |

### Cluster Summary Information

**Displays:**
- Active memory (e.g., 14GB)
- Number of cores (e.g., 4 cores)
- **Billing rate**: DBU per hour (e.g., 0.75 DBU/hour)
  - **DBU**: Databricks Units (billing unit for Databricks resources)

### Cluster Actions

**Available Actions:**

| Action | Purpose |
|--------|---------|
| **Terminate** | Stop the cluster |
| **Restart** | Restart the cluster |
| **Clone** | Create a copy of the cluster |
| **Delete** | Permanently remove the cluster |
| **Change Permissions** | Grant access to other users |

#### Managing Permissions:

1. Click on permissions option
2. Add user details
3. Set permission levels for that user

---

## Editing Cluster Configuration

### How to Edit:

1. Click on the **cluster name**
2. Click the **"Edit"** button to enable editing
3. Modify desired configurations
4. Confirm changes

### What Can Be Edited:

**Allowed Changes:**
- ✅ Databricks Runtime version
- ✅ Node types
- ✅ Auto termination settings
- ✅ Advanced configurations

**Restrictions:**
- ❌ Cannot change single-node to multi-node
- ❌ Some fundamental architecture changes not allowed

### Configuration Changes Requiring Restart:

**⚠️ Important Warning:**

Some changes require cluster restart:
- Example: Changing runtime version (15.4 → 16.0)
- Click **"Confirm and Restart"** to apply changes
- **Any running jobs will be terminated** during restart

**Best Practice:**
- Plan configuration changes carefully
- Ensure no critical jobs are running before restart

---

## Cluster Tabs and Features

### 1. Configuration Tab

View and edit cluster configuration settings.

### 2. Notebooks Tab

**Shows:**
- All notebooks attached to this cluster
- Quick access to notebook resources

### 3. Libraries Tab

**Purpose:**
- Install external libraries
- Manage dependencies for the cluster

### 4. Event Log Tab

**Purpose:**
- Logs major events that happened to the cluster
- Essential for troubleshooting

**Common Use Cases:**

| Issue | Action |
|-------|--------|
| Cluster won't start | Check recent events for details |
| Unexpected behavior | Review event history |
| Performance issues | Investigate logged events |

**What You'll See:**
- Standard events during normal operation
- Error messages and details for troubleshooting
- Enough information to start investigation

### 5. Spark UI Tab

Access to:
- Spark User Interface
- Driver logs
- Additional metrics on underlying VMs

### 6. Metrics Tab

View detailed performance metrics for cluster resources.

---

## Understanding Pricing

### DBU (Databricks Units)

**What is it?**
- Billing unit used by Databricks for resources
- **Example**: 0.75 DBU per hour

### Viewing Actual Costs:

**To see pricing in your currency:**
1. Visit the Azure pricing page
2. Look up DBU costs
3. Calculate based on your usage and currency

**Formula:**
```
Total Cost = DBU Rate × Hours Running × DBU Price (in your currency)
```

---

## Terminating the Cluster

### Why Terminate?

**Automatic Termination:**
- Occurs after configured inactivity period (e.g., 30 minutes)
- No manual action required

**Manual Termination:**
- When you know you won't use the cluster soon
- Prevents unnecessary charges

### How to Terminate:

1. Click the **"Terminate"** button
2. Click **"Confirm"**

### What Happens During Termination:

**Preserved:**
- ✅ Cluster configurations are stored
- ✅ Can restart the cluster later
- ✅ All settings retained

**Released:**
- Virtual machines are freed up
- Resources returned to pool

**Billing:**
- ❌ No charges from termination point onwards
- You're only charged while cluster is running

### Restarting a Terminated Cluster:

- Simply click "Start" on the terminated cluster
- Cluster will spin up with saved configurations
- Resumes where you left off

---

## Summary

You now have a comprehensive understanding of:

### Skills Acquired:

1. ✅ Creating a Databricks cluster through the UI
2. ✅ Configuring all cluster options appropriately
3. ✅ Understanding multi-node vs. single-node differences
4. ✅ Managing cluster lifecycle (create, edit, terminate)
5. ✅ Monitoring cluster status and logs
6. ✅ Understanding Databricks billing (DBU)
7. ✅ Managing permissions and resources

### Best Practices Learned:

- Use auto termination to control costs
- Select appropriate node types for workload
- Choose LTS runtimes for stability
- Monitor the event log for troubleshooting
- Manually terminate when not in use

---

*End of lesson*