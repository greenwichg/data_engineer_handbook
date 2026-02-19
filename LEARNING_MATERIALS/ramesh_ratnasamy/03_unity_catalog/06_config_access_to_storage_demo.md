 # Configuring Cloud Storage Access via Unity Catalog: Hands-On Lab

## Introduction

Welcome back. Now that we understand how to configure access to an Azure Data Lake Storage container via Unity Catalog, let's switch over to the Azure portal and try and **implement this solution**.

### What We'll Accomplish:

In this hands-on lesson, we'll:
1. Create Access Connector for Azure Databricks
2. Create Azure Data Lake Storage Gen2 account
3. Assign IAM role to Access Connector
4. Create Storage Credential in Unity Catalog
5. Create External Location
6. Test data access

---

## Step 1: Create Access Connector for Azure Databricks

### Navigation in Azure Portal

#### 1. Start Resource Creation

1. Go to **Azure Portal**
2. Click **top-left menu**
3. Click **"Create a Resource"**

#### 2. Search for Access Connector

1. Search for: **"Access Connector for Azure Databricks"**
2. Select the result
3. Click **"Create"**

---

### Configure Access Connector

#### Resource Group Selection

**Use existing resource group:**
```
Resource Group: d-org
```

**Why this choice?**
- ✅ Everything for this course in same resource group
- ✅ Easier to manage and clean up
- ✅ Consistent organization

#### Naming Convention

**Access Connector Name:**
```
d-course-ext-ac
```

**Naming Breakdown:**

| Component | Meaning | Example |
|-----------|---------|---------|
| `d-course` | Course identifier | d-course |
| `ext` | External storage | ext |
| `ac` | Access Connector | ac |

**Why "ext"?**
- Represents **external storage**
- Not the default storage attached to Metastore
- Clear identification of purpose

#### Region Selection

**Region:**
```
UK South
```

**Selection Criteria:**
- ✅ Select region closest to you
- ✅ Must match Databricks workspace region
- ✅ Must match storage account region

#### Tags (Optional)

**Configuration:**
- Add tags if desired
- Optional for this course
- Click **"Next"**

---

### Managed Identity Configuration

#### Review Identity Settings

**Screen: Manage Identity**

**Configuration shown:**
```
Identity Type: System-assigned managed identity ✓
```

**What This Means:**
- ✅ Selected by default
- ✅ Good enough for our needs
- ✅ Azure manages the identity lifecycle
- ✅ No manual credential management

**Accept defaults and proceed.**

---

### Create Access Connector

#### Final Steps

1. Click **"Review + Create"**
2. Review all settings
3. Click **"Create"**

**Result:**
✅ Access Connector is now created

---

## Step 2: Create Azure Data Lake Storage Gen2 Account

### Navigation in Azure Portal

#### 1. Start Resource Creation

1. Go to **top-left menu**
2. Click **"Create a Resource"**

#### 2. Search for Storage Account

1. Search for: **"Storage Account"**
2. Select the one with the **green icon**
3. Click **"Create"**

---

### Configure Storage Account

#### Basic Settings

##### Resource Group

**Use existing:**
```
Resource Group: d-org
```

**Consistency:** Same resource group as other resources.

##### Storage Account Name

**Name:**
```
dcoursextdl
```

**⚠️ Important Naming Rules:**
- Must be **alphanumeric only**
- ❌ No hyphens allowed
- ❌ No underscores allowed
- ✅ Lowercase letters and numbers only
- Must be globally unique

**Naming Breakdown:**

| Component | Meaning |
|-----------|---------|
| `dcourse` | Course identifier |
| `ext` | External storage |
| `dl` | Data Lake |

**Note:** "dl" stands for **Data Lake**, not Delta Lake.

##### Region

**Region:**
```
UK South
```

**⚠️ Critical:** Must match Access Connector region and workspace region.

##### Performance

**Selection:**
```
Performance: Standard
```

**Why Standard?**
- ✅ Sufficient for development
- ✅ Cost-effective
- ✅ Meets our needs

##### Redundancy

**Selection:**
```
Redundancy: Locally-redundant storage (LRS)
```

