# Configuring Clusters for Unity Catalog

## Introduction

Welcome back. By now, you will be familiar with Databricks cluster configurations from the earlier lessons, but there are some **important things you need to bear in mind** when creating clusters to work with Unity Catalog.

### What We'll Cover:

In this lesson, we'll:
1. Review key differences for Unity Catalog clusters
2. Identify critical configuration requirements
3. Ensure our cluster can work with Unity Catalog
4. Troubleshoot common issues

---

## Prerequisites

### What You Should Know:

- ✅ Basic cluster configurations (covered in earlier lessons)
- ✅ How to create and edit clusters
- ✅ Unity Catalog fundamentals

**Note:** We won't repeat all configuration explanations—only those specific to Unity Catalog.

---

## Accessing Cluster Configuration

### Navigation Steps:

1. Navigate to Databricks workspace
2. Go to **Compute** menu
3. Select your cluster
4. Click **"Edit"** to edit configurations

---

## Unity Catalog Support Indicator

### The Summary Section ⭐

**Key Feature:**
The cluster summary shows whether the cluster supports Unity Catalog.

**What to Look For:**

```
✅ Good: "Supports Unity Catalog"
❌ Bad: No Unity Catalog mention
```

**⚠️ Critical Rule:**
**Always ensure the summary confirms your cluster supports Unity Catalog before proceeding.**

---

## Three Critical Configurations for Unity Catalog

There are **three important configurations** that determine whether your cluster can access Unity Catalog:

1. Databricks Runtime Version
2. Access Mode
3. Credential Passthrough

Let's examine each one in detail.

---

## Configuration 1: Databricks Runtime Version

### Minimum Requirement

**Databricks Recommendation:**
Use **Runtime version 11.3 or higher** to work with Unity Catalog.

### Testing Different Versions

#### ❌ Version 9.1 (Too Old)

**Configuration:**
- Runtime: 9.1 LTS

**Result in Summary:**
```
❌ Does NOT support Unity Catalog
```

**Conclusion:**
Cannot use version 9.1 for Unity Catalog.

#### ⚠️ Version 10.4 (Borderline)

**Configuration:**
- Runtime: 10.4 LTS

**Result in Summary:**
```
✅ Supports Unity Catalog
```

**Note:**
While it works, Databricks recommends 11.3 or higher.

#### ✅ Version 11.3+ (Recommended)

**Configuration:**
- Runtime: 11.3 LTS or higher

**Result in Summary:**
```
✅ Supports Unity Catalog
```

**Best Practice:**
Use the latest LTS version available.

**For This Course:**
- Runtime: **15.4 LTS** (latest available at time of recording)

### Runtime Version Summary

| Version | Unity Catalog Support | Recommendation |
|---------|---------------------|----------------|
| **< 11.3** | ❌ Not supported or ⚠️ Limited | Don't use |
| **11.3** | ✅ Supported | Minimum version |
| **11.3+** | ✅ Fully supported | ⭐ Recommended |
| **15.4 LTS** | ✅ Fully supported | ⭐⭐ Best (current latest) |

---

## Configuration 2: Access Mode

### Available Access Modes Review

From previous lessons, we know there are three access modes:
1. Single User
2. Shared
3. No Isolation Shared

### Unity Catalog Compatibility

#### ✅ Single User Access Mode

**Characteristics:**
- One user per cluster
- Full language support

**Unity Catalog Support:**
```
✅ Supports Unity Catalog
```

**Use When:**
- Individual development
- Personal workloads
- Single-user scenarios

#### ✅ Shared Access Mode

**Characteristics:**
- Multiple users
- Process isolation
- Security features

**Unity Catalog Support:**
```
✅ Supports Unity Catalog
```

**Use When:**
- Team collaboration
- Production workloads
- Multi-user scenarios

#### ❌ No Isolation Shared Mode

**Characteristics:**
- Multiple users
- No process isolation
- Legacy mode

**Unity Catalog Support:**
```
❌ Does NOT support Unity Catalog
```

**What Happens:**
When you select "No Isolation Shared":
- Summary updates
- "Unity Catalog" disappears from summary
- Cannot use Unity Catalog with this mode

