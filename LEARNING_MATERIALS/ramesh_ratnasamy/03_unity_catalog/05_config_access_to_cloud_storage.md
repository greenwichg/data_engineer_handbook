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

An **authentication and authorization mechanism** for accessing data stored in cloud storage (S3) on behalf of users.

#### Key Characteristics:

**Purpose:**
- Securely authenticate to S3
- Authorize access to data
- On behalf of Databricks users

**Creation Methods:**

Can be created with:
1. **IAM Role**
2. **IAM User with Access Keys**

#### Understanding AWS Identity Concepts

**For those new to AWS:**

| Concept | Description |
|---------|-------------|
| **IAM Role** | AWS-managed identity for resources |
| **IAM User with Access Keys** | Application identity in AWS IAM |

**What they do:**
- Mechanisms for authenticating AWS resources
- Authorize access securely
- **No manual credential management required** (with IAM roles)
- Credentials handled automatically by AWS (with IAM roles)

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
2. **Container Path** - Specific Amazon S3 bucket/path
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
S3 Bucket: data-lake
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

## IAM Cross-Account Role for Databricks

### What is an IAM Cross-Account Role?

**AWS IAM-Based Integration:**
- Specifically designed for Databricks
- Simplifies IAM role integration
- Connects IAM role to Databricks account

### Why Use an IAM Cross-Account Role?

**Advantages:**

| Feature | Benefit |
|---------|---------|
| **IAM-based integration** | Native AWS integration |
| **Simplified setup** | Easier than manual configuration |
| **IAM role** | No credential management |
| **Secure** | AWS-managed authentication |
| **Recommended** | Best practice for AWS |

**⭐ Decision:**
We'll use an IAM cross-account role for this course because it's very simple to implement.

---

## Step-by-Step Implementation Flow

### Complete Architecture Diagram

```
┌─────────────────────────────────────────────────────────────┐
│                      AWS Account                            │
│                                                             │
│  ┌──────────────────────┐      ┌──────────────────────┐   │
│  │ IAM Cross-Account    │      │ Amazon S3 Storage    │   │
│  │ Role                 │─────▶│ (Data Lake)          │   │
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

### Step 1: Create IAM Cross-Account Role

**What to Do:**
Create an IAM cross-account role for Databricks.

**Important Note:**
You may already have one in your AWS account created by Databricks by default.

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

### Step 2: Create Amazon S3 Bucket

**What to Do:**
Create a new Amazon S3 bucket.

**Why Not Use Existing?**

**You may already have a data lake in your AWS account:**
- Created by Databricks by default
- But Databricks manages access to that storage
- We won't have full control

**⚠️ Problem:**
- Databricks-managed S3 bucket
- We don't have full access
- Limited control over permissions

**✅ Solution:**
Create a **new S3 bucket** for which we'll have **full access**.

**Benefits of New S3 Bucket:**

| Benefit | Description |
|---------|-------------|
| **Full Control** | Complete access management |
| **Independent** | Not managed by Databricks |
| **Flexible** | Configure as needed |
| **Learning** | Better for understanding concepts |

---

### Step 3: Attach IAM Policy to Cross-Account Role

**What to Do:**
Attach an **IAM policy with s3:GetObject, s3:PutObject, s3:DeleteObject** permissions on the data lake to the cross-account role.

**Policy Assignment:**
```
IAM Cross-Account Role → IAM Policy (s3:GetObject, s3:PutObject, s3:DeleteObject) → S3 Bucket
```

**What This Achieves:**
- ✅ IAM cross-account role can access the data lake
- ✅ Read and write permissions
- ✅ Proper authorization established

**Policy Details:**

| Policy | Permissions |
|--------|-------------|
| **S3 bucket policy permissions** | s3:GetObject, s3:PutObject, s3:DeleteObject |
| **Scope** | Amazon S3 bucket |
| **Assigned To** | IAM cross-account role |

---

### Step 4: Create Storage Credential

**What to Do:**
Create the storage credential using the IAM cross-account role information.

**How It Works:**
```
Storage Credential ─uses→ IAM Cross-Account Role ─accesses→ Data Lake
```

**Result:**
✅ Storage credential can now access the data lake via the IAM cross-account role.

**What We've Accomplished:**
- Storage credential created
- Linked to IAM cross-account role
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
| **S3 Bucket Path** | Specific bucket/prefix path |
| **External Location** | Combined object |

**Formula:**
```
External Location = Storage Credential + Container Path
```

**Example:**
```
Storage Credential: my_storage_credential
Bucket Path: s3://data-lake/catalogs/dev
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
3. **Storage Credential authenticates via IAM cross-account role**
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
IAM Cross-Account Role
    ↓