**Why LRS?**
- ✅ Cheaper than geo-redundant
- ✅ Sufficient for development/learning
- ✅ Cost-effective option

**Other Options:**
- Leave **Primary Service** as blank
- Click **"Next"**

---

### Advanced Settings

#### Hierarchical Namespace ⭐

**⚠️ CRITICAL SETTING:**

**Configuration:**
```
☑ Enable hierarchical namespace
```

**Why This is Important:**

| Setting | Result |
|---------|--------|
| **Enabled** | ✅ Azure Data Lake Storage Gen2 |
| **Disabled** | ❌ Regular Blob Storage (NOT a Data Lake) |

**What This Does:**
- Enables ADLS Gen2 capabilities
- Provides file system semantics
- Required for Data Lakehouse architecture
- **Essential for this course**

**⚠️ Important:**
**Enabling hierarchical namespace is what makes a storage account an Azure Data Lake Storage Gen2 account.**

**Ensure this is checked!**

#### Other Settings

**Configuration:**
- Leave everything else as default
- No additional changes needed

---

### Create Storage Account

#### Final Steps

1. Click **"Review + Create"**
2. Review all settings
3. Click **"Create"**

**Result:**
✅ Storage account is now created

#### Navigate to Resource

After creation:
1. Click **"Go to resource"**
2. View the storage account details

---

## Step 3: Assign IAM Role to Access Connector

### Current State

**What We Have:**
- ✅ Storage account created
- ✅ Access connector created

**What We Need:**
Give the Access Connector **Storage Blob Data Contributor** role on the storage account.

**Why?**
So the Access Connector can access the storage account.

---

### Assign Role Procedure

#### 1. Navigate to Access Control

**In Storage Account:**
1. Find **"Access Control (IAM)"** in left menu
2. Click **"IAM"**

#### 2. Add Role Assignment

**Actions:**
1. Click **"+ Add"**
2. Select **"Add role assignment"** from dropdown

---

### Select Role

#### 1. Search for Role

**In Role Search Box:**
```
Storage Blob Data Contributor
```

#### 2. Select Role

**From Results:**
- Find: **"Storage Blob Data Contributor"**
- ✅ This is the role we want to assign
- Click to select it
- Click **"Next"**

---

### Assign to Managed Identity

#### 1. Select Assignment Type

**Assign Access To:**
```
☑ Managed Identity
```

**Why?**
The Access Connector is a managed identity behind the scenes.

#### 2. Select Members

**Actions:**
1. Click **"+ Select members"**
2. Window opens on the right side

#### 3. Find Access Connector

**In Members Window:**

**Under "Managed Identity" dropdown:**
```
Select: Access Connector for Azure Databricks
```

**What You'll See:**

Potentially two Access Connectors:
1. One created by you (`d-course-ext-ac`)
2. One created by Databricks by default (if present)

**⚠️ Important Notes:**

| Subscription Created | Default Access Connector |
|---------------------|------------------------|
| **After November 2023** | ✅ May see default connector |
| **Before November 2023** | ❌ May not see default connector |

**Selection:**
- ✅ Select: `d-course-ext-ac` (the one YOU created)
- ❌ Ignore: Any default connector

#### 4. Confirm Selection

1. Select **`d-course-ext-ac`**
2. Click **"Select"**

---

### Complete Role Assignment

#### 1. Review and Assign

**Actions:**
1. Click **"Review + assign"**
2. Review the assignment details
3. Click **"Review + assign"** again to confirm

**Result:**
✅ Access Connector now has Storage Blob Data Contributor role on the storage account

---

### Verify Role Assignment

#### Check Role Assignments

**In Storage Account:**
1. Go to **"Access Control (IAM)"**
2. Navigate to **"Role assignments"** tab
3. Scroll to find your Access Connector

**What You Should See:**

| Identity | Role | Scope |
|----------|------|-------|
| `d-course-ext-ac` | Storage Blob Data Contributor | Storage Account (`dcoursextdl`) |

**Confirmation:**
✅ Access Connector has the correct role
✅ Step 3 complete!