**⚠️ Important:**
**Do NOT use "No Isolation Shared" with Unity Catalog.**

### Access Mode Comparison

| Access Mode | Unity Catalog Support | Recommended For |
|-------------|---------------------|-----------------|
| **Single User** | ✅ Yes | Individual work |
| **Shared** | ✅ Yes | Team/Production |
| **No Isolation Shared** | ❌ No | ⚠️ Never use with Unity Catalog |

### Selection Guidance

**Choose Between:**
- **Single User**: Individual development, testing
- **Shared**: Collaborative work, production environments

**Based on your requirements:**
- Need collaboration? → Shared
- Working alone? → Single User
- Need Unity Catalog? → Never No Isolation Shared

---

## Configuration 3: Credential Passthrough

### What is Credential Passthrough?

A legacy feature that passes user credentials directly to cloud storage.

### Unity Catalog Compatibility

**⚠️ Critical Warning:**

When **Credential Passthrough is ENABLED**:
```
❌ Cluster CANNOT support Unity Catalog
```

**What Happens:**
- Enable credential passthrough checkbox
- Summary updates
- Unity Catalog support disappears

### Why Avoid Credential Passthrough?

#### Reason 1: Unity Catalog Incompatibility
- Cannot be used with Unity Catalog
- Blocks Unity Catalog features

#### Reason 2: Deprecation
- Slowly being deprecated from Databricks
- Legacy feature being phased out

#### Reason 3: Better Alternatives
- Unity Catalog provides better security
- More modern access control
- Enhanced governance

### Recommendation

**⭐ Best Practice:**
- ✅ Keep credential passthrough **UNTICKED**
- ✅ Don't use for any future projects
- ✅ Use Unity Catalog access controls instead

**If your workspace is enabled with Unity Catalog:**
**DO NOT enable credential passthrough.**

---

## Configuration Summary for Unity Catalog

### The Three Required Configurations

| Configuration | Setting | Why |
|--------------|---------|-----|
| **Runtime Version** | 11.3 or higher (recommend 15.4 LTS) | Minimum requirement for UC support |
| **Access Mode** | Single User OR Shared | No Isolation Shared doesn't support UC |
| **Credential Passthrough** | DISABLED (unticked) | Incompatible with Unity Catalog |

### Visual Checklist

```
✅ Databricks Runtime: 15.4 LTS (or 11.3+)
✅ Access Mode: Single User or Shared
✅ Credential Passthrough: Disabled
═══════════════════════════════════════
Result: "Supports Unity Catalog" ✓
```

### Correct Configuration Example

**Cluster Settings:**
```
Access Mode: Single User
Databricks Runtime: 15.4 LTS
Credential Passthrough: [ ] (unchecked)
───────────────────────────────────
Summary: ✅ Supports Unity Catalog
```

---

## Troubleshooting: Unity Catalog Not Showing

### If Unity Catalog Still Not Showing

Even with correct configurations, Unity Catalog might not appear in the summary.

**There can be only TWO reasons:**

### Reason 1: Workspace Not Enabled with Unity Catalog

**Problem:**
The workspace itself hasn't been enabled with Unity Catalog.

**Solution:**
1. Verify workspace has Unity Catalog enabled
2. Check in Account Console
3. Ensure workspace is attached to a Metastore
4. Follow previous lesson on Metastore configuration

**Verification Command:**
```sql
SELECT current_metastore();
```

**Expected:** Returns Metastore name
**If Error:** Workspace not enabled with Unity Catalog

---

### Reason 2: Cluster Created Before Unity Catalog Enablement

**Problem:**
- Cluster was created BEFORE enabling Unity Catalog
- Now Unity Catalog is enabled
- Cluster hasn't recognized the change

**Solution - Refresh the Cluster:**

#### Steps:

1. **Go to cluster configuration:**
   - Navigate to Compute
   - Select your cluster
   - Click "Edit"

2. **Toggle Access Mode:**
   - Switch to different access mode
   - Switch back to original access mode
   - This refreshes the cluster configuration

3. **Verify Summary:**
   - Check summary section
   - Should now show "Supports Unity Catalog"

#### Example Toggle Process:

