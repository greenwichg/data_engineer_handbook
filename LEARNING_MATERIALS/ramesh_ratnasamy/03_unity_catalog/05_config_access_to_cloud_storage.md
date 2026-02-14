# Accessing Cloud Storage with Unity Catalog

## Introduction

Welcome back. Now that we have created the Unity Catalog Metastore, let's take a look at how to **read and write data from cloud storage**.

### What We'll Cover:

In this lesson, we'll learn:
1. Why we don't use default Metastore storage
2. How to assign specific storage containers
3. Unity Catalog objects for storage access
4. Implementation approach and steps

---

## The Problem: Default Metastore Storage

### Why Not Use Default Storage?

**Recall from previous lesson:**
We chose NOT to assign a default storage for the entire Metastore.

**Why this decision?**

| Problem | Impact |
|---------|--------|
| **Single Container** | All Metastore data written to one location |
| **No Separation** | Data mixed across catalogs and schemas |
| **Hard to Maintain** | Difficult to manage and organize |
| **Poor Organization** | Becomes a data swamp |
| **Capacity Planning** | Can't track storage per catalog |
| **Access Control** | Difficult to implement granular permissions |

**⚠️ Result:**
Using default Metastore storage makes data harder to maintain and manage.

---

## The Solution: Specific Storage Assignment

### Better Approach ⭐

**Instead of default storage:**
Assign **specific storage containers** for each catalog or even schemas within catalogs.

### Benefits:

| Benefit | Description |
|---------|-------------|
| **Separation** | Each catalog/schema has dedicated storage |
| **Organization** | Data kept separate and organized |
| **Maintainability** | Easier to manage individual containers |
| **Access Control** | Granular permissions per catalog |
| **Capacity Planning** | Track storage usage per catalog |
| **Scalability** | Independent storage scaling |

### How to Implement:

To achieve this, we need to create **Unity Catalog objects**:
1. **Storage Credential**
2. **External Location**

---

## Unity Catalog Storage Objects

### Object 1: Storage Credential

#### What is a Storage Credential?

An **authentication and authorization mechanism** for accessing data stored in Azure storage on behalf of users.

#### Key Characteristics:

**Purpose:**
- Securely authenticate to Azure storage
- Authorize access to data
- On behalf of Databricks users

**Creation Methods:**

Can be created with:
1. **Managed Identity**
2. **Service Principal**

#### Understanding Azure Identity Concepts

**For those new to Azure:**

| Concept | Description |
|---------|-------------|
| **Managed Identity** | Azure-managed identity for resources |
| **Service Principal** | Application identity in Azure AD |

**What they do:**
- Mechanisms for authenticating Azure resources
- Authorize access securely
- **No manual credential management required**
- Credentials handled automatically by Azure

---

### Object 2: External Location

#### What is an External Location?

An object that **combines** a storage credential with a cloud storage container to gain access to specific containers.

#### How It Works:

**Formula:**
```
Storage Credential + Cloud Storage Container = External Location
```

**Components:**
1. **Storage Credential** - Authentication mechanism
2. **Container Path** - Specific ADLS Gen2 container
3. **External Location** - Combined access object

#### Flexibility and Organization

**Multiple External Locations:**
- ✅ Create as many as needed for catalogs
- ✅ One per catalog
- ✅ One per schema
- ✅ Multiple per catalog (different schemas)

**Subfolder Organization:**
Within a container that an external location refers to:
- ✅ Create subfolders
- ✅ Assign to different catalogs
- ✅ Assign to different schemas

**Example Structure:**
```
ADLS Gen2 Container: data-lake
  └── catalogs/
      ├── dev/
      │   ├── bronze/
      │   ├── silver/
      │   └── gold/
      ├── test/
      │   ├── bronze/
      │   ├── silver/
      │   └── gold/
      └── prod/
          ├── bronze/
          ├── silver/
          └── gold/
```

#### Benefits of Organization:

| Benefit | Description |
|---------|-------------|
| **Separation** | Data for each catalog/schema kept separate |
| **Organization** | Clear folder structure |
| **Access Control** | Granular permissions per folder |
| **Clarity** | Easy to understand data organization |

---

## Implementation Approach

### High-Level Architecture

Let's look at how to implement access to cloud storage using Unity Catalog objects.

---

## Azure Access Connector for Databricks

### What is Access Connector?

**Azure First-Party Service:**
- Specifically designed for Databricks
- Simplifies managed identity integration
- Connects managed identity to Databricks account

### Why Use Access Connector?

**Advantages:**