---

## Step 4: Create Storage Credential

### Where to Create Storage Credential

**Two Options:**

| Method | Tool |
|--------|------|
| **CLI** | Databricks CLI |
| **UI** | Databricks Workspace Interface |

**Our Choice:** UI (easier for learning)

---

### Navigate to Catalog Explorer

#### Path to Credentials

1. Go to **Databricks Workspace**
2. Click **"Catalog"** in sidebar
3. Opens **Catalog Explorer**
4. Click **"External Data"** (top menu)
5. Navigate to **"Credentials"** tab

**What You'll See:**
- All existing storage credentials
- Option to create new credentials

---

### Understanding Storage Credentials

#### What IS a Storage Credential?

**Visual Hierarchy:**

```
Storage Credential (Unity Catalog Object)
    ↓ wraps
Access Connector (Azure Resource)
    ↓ wraps
Managed Identity (Azure AD Identity)
```

**Explanation:**

A storage credential is:
1. A **Unity Catalog object**
2. That wraps an **Access Connector**
3. Which wraps a **Managed Identity**

**Result:**
Eventually, it's just a managed identity that's been wrapped twice:
- Once by the Access Connector
- Again by the Unity Catalog Storage Credential object

#### Why Create Storage Credential?

**The Problem:**
- Unity Catalog only knows about **storage credentials**
- Unity Catalog doesn't know about **managed identities**

**The Solution:**
- Wrap the managed identity into a storage credential
- Unity Catalog can then use this credential (like a user)
- Access the storage account

#### Access Flow

**What We've Done:**
```
1. Access Connector → Storage Blob Data Contributor role → Storage Account
2. Access Connector contains → Managed Identity
3. Managed Identity has → Storage access
```

**What We're Doing Now:**
```
4. Wrap Access Connector → Storage Credential
5. Storage Credential inherits → Same access (Storage Blob Data Contributor)
```

**Result:**
✅ Storage Credential has Storage Blob Data Contributor access to storage account

---

### Create Storage Credential

#### Existing Credentials

**Note:**
You might see a credential already created by default.

**Common Scenarios:**

| Situation | What You See |
|-----------|--------------|
| **New subscription** | May have default credential |
| **Old subscription** | May not have default credential |

**Don't worry if you don't see one—it doesn't matter.**

**Action:**
We're creating a **new one** for this course.

---

#### Start Creation

**Action:**
Click **"Create Credential"**

---

### Configure Storage Credential

#### Credential Type

**Selection:**
```
Credential Type: Managed identity
```

**Why?**
We're using an Access Connector with managed identity.

#### Credential Name

**Name:**
```
d-course-ext-sc
```

**Naming Breakdown:**

| Component | Meaning |
|-----------|---------|
| `d-course` | Course identifier |
| `ext` | External (not default) |
| `sc` | Storage Credential |

**Consistency:** Following same naming pattern as other resources.

---

#### Access Connector ID

**What's Needed:**
The **Resource ID** of the Access Connector.

**Why?**
We're wrapping the Access Connector into the Storage Credential.

---

### Get Access Connector ID

#### Navigate to Access Connector

**In Azure Portal:**

**Option 1: Search**
1. Click search bar (top)
2. Search: **"Access Connector for Azure Databricks"**
3. Select your connector: `d-course-ext-ac`

**Option 2: Resource Group**
1. Go to resource group: `d-org`
2. Find: `d-course-ext-ac`
3. Click to open

#### Find Resource ID

**Two Locations:**

**Location 1: Overview Page (Right Side)**
```
Resource ID: /subscriptions/.../resourceGroups/.../providers/...
```

**Location 2: Properties**
1. Go to **"Settings"**
2. Click **"Properties"**
3. Find **"Resource ID"**

#### Copy Resource ID

**Action:**
1. Select the full Resource ID
2. Copy it

**Format:**
```
/subscriptions/{subscription-id}/resourceGroups/{rg-name}/providers/Microsoft.Databricks/accessConnectors/{connector-name}
```

---

### Complete Storage Credential Creation

#### Paste Access Connector ID