```
Current: Single User
   ↓
Change to: Shared
   ↓
Change back to: Single User
   ↓
Result: Unity Catalog appears in summary
```

**Why This Works:**
- Forces cluster to re-evaluate configuration
- Recognizes Unity Catalog is now available
- Updates internal settings

---

## Troubleshooting Decision Tree

```
Unity Catalog not showing in summary?
        │
        ├─ All 3 configs correct?
        │     │
        │     ├─ No → Fix configurations
        │     │        - Runtime 11.3+
        │     │        - Single/Shared mode
        │     │        - No credential passthrough
        │     │
        │     └─ Yes → Check workspace
        │              │
        │              ├─ Workspace enabled with UC?
        │              │     │
        │              │     ├─ No → Enable Unity Catalog
        │              │     │        (see previous lesson)
        │              │     │
        │              │     └─ Yes → Cluster created before UC?
        │              │              │
        │              │              └─ Yes → Toggle access mode
        │              │                       to refresh config
        │              │
        │              └─ Still issues? → Contact support
```

---

## Verification Steps

### Final Verification Checklist

Before proceeding, ensure:

- [ ] **Runtime Version:**
  - ✅ Version 11.3 or higher
  - ⭐ Recommended: Latest LTS (e.g., 15.4)

- [ ] **Access Mode:**
  - ✅ Single User OR Shared
  - ❌ NOT "No Isolation Shared"

- [ ] **Credential Passthrough:**
  - ✅ Disabled (unchecked)
  - ❌ NOT enabled

- [ ] **Summary Check:**
  - ✅ "Supports Unity Catalog" visible
  - ✅ No warnings or errors

- [ ] **Workspace Verification:**
  - ✅ Workspace enabled with Unity Catalog
  - ✅ Attached to Metastore

---

## Saving and Starting the Cluster

### Save Configuration Changes

After making all necessary changes:

1. **Review all settings**
   - Double-check the three critical configurations
   - Verify summary shows Unity Catalog support

2. **Click "Confirm"**
   - Saves all configuration changes
   - May require cluster restart

3. **Start the Cluster**
   - Click **"Start"** button
   - Cluster will initialize with new settings
   - Wait for cluster to become ready

### Post-Start Verification

**Test Unity Catalog Access:**

```sql
-- In a notebook attached to the cluster
SELECT current_metastore();
```

**Expected Result:**
- Returns your Metastore name
- Confirms Unity Catalog is accessible

**If Error:**
- Review configurations again
- Check troubleshooting section
- Verify workspace settings

---

## Best Practices Summary

### ✅ Do's

| Best Practice | Reason |
|--------------|--------|
| **Use Runtime 11.3+** | Unity Catalog requirement |
| **Choose Single User or Shared** | Only modes supporting UC |
| **Disable Credential Passthrough** | Incompatible with UC and deprecated |
| **Check Summary** | Confirms UC support before proceeding |
| **Use Latest LTS** | Best stability and features |

### ❌ Don'ts

| Practice to Avoid | Why |
|------------------|-----|
| **Using old runtimes (<11.3)** | No UC support |
| **No Isolation Shared mode** | Doesn't support UC |
| **Enabling Credential Passthrough** | Blocks UC functionality |
| **Skipping verification** | May cause issues later |

---

## Quick Reference Card

### Unity Catalog Cluster Configuration

**Minimum Requirements:**
```
Runtime Version:  11.3+ (Recommended: 15.4 LTS)
Access Mode:      Single User OR Shared
Credential PT:    Disabled ❌
═══════════════════════════════════════════
Result: Must show "Supports Unity Catalog"
```

**Common Issues:**

| Symptom | Cause | Fix |
|---------|-------|-----|
| UC not in summary | Runtime < 11.3 | Upgrade to 11.3+ |
| UC not in summary | No Isolation Shared | Change to Single/Shared |
| UC not in summary | Credential PT enabled | Disable Credential PT |
| UC not in summary | Workspace not enabled | Enable UC on workspace |
| UC not in summary | Old cluster config | Toggle access mode |

---

## Summary

### Key Takeaways:

1. **Three Critical Configurations** for Unity Catalog:
   - Runtime Version (11.3+)
   - Access Mode (Single User or Shared)
   - Credential Passthrough (Disabled)