| Feature | Benefit |
|---------|---------|
| **First-party service** | Native Azure integration |
| **Simplified setup** | Easier than manual configuration |
| **Managed identity** | No credential management |
| **Secure** | Azure-managed authentication |
| **Recommended** | Best practice for Azure |

**⭐ Decision:**
We'll use Access Connector for this course because it's very simple to implement.

---

## Step-by-Step Implementation Flow

### Complete Architecture Diagram

```
┌─────────────────────────────────────────────────────────────┐
│                    Azure Subscription                       │
│                                                             │
│  ┌──────────────────────┐      ┌──────────────────────┐   │
│  │ Access Connector     │      │ ADLS Gen2 Storage    │   │
│  │ (Managed Identity)   │─────▶│ (Data Lake)          │   │
│  └──────────────────────┘      └──────────────────────┘   │
│           │                              ▲                  │
│           │ (Uses)                       │ (Accesses)       │
│           ▼                              │                  │
│  ┌──────────────────────┐               │                  │
│  │ Storage Credential   │───────────────┘                  │
│  │ (Unity Catalog)      │                                  │
│  └──────────────────────┘                                  │
│           │                                                 │
│           │ (Combined with)                                │
│           ▼                                                 │
│  ┌──────────────────────┐                                  │
│  │ External Location    │                                  │
│  │ (Unity Catalog)      │                                  │
│  └──────────────────────┘                                  │
│           │                                                 │
└───────────┼─────────────────────────────────────────────────┘
            │
            ▼
    ┌───────────────┐
    │     User      │
    │  References   │
    │   External    │
    │   Location    │
    └───────────────┘
```

---

## Detailed Implementation Steps

### Step 1: Create Access Connector

**What to Do:**
Create an Azure Access Connector for Databricks.

**Important Note:**
You may already have one in your subscription created by Databricks by default.

**Options:**

| Option | When to Use |
|--------|-------------|
| **Use existing** | Quick setup, shared resources |
| **Create new** | Better organization, dedicated for course |

**⭐ Our Approach:**
Create a **new one** just for this part of the course to keep it separate.

**Why Create New?**
- ✅ Better separation of concerns
- ✅ Easier to manage access separately
- ✅ Clean up easily after course
- ✅ Best practice for production environments

---

### Step 2: Create Azure Data Lake Storage Account

**What to Do:**
Create a new ADLS Gen2 storage account.

**Why Not Use Existing?**

**You may already have a data lake in your subscription:**
- Created by Databricks by default
- But Databricks manages access to that storage
- We won't have full control

**⚠️ Problem:**
- Databricks-managed storage account
- We don't have full access
- Limited control over permissions

**✅ Solution:**
Create a **new storage account** for which we'll have **full access**.

**Benefits of New Storage Account:**

| Benefit | Description |
|---------|-------------|
| **Full Control** | Complete access management |
| **Independent** | Not managed by Databricks |
| **Flexible** | Configure as needed |
| **Learning** | Better for understanding concepts |

---

### Step 3: Assign Role to Access Connector

**What to Do:**
Assign the **Storage Blob Data Contributor** role on the data lake to the access connector.

**Role Assignment:**
```
Access Connector → Storage Blob Data Contributor → ADLS Gen2
```

**What This Achieves:**
- ✅ Access Connector can access the data lake
- ✅ Read and write permissions
- ✅ Proper authorization established

**Role Details:**

| Role | Permissions |
|------|-------------|
| **Storage Blob Data Contributor** | Read, write, delete blobs |
| **Scope** | ADLS Gen2 storage account |
| **Assigned To** | Access Connector |

---

### Step 4: Create Storage Credential

**What to Do:**
Create the storage credential using the access connector information.

**How It Works:**
```
Storage Credential ─uses→ Access Connector ─accesses→ Data Lake
```

**Result:**
✅ Storage credential can now access the data lake via the access connector.

**What We've Accomplished:**
- Storage credential created
- Linked to Access Connector
- Access to data lake established
- ✅ **Storage Credential setup complete**

---

### Step 5: Create External Location

**What to Do:**
Create the external location object in Unity Catalog.

**Components Combined:**

| Component | Details |
|-----------|---------|
| **Storage Credential** | Created in Step 4 |
| **ADLS Container** | Specific container path |
| **External Location** | Combined object |

**Formula:**
```
External Location = Storage Credential + Container Path
```

**Example:**
```
Storage Credential: my_storage_credential
Container Path: abfss://data@mystorageaccount.dfs.core.windows.net/catalogs/dev
External Location: dev_external_location
```