**Back in Catalog Explorer:**
1. Paste the copied Resource ID
2. Into **"Access Connector ID"** field

#### Other Settings

**User-Assigned Managed Identity:**
```
Leave blank
```

**Why?**
We're using system-assigned, not user-assigned.

**Comment (Optional):**
```
Add a comment if desired (optional)
```

#### Create Credential

**Final Step:**
Click **"Create"**

**Result:**
✅ Storage Credential is now created

---

### Verify Storage Credential

#### View Credentials

**In Catalog Explorer:**
1. Click **"Credentials"** tab
2. View all credentials

**What You Should See:**

| Credential Name | Type | Status |
|----------------|------|--------|
| `d-course-ext-sc` | Managed Identity | ✅ Active |
| (Default credential) | (if present) | Active |

**Confirmation:**
✅ Newly created storage credential visible
✅ Step 4 complete!

---

## Step 5: Create Container in Storage Account

### Why Create Container First?

Before creating the External Location, we need:
- A container in the storage account
- To test access before and after creating External Location

---

### Navigate to Storage Account

#### In Azure Portal

1. Go to storage account: `dcoursextdl`
2. Find containers section

**Two Navigation Options:**

**Option 1: Storage Browser**
- Click **"Storage browser"** (left menu)
- Navigate to containers

**Option 2: Containers**
- Under **"Data storage"**
- Click **"Containers"**

**Our Choice:** Use Containers (more direct)

---

### Create Container

#### Container Creation

1. Click **"+ Container"**
2. Container creation dialog opens

#### Container Name

**Name:**
```
demo
```

**Settings:**
- Simple name for demo purposes
- Leave other settings as default

#### Create

Click **"Create"**

**Result:**
✅ Container named "demo" is created

---

### Current State

**What We Have:**

| Component | Value |
|-----------|-------|
| **Storage Account** | `dcoursextdl` |
| **Container** | `demo` |
| **Access Connector** | `d-course-ext-ac` (with IAM role) |
| **Storage Credential** | `d-course-ext-sc` (wraps connector) |
| **External Location** | ❌ Not yet created |

**Next:** Create External Location and test access.

---

## Step 6: Test Access WITHOUT External Location

### Why Test First?

**Purpose:**
- Verify we DON'T have access (expected)
- Create External Location
- Verify we DO have access (success)
- Demonstrates the External Location's role

---

### Create Notebook for Testing

#### Notebook Location

**Path:**
```
Workspace
  └── d-course/
      └── db-unity-catalog/
          └── Configure_Access_to_Cloud_Storage
```

**Notebook Created:**
- Name: `Configure Access to Cloud Storage`
- For creating External Location
- For testing access

---

### Test Container Access

#### Construct Container URL

**Format:**
```
abfss://{container}@{storage-account}.dfs.core.windows.net/
```

**Our Values:**

| Component | Value |
|-----------|-------|
| Protocol | `abfss://` |
| Container | `demo` |
| Storage Account | `dcoursextdl` |
| Suffix | `.dfs.core.windows.net` |

**Complete URL:**
```
abfss://demo@dcoursextdl.dfs.core.windows.net/
```

---

#### List Container Contents

**Command:**
```python
%fs ls abfss://demo@dcoursextdl.dfs.core.windows.net/
```

**Breakdown:**

| Component | Purpose |
|-----------|---------|
| `%fs` | Databricks file system magic command |
| `ls` | List contents |
| `abfss://...` | ADLS Gen2 URL |

#### Execute Command

**Action:**
1. Enter command in notebook cell
2. Execute cell

---

### Expected Error

**Error Message:**
```
Failure: Invalid configuration value detected for account key
```

**What This Means:**

| Aspect | Explanation |
|--------|-------------|
| **Error Type** | Configuration/Authentication error |
| **Cause** | No access to storage account container |
| **Expected** | ✅ Yes, this is what we expect |
| **Solution** | Create External Location |

**Why This Happens:**
- ❌ No External Location created yet
- ❌ Unity Catalog can't access the container
- ❌ Authentication fails

**✅ This is expected behavior!**

---

## Step 7: Create External Location