2. **Always verify** "Supports Unity Catalog" appears in summary

3. **Two main troubleshooting scenarios**:
   - Workspace not UC-enabled
   - Cluster needs configuration refresh

4. **Credential Passthrough** is being deprecated—don't use it

5. **Use latest LTS runtime** for best experience

### What's Next:

Now that your cluster is properly configured for Unity Catalog:
- ✅ You can create catalogs and schemas
- ✅ You can work with Unity Catalog tables and volumes
- ✅ You can leverage Unity Catalog governance features

### Final Reminder:

**Before proceeding with Unity Catalog work:**
**Ensure your cluster summary shows: "Supports Unity Catalog"**

---

## CONCEPT GAP: Access Modes Deep Dive

Understanding access modes is a frequently tested topic. Each mode has specific implications for security, language support, and Unity Catalog compatibility.

### Access Mode Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                    SINGLE USER MODE                             │
│                                                                 │
│  ┌───────────────────────────────────────┐                     │
│  │           Cluster                      │                     │
│  │  ┌─────────────────────────────────┐  │                     │
│  │  │  Single User's Processes       │  │                     │
│  │  │  - Python, Scala, R, SQL       │  │                     │
│  │  │  - Full library support        │  │                     │
│  │  │  - Init scripts allowed        │  │                     │
│  │  │  - DBFS access (legacy)        │  │                     │
│  │  └─────────────────────────────────┘  │                     │
│  │  Unity Catalog: SUPPORTED             │                     │
│  └───────────────────────────────────────┘                     │
│  Only ONE user can use this cluster                             │
└─────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────┐
│                      SHARED MODE                                │
│                                                                 │
│  ┌───────────────────────────────────────┐                     │
│  │           Cluster                      │                     │
│  │  ┌──────────┐  ┌──────────┐          │                     │
│  │  │  User A  │  │  User B  │  ...     │                     │
│  │  │(isolated)│  │(isolated)│          │                     │
│  │  └──────────┘  └──────────┘          │                     │
│  │  Process isolation enforced           │                     │
│  │  Some library restrictions            │                     │
│  │  Unity Catalog: SUPPORTED             │                     │
│  └───────────────────────────────────────┘                     │
│  Multiple users share; each is process-isolated                 │
└─────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────┐
│                 NO ISOLATION SHARED MODE                         │
│                                                                 │
│  ┌───────────────────────────────────────┐                     │
│  │           Cluster                      │                     │
│  │  ┌──────────────────────────────────┐ │                     │
│  │  │  All Users (NO isolation)        │ │                     │
│  │  │  User A, User B, User C...      │ │                     │
│  │  │  Shared process space            │ │                     │
│  │  └──────────────────────────────────┘ │                     │
│  │  Unity Catalog: NOT SUPPORTED         │                     │
│  └───────────────────────────────────────┘                     │
│  LEGACY mode -- avoid for new workloads                         │
└─────────────────────────────────────────────────────────────────┘
```

### Detailed Access Mode Feature Comparison

| Feature | Single User | Shared | No Isolation Shared |
|---------|------------|--------|---------------------|
| **Unity Catalog** | Yes | Yes | No |
| **Multi-user** | No | Yes | Yes |
| **Process isolation** | N/A (single user) | Yes | No |
| **Python** | Full | Restricted (no arbitrary JVM) | Full |
| **Scala** | Full | Limited | Full |
| **R** | Full | Supported | Full |
| **SQL** | Full | Full | Full |
| **Init scripts** | Yes | No | Yes |
| **Cluster libraries** | Yes | Restricted | Yes |
| **DBFS access** | Yes (legacy) | No (UC paths only) | Yes |
| **Credential passthrough** | Possible (not with UC) | No | No |
| **Best for** | Dev/test | Production multi-user | Legacy only |

---

## CONCEPT GAP: Databricks Runtime Versions and Unity Catalog Feature Evolution

Not all Unity Catalog features are available in every runtime version. Understanding the progression helps with troubleshooting and exam questions.

### Runtime Feature Matrix

| Runtime Version | UC Tables | UC Views | UC Functions | Volumes | Row Filters | Column Masks |
|----------------|-----------|----------|-------------|---------|-------------|-------------|
| **< 11.3** | No | No | No | No | No | No |
| **11.3 LTS** | Yes | Yes | Basic | No | No | No |
| **12.2 LTS** | Yes | Yes | Yes | Preview | No | No |
| **13.3 LTS** | Yes | Yes | Yes | Yes | Yes | Yes |
| **14.3 LTS** | Yes | Yes | Yes | Yes | Yes | Yes |
| **15.4 LTS** | Yes | Yes | Yes | Yes | Yes | Yes |

### LTS vs Non-LTS Runtimes

```
┌────────────────────────────────────────────────────────────┐
│                  LTS (Long Term Support)                   │
│                                                            │
│  - Supported for 2+ years                                  │
│  - Receives security patches and bug fixes                 │
│  - Recommended for production workloads                    │
│  - Examples: 11.3 LTS, 12.2 LTS, 13.3 LTS, 14.3 LTS     │
│                                                            │
│  BEST PRACTICE: Always use the latest LTS for production   │
└────────────────────────────────────────────────────────────┘