Amazon S3
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
- ❌ Non-AWS storage

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

#### Phase 1: AWS Resources (Steps 1-3)

**Step 1: Create IAM Cross-Account Role**
```
Action: Create (or use existing) IAM cross-account role
Tool: AWS Console
Result: IAM role for Databricks
```

**Step 2: Create Amazon S3 Bucket**
```
Action: Create new S3 bucket
Tool: AWS Console
Result: Dedicated data lake with full access
```

**Step 3: Attach IAM Policy**
```
Action: Attach IAM policy with s3:GetObject, s3:PutObject, s3:DeleteObject
From: IAM cross-account role
To: Amazon S3 Bucket
Tool: AWS Console (IAM)
Result: IAM cross-account role can access data lake
```

#### Phase 2: Unity Catalog Objects (Steps 4-5)

**Step 4: Create Storage Credential**
```
Action: Create storage credential
Using: IAM cross-account role information
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
1. Create IAM Cross-Account Role
   ↓
2. Create Amazon S3 Bucket
   ↓
3. Attach IAM Policy (s3:GetObject, s3:PutObject, s3:DeleteObject)
   IAM Cross-Account Role → S3 Bucket
   ↓
4. Create Storage Credential
   Uses: IAM Cross-Account Role
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
| **IAM Cross-Account Role** | Owner/Creator |
| **S3 Bucket** | Owner/Creator |
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
Authentication/authorization mechanism for accessing S3 on behalf of users.

**Created With:**
- IAM Role (via IAM cross-account role)
- Or IAM User with Access Keys

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

### IAM Cross-Account Role

**Definition:**
AWS IAM-based integration for connecting an IAM role to Databricks.

**Purpose:**
- Simplify IAM role setup
- Secure authentication
- No manual credential management

**Best Practice:**
✅ Use IAM cross-account role for AWS deployments

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
| **Simplicity** | IAM cross-account role simplifies setup |

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

1. **Create IAM Cross-Account Role** in AWS Console
2. **Create Amazon S3 Bucket** in AWS Console
3. **Attach IAM Policy** to cross-account role
4. **Create Storage Credential** in Databricks
5. **Create External Location** in Databricks
6. **Test Data Access** through Unity Catalog

### You'll Learn:

- ✅ Hands-on AWS Console navigation
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

3. **Use IAM cross-account role** - simplifies IAM role integration

4. **Create dedicated storage accounts** - for full control and organization

5. **Granular access control** - at both credential and location levels

6. **"External" context matters** - different meanings in different contexts

7. **Six-step implementation process** - from IAM cross-account role to data access

### What We've Covered:

- ✅ Problem with default storage
- ✅ Storage Credential concept
- ✅ External Location concept
- ✅ IAM cross-account role benefits
- ✅ Implementation architecture
- ✅ Step-by-step process
- ✅ Access control mechanisms

### Ready for Implementation:

You now have a good understanding of:
- How to access external locations via Unity Catalog
- Why this approach is better than default storage
- The role of each component in the architecture
- The steps needed to implement secure storage access

**Next:** Hands-on implementation in AWS!

---

## CONCEPT GAP: Storage Credential Types -- IAM Role vs IAM User with Access Keys

Certification exams often test the differences between these two authentication methods. Understanding when to use each is critical.

### IAM Role vs IAM User with Access Keys Comparison

```
IAM ROLE:
═════════
  ┌──────────────────────────────┐
  │   AWS Resource               │
  │   (Cross-Account Role)       │
  │                              │
  │   Identity: Auto-managed     │
  │   Credentials: None to       │
  │                manage!       │
  │   Rotation: Automatic        │
  │   Lifecycle: Tied to         │
  │              resource        │
  └──────────────────────────────┘
  Best for: AWS-native workloads
  Recommended by Databricks