### Approach: Programmatic Creation

**Why Use SQL?**

| Benefit | Description |
|---------|-------------|
| **Repeatable** | Can run across environments |
| **Version Control** | Can store in git |
| **Documentation** | Self-documenting code |
| **Automation** | Easier to automate |

**Alternative:**
Could use UI (Catalog Explorer → Create External Location), but programmatic is better practice.

---

### External Location SQL Syntax

#### Documentation Reference

**SQL Command:**
```sql
CREATE EXTERNAL LOCATION [IF NOT EXISTS] <location_name>
URL '<storage_url>'
WITH (STORAGE CREDENTIAL <credential_name>)
[COMMENT '<comment>'];
```

---

### Build Our External Location Command

#### Basic Structure

**Copy syntax template:**
```sql
CREATE EXTERNAL LOCATION IF NOT EXISTS <name>
URL '<url>'
WITH (STORAGE CREDENTIAL <credential>)
COMMENT '<comment>';
```

---

#### Define Location Name

**Naming Convention:**

**Format:**
```
{storage-account}_{container}
```

**Our Name:**
```sql
d_course_ext_dl_demo
```

**Breakdown:**

| Component | Meaning |
|-----------|---------|
| `d_course` | Course identifier |
| `ext` | External storage |
| `dl` | Data Lake (storage account) |
| `demo` | Container name |

**Why This Convention?**

| Benefit | Explanation |
|---------|-------------|
| **Clarity** | Obvious which storage account |
| **No Clashes** | Unique names |
| **Easy Identification** | Can trace back to resources |
| **Standard** | Consistent across project |

---

#### Specify URL

**Use the URL we tested earlier:**
```sql
URL 'abfss://demo@dcoursextdl.dfs.core.windows.net/'
```

**Component Breakdown:**
- Protocol: `abfss://`
- Container: `demo`
- Storage Account: `dcoursextdl`
- Suffix: `.dfs.core.windows.net/`

---

#### Specify Storage Credential

**Get Credential Name:**

**From Catalog Explorer:**
1. Go to Credentials tab
2. Find our credential: `d-course-ext-sc`
3. Copy name

**Add to Command:**
```sql
WITH (STORAGE CREDENTIAL d_course_ext_sc)
```

**Note:** Use underscore in SQL (not hyphen).

---

#### Add Comment (Optional)

**Example:**
```sql
COMMENT 'External location for demo container in d-course data lake'
```

---

### Complete SQL Command

**Full Command:**
```sql
CREATE EXTERNAL LOCATION IF NOT EXISTS d_course_ext_dl_demo
URL 'abfss://demo@dcoursextdl.dfs.core.windows.net/'
WITH (STORAGE CREDENTIAL d_course_ext_sc)
COMMENT 'External location for demo container in d-course data lake';
```

---

### Execute Command

#### Run in Notebook

**Actions:**
1. Paste complete SQL command into notebook cell
2. Execute cell

**Result:**
```
External location created successfully
```

✅ **External Location is now created!**

---

### Verify External Location

#### Check in Catalog Explorer

**Navigation:**
1. Go to **Catalog Explorer**
2. Click **"External Data"**
3. Navigate to **"External Locations"** tab

**What You Should See:**

| Location Name | URL | Storage Credential | Status |
|--------------|-----|-------------------|--------|
| `d_course_ext_dl_demo` | `abfss://demo@...` | `d_course_ext_sc` | ✅ Active |

**Confirmation:**
✅ External Location visible in Catalog Explorer
✅ Linked to correct credential
✅ Points to correct container

---

## Step 8: Test Access WITH External Location

### Retry Container Access

#### Same Command as Before

**Command:**
```python
%fs ls abfss://demo@dcoursextdl.dfs.core.windows.net/
```

**What's Different Now?**
- ✅ External Location created
- ✅ Storage Credential configured
- ✅ Access should work

---

### Execute Test

**Actions:**
1. Go back to the test cell in notebook
2. Re-execute the same command

**Expected Before:**
```
❌ Error: Invalid configuration value detected for account key
```