┌────────────────────────────────────────────────────────────┐
│              Non-LTS (Standard Release)                    │
│                                                            │
│  - Shorter support window                                  │
│  - May include experimental features                       │
│  - Good for testing new features                           │
│  - Not recommended for production                          │
└────────────────────────────────────────────────────────────┘
```

---

## CONCEPT GAP: Serverless Compute and Unity Catalog

Serverless SQL warehouses and serverless compute are increasingly important in the Databricks ecosystem and are always Unity Catalog-enabled.

### Serverless vs Classic Compute

```
CLASSIC COMPUTE (Clusters):
┌──────────────────────────────────────────┐
│  You configure:                          │
│  - Runtime version                       │
│  - Access mode                           │
│  - Node types and counts                 │
│  - Credential passthrough setting        │
│  Must verify "Supports Unity Catalog"    │
└──────────────────────────────────────────┘

SERVERLESS COMPUTE:
┌──────────────────────────────────────────┐
│  Databricks manages:                     │
│  - Runtime version (always latest)       │
│  - Infrastructure and scaling            │
│  - Always Unity Catalog enabled          │
│  - No configuration needed for UC        │
│  - Instant startup                       │
│  No cluster config decisions required!   │
└──────────────────────────────────────────┘

SQL WAREHOUSES:
┌──────────────────────────────────────────┐
│  - Serverless or Classic (Pro)           │
│  - Always supports Unity Catalog         │
│  - Designed for SQL/BI workloads         │
│  - Auto-scaling and auto-suspend         │
│  - Optimized for concurrent queries      │
└──────────────────────────────────────────┘
```

| Feature | Classic Cluster | Serverless Compute | SQL Warehouse |
|---------|----------------|-------------------|---------------|
| **UC Support** | Requires config | Always enabled | Always enabled |
| **Runtime** | User selects | Auto-managed | Auto-managed |
| **Startup time** | Minutes | Seconds | Seconds (serverless) |
| **Best for** | Custom ML/DE | General notebooks | SQL/BI queries |
| **Cost model** | DBU + VM | DBU only | DBU only |

---

## CONCEPT GAP: Credential Passthrough vs Unity Catalog Access Control

Understanding why credential passthrough is deprecated in favor of Unity Catalog access control is important for interviews and exams.

### Comparison of Access Models

```
CREDENTIAL PASSTHROUGH (DEPRECATED):
═════════════════════════════════════
  User A ──credential──▶ S3 Storage
  User B ──credential──▶ S3 Storage
  User C ──credential──▶ S3 Storage

  Problems:
  - Each user needs direct IAM identity
  - No centralized audit trail
  - No fine-grained table/column/row security
  - Incompatible with Unity Catalog
  - Being phased out


UNITY CATALOG ACCESS CONTROL (RECOMMENDED):
════════════════════════════════════════════
  User A ─┐
  User B ─┼──▶ Unity Catalog ──▶ Storage Credential ──▶ S3 Storage
  User C ─┘      (checks         (IAM role)
                  permissions
                  centrally)

  Benefits:
  - Centralized permission management
  - Full audit trail via system tables
  - Fine-grained access (table, column, row)
  - Data lineage tracking
  - Works with all UC features