IAM USER WITH ACCESS KEYS:
══════════════════════════
  ┌──────────────────────────────┐
  │   AWS IAM User               │
  │                              │
  │   Access Key ID: AKIA...     │
  │   Secret Access Key: ***     │
  │   Account ID: 123456789...   │
  │                              │
  │   Credentials: Must manage   │
  │   Rotation: Manual           │
  │   Lifecycle: Independent     │
  └──────────────────────────────┘
  Best for: Cross-account, multi-cloud
  More configuration required
```

### Detailed Comparison Table

| Aspect | IAM Role | IAM User with Access Keys |
|--------|----------|---------------------------|
| **Credential management** | Automatic (AWS manages) | Manual (you manage access keys) |
| **Secret rotation** | Automatic, transparent | Manual, must track expiry |
| **Setup complexity** | Simple (via cross-account role) | More steps (user creation, key generation) |
| **Cross-account access** | Supported (via trust policies) | Supported |
| **Multi-cloud support** | AWS only | Can work across clouds |
| **Security risk** | Lower (no secrets to leak) | Higher (access keys can be exposed) |
| **Databricks recommendation** | Preferred for AWS | Use when IAM role insufficient |
| **Types** | Service role, Cross-account role | N/A |

---

## CONCEPT GAP: External Location Scope and Overlap Rules

Unity Catalog enforces strict rules about external location paths that are important for exams.

### External Location Overlap Rules

```
RULE: External locations CANNOT overlap in path hierarchy

VALID Configuration:
  ┌────────────────────────────────────────────┐
  │  External Location A:                      │
  │  s3://bucket-1/                            │
  └────────────────────────────────────────────┘
  ┌────────────────────────────────────────────┐
  │  External Location B:                      │
  │  s3://bucket-2/                            │
  └────────────────────────────────────────────┘
  Different buckets = no overlap = VALID


INVALID Configuration:
  ┌────────────────────────────────────────────┐
  │  External Location A:                      │
  │  s3://data-lake/catalogs/                  │
  └────────────────────────────────────────────┘
  ┌────────────────────────────────────────────┐
  │  External Location B:                      │
  │  s3://data-lake/catalogs/dev/              │
  └────────────────────────────────────────────┘
  B is a subpath of A = overlap = INVALID


VALID Alternative:
  ┌────────────────────────────────────────────┐
  │  External Location A:                      │
  │  s3://data-lake/catalogs/dev/              │
  └────────────────────────────────────────────┘
  ┌────────────────────────────────────────────┐
  │  External Location B:                      │
  │  s3://data-lake/catalogs/prd/              │
  └────────────────────────────────────────────┘
  Sibling paths (no parent-child) = VALID