---

### Step 6: Access Data

**How Users Access Data:**

When a user references the external location:

1. **User references External Location**
2. **Unity Catalog checks:**
   - Which storage credential to use
   - User permissions on external location
3. **Storage Credential authenticates via Access Connector**
4. **If successful:** Access granted
5. **If failed:** Request denied

**Authentication Flow:**
```
User Request
    ↓
External Location
    ↓
Unity Catalog checks permissions
    ↓
Storage Credential
    ↓
Access Connector
    ↓
ADLS Gen2
    ↓
Data Access (if authorized)
```

---

## Access Control

### Granular Permission Management

#### Where to Apply Access Control:

1. **Storage Credential Level**
2. **External Location Level**

#### How It Works:

**Storage Credential Permissions:**
- Control who can use the credential
- Administrators manage credential access

**External Location Permissions:**
- Control who can access the location
- Administrators manage location access

#### Security Layers:

```
User Access Request
    ↓
Check: User has permission to External Location?
    │
    ├─ No → ❌ Deny (No authentication attempted)
    │
    └─ Yes → Check: User has permission to Storage Credential?
              │
              ├─ No → ❌ Deny (No authentication attempted)
              │
              └─ Yes → ✅ Authenticate and grant access
```

#### Benefits of Dual-Level Control:

| Level | Benefit |
|-------|---------|
| **Storage Credential** | Centralized credential management |
| **External Location** | Fine-grained location access |
| **Combined** | Granular security control |

**Administrator Capabilities:**
- ✅ Manage access at granular level
- ✅ Control who can use credentials
- ✅ Control who can access locations
- ✅ Prevent unauthorized access
- ✅ No authentication attempts for unauthorized users

---

## Important Terminology Note

### The Word "External" in Databricks

**⚠️ Important Context:**

The keyword **"external"** has **slightly different meanings** in different places in Databricks.

#### In "External Location":

**Meaning:**
"External" simply refers to storage **other than** the default storage attached to the Metastore.

**NOT "External" as in:**
- ❌ Outside Databricks ecosystem
- ❌ Third-party storage
- ❌ Non-Azure storage

**IS "External" as in:**
- ✅ Not the default Metastore storage
- ✅ Additional storage locations
- ✅ Custom storage containers

#### In "External Tables":

**Meaning:**
Tables where data is managed outside Unity Catalog (data not deleted when table dropped).

#### Comparison:

| Context | "External" Means |
|---------|-----------------|
| **External Location** | Storage other than default Metastore storage |
| **External Table** | Data managed outside Unity Catalog |
| **External Volumes** | Storage managed outside Databricks |

**Key Point:**
Context matters—"external" has nuanced meanings depending on where it's used.

---

## Implementation Summary

### Complete Step-by-Step Process

Here's everything we need to carry out:

#### Phase 1: Azure Resources (Steps 1-3)

**Step 1: Create Access Connector**
```
Action: Create (or use existing) Access Connector
Tool: Azure Portal
Result: Managed Identity for Databricks
```

**Step 2: Create ADLS Gen2 Storage Account**
```
Action: Create new storage account
Tool: Azure Portal
Result: Dedicated data lake with full access
```

**Step 3: Assign Role**
```
Action: Assign "Storage Blob Data Contributor"
From: Access Connector
To: ADLS Gen2 Storage Account
Tool: Azure Portal (IAM)
Result: Access Connector can access data lake
```

#### Phase 2: Unity Catalog Objects (Steps 4-5)

**Step 4: Create Storage Credential**
```
Action: Create storage credential
Using: Access Connector information
Tool: Databricks Account Console / Workspace
Result: Credential can authenticate to storage
```

**Step 5: Create External Location**
```
Action: Create external location
Combining: Storage Credential + Container Path
Tool: Databricks Account Console / Workspace
Result: Complete access path established
```

#### Phase 3: Access and Permissions (Step 6)

**Step 6: Access Data & Manage Permissions**
```
Access: Via external location and storage credential
Permissions: Set on both credential and location
Result: Controlled, granular data access
```

---

### Visual Process Flow

```
1. Create Access Connector
   ↓
2. Create ADLS Gen2 Account
   ↓
3. Assign Role (Storage Blob Data Contributor)
   Access Connector → ADLS Gen2
   ↓
4. Create Storage Credential
   Uses: Access Connector
   ↓
5. Create External Location
   Combines: Credential + Container
   ↓
6. Users Access Data
   Via: External Location
   ↓
✅ Secure, Organized Data Access
```

---

## Access and Permissions