```

---

## KEY INTERVIEW QUESTIONS AND ANSWERS

### Q1: What are the three critical cluster configurations required for Unity Catalog support?
**A:** The three critical configurations are: (1) Databricks Runtime version must be 11.3 or higher (latest LTS recommended), (2) Access Mode must be either Single User or Shared (No Isolation Shared does not support Unity Catalog), and (3) Credential Passthrough must be disabled (unchecked). All three must be correctly configured, and you should verify by checking that the cluster summary displays "Supports Unity Catalog."

### Q2: Why does "No Isolation Shared" access mode not support Unity Catalog?
**A:** No Isolation Shared mode does not enforce process isolation between users sharing the cluster. Unity Catalog requires process isolation to enforce per-user access controls and ensure that one user cannot access data they are not authorized to see. Without isolation, a malicious user could potentially bypass Unity Catalog's security model by inspecting another user's processes or memory. Single User mode avoids this by allowing only one user, while Shared mode enforces strict process-level isolation.

### Q3: Why is credential passthrough being deprecated, and what replaces it?
**A:** Credential passthrough is deprecated because it passes individual user Azure AD credentials directly to cloud storage, bypassing centralized governance. This means there is no unified audit trail, no fine-grained table/column/row level security, and no data lineage tracking. Unity Catalog replaces this with a centralized access control model using storage credentials and managed identities. Unity Catalog provides a single point of authorization with comprehensive auditing, making credential passthrough both unnecessary and incompatible with the new governance model.

### Q4: What should you do if a cluster does not show "Supports Unity Catalog" in its summary even though configurations appear correct?
**A:** There are two possible causes: (1) The workspace itself has not been enabled with Unity Catalog -- verify by running `SELECT current_metastore();` and if it returns an error, the workspace needs to be attached to a Metastore via the Account Console. (2) The cluster was created before Unity Catalog was enabled on the workspace -- fix this by toggling the access mode (e.g., switch from Single User to Shared and back to Single User) to force the cluster to re-evaluate its configuration and recognize the newly available Unity Catalog.

### Q5: What is the difference between Single User and Shared access modes, and when would you use each?
**A:** Single User mode restricts the cluster to one user but provides full language support (Python, Scala, R, SQL), init scripts, and custom libraries with no restrictions. Shared mode allows multiple users with process isolation but restricts some features like init scripts, arbitrary JVM access from Python, and certain libraries. Use Single User for individual development, testing, or workloads requiring unrestricted language features. Use Shared mode for production multi-user environments, team collaboration, and when cost optimization through shared resources is important.

### Q6: How do SQL Warehouses and Serverless Compute relate to Unity Catalog cluster configuration?
**A:** SQL Warehouses (both Serverless and Pro) and Serverless Compute always support Unity Catalog without any manual configuration. They use auto-managed runtimes that are always current and always have Unity Catalog enabled. This eliminates the need to configure runtime versions, access modes, or credential passthrough settings. For new workloads, especially SQL/BI workloads, Databricks recommends SQL Warehouses. Serverless Compute is ideal for notebook-based workloads where instant startup and zero configuration are desired.

### Q7: What runtime version should you use for production Unity Catalog workloads?
**A:** For production workloads, always use the latest available LTS (Long Term Support) runtime version. LTS versions are supported for 2+ years with security patches and bug fixes, making them suitable for production stability. While the minimum requirement for Unity Catalog is 11.3, newer LTS versions (13.3+, 14.3+, 15.4+) include additional features like Volumes, row-level filters, and column masking. Avoid non-LTS versions in production as they have shorter support windows.

### Q8: Can you change a cluster's access mode while it is running?
**A:** No, changing the access mode requires the cluster to be restarted. When you modify the access mode in the cluster configuration, you must confirm the changes and the cluster will need to restart with the new settings. This is because the access mode fundamentally changes how the cluster handles user sessions, process isolation, and security enforcement. Always verify the summary shows "Supports Unity Catalog" after making changes and before running workloads.

---

*End of lesson*