```

---

## CONCEPT GAP: AWS IAM Policies for Data Lake Access

Understanding which AWS IAM policies are relevant is important for both the implementation and exam questions.

### AWS IAM Policy Actions for S3

| Policy / Actions | s3:GetObject | s3:PutObject | s3:DeleteObject | s3:CreateBucket / s3:DeleteBucket | Use Case |
|------------------|-------------|-------------|----------------|----------------------------------|----------|
| **Read-only policy** | Yes | No | No | No | Read-only access |
| **Read/write policy (recommended)** | Yes | Yes | Yes | No | Read/write access (recommended) |
| **Full control policy** | Yes | Yes | Yes | Yes | Full control including bucket management |
| **s3:ListBucket only** | No (listing only) | No | No | No | List buckets only |
| **Administrative policy** | No (management only) | No | No | Yes | Manage buckets, not data |

### Important Distinction

```
┌──────────────────────────────────────────────────────────────┐
│  COMMON EXAM TRAP:                                           │
│                                                              │
│  Administrative IAM policy =/= Data access IAM policy        │
│                                                              │
│  Administrative policy:                                      │
│    - AWS management plane policy                             │
│    - Can manage the S3 BUCKET (create, delete, etc.)         │
│    - CANNOT read or write object DATA                        │
│                                                              │
│  Data access policy (s3:GetObject, s3:PutObject, etc.):     │
│    - AWS data plane policy                                   │
│    - Can read, write, and delete object DATA                 │
│    - Cannot manage the S3 bucket itself                      │
│                                                              │
│  For Unity Catalog: Use data access IAM policy               │
│  (s3:GetObject, s3:PutObject, s3:DeleteObject)               │
└──────────────────────────────────────────────────────────────┘
```

---

## CONCEPT GAP: Managed Tables Storage Location

When you create managed tables in Unity Catalog, the storage location depends on how storage is configured at each level of the hierarchy.

### Storage Resolution Order

```
When creating a managed table in catalog.schema.table:

  1. Does the SCHEMA have a managed storage location?
     ├── YES ──▶ Store data in schema's storage location
     └── NO  ──▶ Continue to step 2

  2. Does the CATALOG have a managed storage location?
     ├── YES ──▶ Store data in catalog's storage location
     └── NO  ──▶ Continue to step 3

  3. Does the METASTORE have a default storage location?
     ├── YES ──▶ Store data in metastore's default storage
     └── NO  ──▶ ERROR: No storage location available
                  (Cannot create managed tables)
```

### Practical Example

```sql
-- Create catalog with dedicated storage
CREATE CATALOG dev_catalog
MANAGED LOCATION 's3://dev-bucket/';

-- Create schema within catalog (inherits catalog storage)
CREATE SCHEMA dev_catalog.bronze;
-- Managed tables here stored at: s3://dev-bucket/bronze/