### Who Has Access?

**As Resource Creators:**

Since we're creating these resources ourselves:
- ✅ Full access to resources
- ✅ Owner permissions
- ✅ Can manage everything

**Our Access:**

| Resource | Access Level |
|----------|--------------|
| **Access Connector** | Owner/Creator |
| **Storage Account** | Owner/Creator |
| **Storage Credential** | Creator |
| **External Location** | Creator |

### Granting Access to Team

**Optional:**
If you want to grant access to the rest of the team, you can do that as well.

**How to Grant Access:**

1. **Storage Credential Level:**
   - Add users/groups to credential permissions
   - Grant "USE" permission

2. **External Location Level:**
   - Add users/groups to location permissions
   - Grant appropriate access levels

**Permission Levels:**

| Permission | Capability |
|------------|------------|
| **USE** | Can use the resource |
| **CREATE** | Can create objects in location |
| **READ** | Can read data |
| **WRITE** | Can write data |
| **ALL PRIVILEGES** | Full control |

---

## Key Concepts Recap

### Storage Credential

**Definition:**
Authentication/authorization mechanism for accessing Azure storage on behalf of users.

**Created With:**
- Managed Identity (via Access Connector)
- Or Service Principal

**Purpose:**
- Authenticate to cloud storage
- Authorize access
- Centralized credential management

### External Location

**Definition:**
Combination of storage credential and cloud storage container.

**Components:**
- Storage Credential (authentication)
- Container Path (location)

**Purpose:**
- Provide access to specific containers
- Enable organized storage
- Support granular access control

### Access Connector

**Definition:**
Azure first-party service for connecting managed identity to Databricks.

**Purpose:**
- Simplify managed identity setup
- Secure authentication
- No manual credential management

**Best Practice:**
✅ Use Access Connector for Azure deployments

---

## Benefits Summary

### Why This Approach?

| Benefit | Description |
|---------|-------------|
| **Organization** | Each catalog/schema has dedicated storage |
| **Security** | Granular access control at multiple levels |
| **Scalability** | Independent storage per catalog |
| **Maintainability** | Easy to manage separate containers |
| **Flexibility** | Create as many locations as needed |
| **Best Practice** | Follows Databricks recommendations |
| **Simplicity** | Access Connector simplifies setup |

### Comparison: Default vs. Dedicated Storage

| Aspect | Default Metastore Storage | Dedicated Storage (Our Approach) |
|--------|--------------------------|-----------------------------------|
| **Organization** | ❌ All mixed together | ✅ Separated by catalog/schema |
| **Maintenance** | ❌ Difficult | ✅ Easy |
| **Access Control** | ⚠️ Broad | ✅ Granular |
| **Scalability** | ⚠️ Limited | ✅ Flexible |
| **Capacity Planning** | ❌ Difficult | ✅ Easy per catalog |
| **Recommendation** | ❌ Not recommended | ⭐ Recommended |

---

## What's Next

### Upcoming Lesson:

In the next lesson, we'll **put this into practice**:

1. **Create Access Connector** in Azure Portal
2. **Create ADLS Gen2 Storage Account** in Azure Portal
3. **Assign IAM Role** to Access Connector
4. **Create Storage Credential** in Databricks
5. **Create External Location** in Databricks
6. **Test Data Access** through Unity Catalog

### You'll Learn:

- ✅ Hands-on Azure Portal navigation
- ✅ Step-by-step resource creation
- ✅ Unity Catalog object configuration
- ✅ Verification and testing procedures
- ✅ Troubleshooting common issues

---

## Summary

### Key Takeaways:

1. **Don't use default Metastore storage** - leads to poor organization

2. **Two Unity Catalog objects needed:**
   - Storage Credential (authentication)
   - External Location (credential + container)

3. **Use Access Connector** - simplifies managed identity integration

4. **Create dedicated storage accounts** - for full control and organization

5. **Granular access control** - at both credential and location levels

6. **"External" context matters** - different meanings in different contexts

7. **Six-step implementation process** - from Access Connector to data access

### What We've Covered:

- ✅ Problem with default storage
- ✅ Storage Credential concept
- ✅ External Location concept
- ✅ Access Connector benefits
- ✅ Implementation architecture
- ✅ Step-by-step process
- ✅ Access control mechanisms

### Ready for Implementation:

You now have a good understanding of:
- How to access external locations via Unity Catalog
- Why this approach is better than default storage
- The role of each component in the architecture
- The steps needed to implement secure storage access

**Next:** Hands-on implementation in Azure!

---

*End of lesson*