**Expected After:**
```
✅ Success: (empty list or "OK")
```

---

### Verify Success

**Result:**
```
OK
```

**What This Means:**

| Result | Interpretation |
|--------|---------------|
| `OK` | ✅ Command succeeded |
| `OK` (not file list) | ✅ Container is empty (expected) |
| No error | ✅ Access is working |
| Authentication | ✅ Successful |

**Why Just "OK"?**
- Container is empty
- We just created it
- No files to list
- Therefore returns "OK" instead of file list

---

### Success Confirmation

**What We've Proven:**

1. **Before External Location:**
   - ❌ Access failed
   - ❌ Authentication error

2. **After External Location:**
   - ✅ Access successful
   - ✅ Can list container
   - ✅ Authentication working

**✅ We've successfully configured access to Azure Data Lake Storage via Unity Catalog!**

---

## Complete Architecture Review

### What We Built

```
┌─────────────────────────────────────────────────────────────┐
│                   Azure Subscription                        │
│                                                             │
│  ┌──────────────────────┐       ┌───────────────────────┐ │
│  │ Access Connector     │       │ ADLS Gen2 Storage     │ │
│  │ (d-course-ext-ac)    │──────▶│ (dcoursextdl)         │ │
│  │                      │ Role  │                       │ │
│  │ Managed Identity     │       │ Container: demo       │ │
│  └──────────────────────┘       └───────────────────────┘ │
│           │                               ▲                 │
└───────────┼───────────────────────────────┼─────────────────┘
            │                               │
            │ (Wrapped in)                  │ (Accesses)
            ▼                               │
┌─────────────────────────────────────────────────────────────┐
│               Databricks Unity Catalog                      │
│                                                             │
│  ┌──────────────────────┐                                  │
│  │ Storage Credential   │                                  │
│  │ (d-course-ext-sc)    │──────────────────────────────┐  │
│  └──────────────────────┘                               │  │
│           │                                              │  │
│           │ (Combined with URL)                          │  │
│           ▼                                              │  │
│  ┌──────────────────────────────────────────────────┐   │  │
│  │ External Location                                │   │  │
│  │ (d_course_ext_dl_demo)                          │   │  │
│  │                                                  │   │  │
│  │ URL: abfss://demo@dcoursextdl...                │───┘  │
│  └──────────────────────────────────────────────────┘      │
│           │                                                 │
└───────────┼─────────────────────────────────────────────────┘
            │
            ▼
        ┌───────┐
        │ Users │
        └───────┘
```

---

## Complete Implementation Summary

### Resources Created

| # | Resource Type | Resource Name | Purpose |
|---|--------------|---------------|---------|
| 1 | Access Connector | `d-course-ext-ac` | Managed identity for authentication |
| 2 | Storage Account | `dcoursextdl` | ADLS Gen2 data lake |
| 3 | Container | `demo` | Storage container |
| 4 | IAM Role | Storage Blob Data Contributor | Grant access to connector |
| 5 | Storage Credential | `d-course-ext-sc` | Unity Catalog authentication |
| 6 | External Location | `d_course_ext_dl_demo` | Access path to container |

### Configuration Steps Completed

**Phase 1: Azure Resources (Steps 1-3)**
- [x] Created Access Connector with managed identity
- [x] Created ADLS Gen2 storage account with hierarchical namespace
- [x] Assigned Storage Blob Data Contributor role to Access Connector

**Phase 2: Unity Catalog Objects (Steps 4-6)**
- [x] Created Storage Credential wrapping Access Connector
- [x] Created container in storage account
- [x] Created External Location combining credential and URL

**Phase 3: Testing (Step 7-8)**
- [x] Verified access fails without External Location
- [x] Created External Location programmatically
- [x] Verified access succeeds with External Location

---

## Key Commands Reference

### Azure Portal Actions

| Action | Steps |
|--------|-------|
| **Create Access Connector** | Create Resource → Search "Access Connector" |
| **Create Storage Account** | Create Resource → Search "Storage Account" |
| **Assign IAM Role** | Storage Account → IAM → Add Role Assignment |
| **Create Container** | Storage Account → Containers → + Container |