-- Create schema with its own storage (overrides catalog)
CREATE SCHEMA dev_catalog.sensitive
MANAGED LOCATION 's3://sensitive-bucket/';
-- Managed tables here stored at: s3://sensitive-bucket/
```

---

## CONCEPT GAP: The "External" Keyword Context Matrix

This is a common source of confusion in exams. The word "external" is used in multiple contexts with different meanings.

| Term | Meaning | Data Ownership | Drop Behavior |
|------|---------|---------------|---------------|
| **External Location** | A UC object pointing to storage outside default metastore storage | N/A (it is a pointer) | Removes pointer, storage unaffected |
| **External Table** | A table whose data files are NOT managed by UC | Data owned outside UC | Metadata removed, data files persist |
| **External Volume** | A volume referencing files NOT managed by UC | Files owned outside UC | Volume removed, files persist |
| **External Data** | Menu in Catalog Explorer for managing credentials and locations | N/A (UI term) | N/A |

---

## KEY INTERVIEW QUESTIONS AND ANSWERS

### Q1: What is the relationship between a Storage Credential and an External Location in Unity Catalog?
**A:** A Storage Credential is an authentication/authorization mechanism that wraps AWS credentials (IAM role or IAM user with access keys) to access cloud storage. An External Location combines a Storage Credential with a specific cloud storage path (S3 bucket URL) to provide access to a particular location. You need both: the Storage Credential handles "how to authenticate" while the External Location defines "where to access." Multiple External Locations can share the same Storage Credential if they need to access different paths in the same S3 bucket.

### Q2: Why does Databricks recommend using an IAM cross-account role rather than an IAM user with access keys?
**A:** An IAM cross-account role is recommended because: (1) credentials are automatically managed by AWS with no secrets to rotate or expire, (2) there is no risk of credential leakage since no access keys exist, (3) setup is simpler with fewer configuration steps, (4) the IAM cross-account role is an AWS IAM-based integration specifically designed for Databricks integration, and (5) the identity lifecycle is tied to the AWS resource. IAM users with access keys require manual key management, have expiration dates, and introduce security risks if keys are exposed. Use IAM users with access keys only when cross-account access or multi-cloud scenarios are needed.

### Q3: Explain the dual-level access control for cloud storage in Unity Catalog.
**A:** Unity Catalog implements access control at two levels for cloud storage: (1) At the Storage Credential level, administrators control who can use the authentication mechanism, and (2) at the External Location level, administrators control who can access specific storage paths. When a user requests data access, Unity Catalog first checks if the user has permission on the External Location, then checks the Storage Credential permission. If either check fails, the request is denied without even attempting authentication to the cloud storage. This provides defense in depth and granular permission management.

### Q4: What IAM policy permissions are needed for Unity Catalog to access S3, and why?
**A:** An IAM policy with s3:GetObject, s3:PutObject, and s3:DeleteObject is the data plane policy that grants read, write, and delete permissions on objects within Amazon S3. It is attached to the IAM cross-account role on the S3 bucket so that Unity Catalog can read from and write to the data lake. It is important to distinguish this from administrative IAM policies, which are management plane policies that can manage the S3 bucket resource itself but cannot read or write actual object data. For Unity Catalog, the data plane policy is what is needed.

### Q5: Why should you create a separate S3 bucket instead of using the one Databricks creates by default?
**A:** The S3 bucket created by Databricks by default is managed by Databricks for internal purposes (DBFS root storage). You do not have full control over its access management, and Databricks may change configurations. Creating a separate S3 bucket gives you full ownership and control over permissions, the ability to configure it according to your organization's security policies, independence from Databricks-managed infrastructure, and better organization for production workloads. This aligns with the principle of separation of concerns and ensures that your data lake is not coupled to Databricks' internal storage management.

### Q6: How does the storage resolution hierarchy work for managed tables in Unity Catalog?
**A:** When a managed table is created, Unity Catalog resolves the storage location by checking three levels in order: (1) the schema's MANAGED LOCATION if one was specified, (2) the catalog's MANAGED LOCATION if set, (3) the metastore's default storage location. The first match is used. If none of these have a storage location configured, managed tables cannot be created and you must use external tables instead. This hierarchy allows flexible storage organization where different schemas or catalogs can have their own dedicated storage locations.

### Q7: What does the term "external" mean in different Unity Catalog contexts?
**A:** "External" has different meanings depending on context: (1) External Location refers to a storage path that is not the default metastore storage -- it can still be within your AWS account; (2) External Table means a table whose data files are not managed by Unity Catalog -- dropping the table keeps the data; (3) External Volume means a volume referencing files managed outside Databricks. The common thread is that "external" indicates something not fully lifecycle-managed by Unity Catalog, but it does NOT necessarily mean outside your organization or cloud environment.

### Q8: Walk through the complete authentication flow when a user queries data via an External Location.
**A:** The flow is: (1) User submits a query referencing a table at an External Location, (2) Unity Catalog checks if the user has permission on the External Location -- if not, access is denied immediately, (3) Unity Catalog identifies the associated Storage Credential and checks if the user has permission to use it -- if not, access is denied, (4) The Storage Credential uses its wrapped IAM cross-account role to authenticate to Amazon S3, (5) AWS checks that the IAM role has the required IAM policy (s3:GetObject, s3:PutObject, s3:DeleteObject) on the S3 bucket, (6) If all checks pass, data is retrieved and returned to the user. This multi-layer approach ensures both UC-level and AWS-level authorization.

---

*End of lesson*