### Databricks Commands

**Test Access (Magic Command):**
```python
%fs ls abfss://{container}@{storage-account}.dfs.core.windows.net/
```

**Create External Location (SQL):**
```sql
CREATE EXTERNAL LOCATION IF NOT EXISTS {location_name}
URL 'abfss://{container}@{storage-account}.dfs.core.windows.net/'
WITH (STORAGE CREDENTIAL {credential_name})
COMMENT '{description}';
```

---

## Naming Conventions Used

### Resource Naming Pattern

| Resource | Pattern | Example |
|----------|---------|---------|
| **Access Connector** | `{project}-ext-ac` | `d-course-ext-ac` |
| **Storage Account** | `{project}extdl` | `dcoursextdl` |
| **Storage Credential** | `{project}-ext-sc` | `d-course-ext-sc` |
| **External Location** | `{project}_ext_dl_{container}` | `d_course_ext_dl_demo` |

**Key Components:**
- `{project}`: Course or project identifier
- `ext`: External (not default)
- `ac`: Access Connector
- `dl`: Data Lake
- `sc`: Storage Credential

---

## Troubleshooting Guide

### Common Issues and Solutions

| Issue | Cause | Solution |
|-------|-------|----------|
| **"Invalid account key" error** | No External Location | Create External Location |
| **Can't find Access Connector** | Wrong resource group | Check resource group filter |
| **Storage account name taken** | Not globally unique | Add unique identifier |
| **Hierarchical namespace disabled** | Wrong configuration | Recreate storage account |
| **Role assignment not working** | Wrong managed identity | Verify Access Connector selected |
| **External Location creation fails** | Wrong credential name | Verify Storage Credential name |

---

## Best Practices Demonstrated

### ✅ Good Practices We Followed

1. **Consistent Naming:**
   - Clear naming conventions
   - Easy to identify resources
   - No naming conflicts

2. **Resource Organization:**
   - Same resource group for related resources
   - Easy to manage and clean up

3. **Documentation:**
   - Comments on resources
   - Clear identification of purpose

4. **Testing:**
   - Test failure first
   - Verify success after configuration

5. **Programmatic Creation:**
   - SQL for External Location
   - Repeatable and versionable

6. **Hierarchical Namespace:**
   - Enabled for ADLS Gen2 capabilities
   - Required for Data Lakehouse

---

## What's Next

### You Can Now:

- ✅ Create Access Connectors for authentication
- ✅ Set up ADLS Gen2 storage accounts
- ✅ Assign IAM roles for access control
- ✅ Create Unity Catalog Storage Credentials
- ✅ Create External Locations programmatically
- ✅ Access cloud storage via Unity Catalog

### Upcoming Topics:

Now that we have storage access configured:
1. Create catalogs using External Locations
2. Create schemas within catalogs
3. Create managed and external tables
4. Work with volumes for file storage
5. Implement data governance features

---

## Summary

### Key Achievements:

**Successfully Configured:**
1. ✅ Access Connector with managed identity
2. ✅ ADLS Gen2 storage account with hierarchical namespace
3. ✅ IAM role assignment for authorization
4. ✅ Unity Catalog Storage Credential
5. ✅ External Location for container access
6. ✅ Verified end-to-end access

**Key Learnings:**

| Concept | Understanding |
|---------|--------------|
| **Access Connector** | Wraps managed identity for Databricks |
| **Storage Credential** | Unity Catalog authentication object |
| **External Location** | Combines credential + URL for access |
| **Hierarchical Namespace** | Required for ADLS Gen2 |
| **IAM Roles** | Control access to Azure resources |
| **Programmatic Creation** | Better than UI for repeatability |

### Critical Points:

1. **Hierarchical namespace MUST be enabled** for ADLS Gen2
2. **Storage account names must be alphanumeric** (no hyphens/underscores)
3. **IAM role assignment is critical** for access
4. **External Location combines** credential and URL
5. **Test before and after** to verify configuration

### Result:

✅ **We've successfully configured access to another cloud storage via Unity Catalog from Databricks!**

---

*End of lesson*