# Configuring Cloud Storage Access via Unity Catalog: Hands-On Lab

## Introduction

Welcome back. Now that we understand how to configure access to an Amazon S3 bucket via Unity Catalog, let's switch over to the AWS Console and try and **implement this solution**.

### What We'll Accomplish:

In this hands-on lesson, we'll:
1. Create IAM cross-account role for Databricks
2. Create Amazon S3 bucket
3. Attach IAM policy to cross-account role
4. Create Storage Credential in Unity Catalog
5. Create External Location
6. Test data access

---

## Step 1: Create IAM Cross-Account Role for Databricks

### Navigation in AWS Console

#### 1. Start Role Creation

1. Go to **AWS Console**
2. Navigate to **IAM** service
3. Click **"Roles"** in the left menu, then **"Create role"**

#### 2. Configure Cross-Account Role

1. Select **"AWS account"** as the trusted entity type
2. Choose **"Another AWS account"** and enter the Databricks account ID
3. Click **"Next"**

---

### Configure IAM Cross-Account Role

#### AWS Resource Tags / Organization

**Use consistent tagging:**
```
Tag: Project = d-org
```

**Why this choice?**
- Everything for this course tagged consistently
- Easier to manage and clean up
- Consistent organization

#### Naming Convention

**IAM Cross-Account Role Name:**
```
d-course-ext-role
```

**Naming Breakdown:**

| Component | Meaning | Example |
|-----------|---------|---------|
| `d-course` | Course identifier | d-course |
| `ext` | External storage | ext |
| `role` | IAM cross-account role | role |

**Why "ext"?**
- Represents **external storage**
- Not the default storage attached to Metastore
- Clear identification of purpose

#### Region Selection

**Region:**
```
eu-west-2
```

**Selection Criteria:**
- Select region closest to you
- Must match Databricks workspace region
- Must match S3 bucket region

#### Tags (Optional)

**Configuration:**
- Add tags if desired
- Optional for this course
- Click **"Next"**

---

### IAM Role Configuration

#### Review Trust Policy

**Screen: Trust Relationship**

**Configuration shown:**
```
Trust Policy: Allows Databricks AWS account to assume this role
```

**What This Means:**
- Configured to trust the Databricks AWS account
- Databricks can assume this role to access your resources
- AWS manages the role lifecycle
- No manual credential management

**Accept defaults and proceed.**

---

### Create IAM Cross-Account Role

#### Final Steps

1. Click **"Next"** through permissions (we'll attach policy later)
2. Review all settings
3. Click **"Create role"**

**Result:**
IAM cross-account role is now created

---

## Step 2: Create Amazon S3 Bucket

### Navigation in AWS Console

#### 1. Start Bucket Creation

1. Navigate to **S3** service
2. Click **"Create bucket"**

#### 2. Configure S3 Bucket

1. Enter bucket name
2. Select region
3. Click **"Create bucket"**

---

### Configure S3 Bucket

#### Basic Settings

##### AWS Resource Tags / Organization

**Use consistent tagging:**
```
Tag: Project = d-org
```

**Consistency:** Same tagging as other resources.

##### S3 Bucket Name

**Name:**
```
dcoursextdl
```

**Important Naming Rules:**
- Must be **globally unique**
- No uppercase allowed
- Must be between 3-63 characters
- Must start with a letter or number
- Can contain hyphens

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
eu-west-2
```

**Critical:** Must match IAM cross-account role region and workspace region.

##### Bucket Settings

**Selection:**
```
Object Ownership: ACLs disabled (recommended)
Block Public Access: Enabled
Versioning: Disabled
```

**Why these defaults?**
- Sufficient for development
- Cost-effective
- Meets our needs

---

### Create S3 Bucket

#### Final Steps

1. Review all settings
2. Click **"Create bucket"**

**Result:**
S3 bucket is now created

#### Navigate to Resource

After creation:
1. Click on the bucket name
2. View the bucket details

---

## Step 3: Attach IAM Policy to Cross-Account Role

### Current State

**What We Have:**
- S3 bucket created
- IAM cross-account role created

**What We Need:**
Give the IAM cross-account role an **IAM policy with S3 permissions (s3:GetObject, s3:PutObject, s3:DeleteObject, s3:ListBucket)** on the S3 bucket.

**Why?**
So the IAM cross-account role can access the S3 bucket.

---

### Attach Policy Procedure

#### 1. Navigate to IAM

**In AWS Console:**
1. Navigate to **IAM** service
2. Click **"Roles"** in left menu
3. Find and click on your role: `d-course-ext-role`

#### 2. Add Inline Policy

**Actions:**
1. Click **"Add permissions"**
2. Select **"Create inline policy"** from dropdown

---

### Define Policy

#### 1. Create Policy JSON

**In Policy Editor:**
```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "s3:GetObject",
        "s3:PutObject",
        "s3:DeleteObject",
        "s3:ListBucket"
      ],
      "Resource": [
        "arn:aws:s3:::dcoursextdl",
        "arn:aws:s3:::dcoursextdl/*"
      ]
    }
  ]
}
```

#### 2. Name and Create Policy

**From Results:**
- Name: **"d-course-ext-s3-policy"**
- This grants read, write, delete, and list permissions on the S3 bucket
- Click **"Create policy"**

---

### Verify Policy Attachment

#### Check Role Permissions

**In IAM Console:**
1. Navigate to **"Roles"**
2. Click on role: `d-course-ext-role`
3. Check the **"Permissions"** tab

**What You Should See:**

| Identity | Policy | Scope |
|----------|--------|-------|
| `d-course-ext-role` | IAM policy with S3 permissions (s3:GetObject, s3:PutObject, s3:DeleteObject, s3:ListBucket) | S3 Bucket (`dcoursextdl`) |

**Confirmation:**
IAM cross-account role has the correct policy
Step 3 complete!

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
IAM Cross-Account Role (AWS Resource)
    ↓ provides
IAM Role Permissions (AWS IAM)
```

**Explanation:**

A storage credential is:
1. A **Unity Catalog object**
2. That wraps an **IAM cross-account role**
3. Which provides **IAM role permissions**

**Result:**
Eventually, it's just an IAM role that's been wrapped:
- By the Unity Catalog Storage Credential object

#### Why Create Storage Credential?

**The Problem:**
- Unity Catalog only knows about **storage credentials**
- Unity Catalog doesn't know about **IAM roles**

**The Solution:**
- Wrap the IAM role into a storage credential
- Unity Catalog can then use this credential (like a user)
- Access the S3 bucket

#### Access Flow

**What We've Done:**
```
1. IAM Cross-Account Role → IAM policy with S3 permissions → S3 Bucket
2. IAM Cross-Account Role contains → IAM Role Permissions
3. IAM Role has → S3 access
```

**What We're Doing Now:**
```
4. Wrap IAM Cross-Account Role → Storage Credential
5. Storage Credential inherits → Same access (S3 permissions)
```

**Result:**
Storage Credential has S3 read/write/delete/list access to the S3 bucket

---

### Create Storage Credential

#### Existing Credentials

**Note:**
You might see a credential already created by default.

**Common Scenarios:**

| Situation | What You See |
|-----------|--------------|
| **New AWS account** | May have default credential |
| **Old AWS account** | May not have default credential |

**Don't worry if you don't see one -- it doesn't matter.**

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
Credential Type: IAM role
```

**Why?**
We're using an IAM cross-account role.

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

#### IAM Role ARN

**What's Needed:**
The **ARN** of the IAM cross-account role.

**Why?**
We're wrapping the IAM cross-account role into the Storage Credential.

---

### Get IAM Role ARN

#### Navigate to IAM Role

**In AWS Console:**

**Option 1: Search**
1. Navigate to **IAM** service
2. Click **"Roles"**
3. Search for and select your role: `d-course-ext-role`

**Option 2: Direct Navigation**
1. Go to IAM > Roles
2. Find: `d-course-ext-role`
3. Click to open

#### Find Role ARN

**Location: Summary Page (Top)**
```
ARN: arn:aws:iam::123456789012:role/d-course-ext-role
```

#### Copy Role ARN

**Action:**
1. Find the ARN at the top of the role summary
2. Copy it

**Format:**
```
arn:aws:iam::{account-id}:role/{role-name}
```

---

### Complete Storage Credential Creation

#### Paste IAM Role ARN

**Back in Catalog Explorer:**
1. Paste the copied ARN
2. Into **"IAM Role ARN"** field

#### Other Settings

**Comment (Optional):**
```
Add a comment if desired (optional)
```

#### Create Credential

**Final Step:**
Click **"Create"**

**Result:**
Storage Credential is now created

---

### Verify Storage Credential

#### View Credentials

**In Catalog Explorer:**
1. Click **"Credentials"** tab
2. View all credentials

**What You Should See:**

| Credential Name | Type | Status |
|----------------|------|--------|
| `d-course-ext-sc` | IAM Role | Active |
| (Default credential) | (if present) | Active |

**Confirmation:**
Newly created storage credential visible
Step 4 complete!

---

## Step 5: Create Prefix (Folder) in S3 Bucket

### Why Create a Prefix First?

Before creating the External Location, we need:
- A prefix (folder) in the S3 bucket to use as the target
- To test access before and after creating External Location

---

### Navigate to S3 Bucket

#### In AWS Console

1. Go to S3 bucket: `dcoursextdl`
2. Find the bucket contents

**Navigation:**

**Option 1: S3 Console**
- Navigate to **S3** service
- Click on the bucket name

**Option 2: Search**
- Search for the bucket in the S3 console

**Our Choice:** Navigate directly (more direct)

---

### Create Prefix

#### Prefix Creation

1. Click **"Create folder"**
2. Folder creation dialog opens

#### Folder Name

**Name:**
```
demo
```

**Settings:**
- Simple name for demo purposes
- Leave other settings as default

#### Create

Click **"Create folder"**

**Result:**
Folder named "demo" is created in the S3 bucket

---

### Current State

**What We Have:**

| Component | Value |
|-----------|-------|
| **S3 Bucket** | `dcoursextdl` |
| **Folder** | `demo` |
| **IAM Cross-Account Role** | `d-course-ext-role` (with IAM policy) |
| **Storage Credential** | `d-course-ext-sc` (wraps IAM role) |
| **External Location** | Not yet created |

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

### Test Bucket Access

#### Construct Bucket URL

**Format:**
```
s3://{bucket-name}/{path}
```

**Our Values:**

| Component | Value |
|-----------|-------|
| Protocol | `s3://` |
| Bucket | `dcoursextdl` |
| Path | `demo` |

**Complete URL:**
```
s3://dcoursextdl/demo/
```

---

#### List Bucket Contents

**Command:**
```python
%fs ls s3://dcoursextdl/demo/
```

**Breakdown:**

| Component | Purpose |
|-----------|---------|
| `%fs` | Databricks file system magic command |
| `ls` | List contents |
| `s3://...` | Amazon S3 URL |

#### Execute Command

**Action:**
1. Enter command in notebook cell
2. Execute cell

---

### Expected Error

**Error Message:**
```
Failure: Access denied or invalid credentials
```

**What This Means:**

| Aspect | Explanation |
|--------|-------------|
| **Error Type** | Configuration/Authentication error |
| **Cause** | No access to S3 bucket path |
| **Expected** | Yes, this is what we expect |
| **Solution** | Create External Location |

**Why This Happens:**
- No External Location created yet
- Unity Catalog can't access the bucket
- Authentication fails

**This is expected behavior!**

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
Could use UI (Catalog Explorer > Create External Location), but programmatic is better practice.

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
{bucket}_{path}
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
| `dl` | Data Lake (S3 bucket) |
| `demo` | Folder name |

**Why This Convention?**

| Benefit | Explanation |
|---------|-------------|
| **Clarity** | Obvious which S3 bucket |
| **No Clashes** | Unique names |
| **Easy Identification** | Can trace back to resources |
| **Standard** | Consistent across project |

---

#### Specify URL

**Use the URL we tested earlier:**
```sql
URL 's3://dcoursextdl/demo/'
```

**Component Breakdown:**
- Protocol: `s3://`
- Bucket: `dcoursextdl`
- Path: `demo/`

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
COMMENT 'External location for demo folder in d-course data lake'
```

---

### Complete SQL Command

**Full Command:**
```sql
CREATE EXTERNAL LOCATION IF NOT EXISTS d_course_ext_dl_demo
URL 's3://dcoursextdl/demo/'
WITH (STORAGE CREDENTIAL d_course_ext_sc)
COMMENT 'External location for demo folder in d-course data lake';
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

**External Location is now created!**

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
| `d_course_ext_dl_demo` | `s3://dcoursextdl/demo/` | `d_course_ext_sc` | Active |

**Confirmation:**
External Location visible in Catalog Explorer
Linked to correct credential
Points to correct bucket path

---

## Step 8: Test Access WITH External Location

### Retry Bucket Access

#### Same Command as Before

**Command:**
```python
%fs ls s3://dcoursextdl/demo/
```

**What's Different Now?**
- External Location created
- Storage Credential configured
- Access should work

---

### Execute Test

**Actions:**
1. Go back to the test cell in notebook
2. Re-execute the same command

**Expected Before:**
```
Error: Access denied or invalid credentials
```

**Expected After:**
```
Success: (empty list or "OK")
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
| `OK` | Command succeeded |
| `OK` (not file list) | Folder is empty (expected) |
| No error | Access is working |
| Authentication | Successful |

**Why Just "OK"?**
- Folder is empty
- We just created it
- No files to list
- Therefore returns "OK" instead of file list

---

### Success Confirmation

**What We've Proven:**

1. **Before External Location:**
   - Access failed
   - Authentication error

2. **After External Location:**
   - Access successful
   - Can list bucket contents
   - Authentication working

**We've successfully configured access to Amazon S3 via Unity Catalog!**

---

## Complete Architecture Review

### What We Built

```
┌─────────────────────────────────────────────────────────────┐
│                     AWS Account                              │
│                                                             │
│  ┌──────────────────────┐       ┌───────────────────────┐ │
│  │ IAM Cross-Account    │       │ Amazon S3 Bucket      │ │
│  │ Role                 │──────▶│ (dcoursextdl)         │ │
│  │ (d-course-ext-role)  │ Policy│                       │ │
│  │                      │       │ Folder: demo          │ │
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
│  │ URL: s3://dcoursextdl/demo/                     │───┘  │
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
| 1 | IAM Cross-Account Role | `d-course-ext-role` | IAM role for authentication |
| 2 | S3 Bucket | `dcoursextdl` | Amazon S3 data lake |
| 3 | Folder | `demo` | Storage folder |
| 4 | IAM Policy | IAM policy with S3 permissions (s3:GetObject, s3:PutObject, s3:DeleteObject, s3:ListBucket) | Grant access to IAM role |
| 5 | Storage Credential | `d-course-ext-sc` | Unity Catalog authentication |
| 6 | External Location | `d_course_ext_dl_demo` | Access path to bucket folder |

### Configuration Steps Completed

**Phase 1: AWS Resources (Steps 1-3)**
- [x] Created IAM cross-account role
- [x] Created Amazon S3 bucket
- [x] Attached IAM policy with S3 permissions to IAM cross-account role

**Phase 2: Unity Catalog Objects (Steps 4-6)**
- [x] Created Storage Credential wrapping IAM cross-account role
- [x] Created folder in S3 bucket
- [x] Created External Location combining credential and URL

**Phase 3: Testing (Step 7-8)**
- [x] Verified access fails without External Location
- [x] Created External Location programmatically
- [x] Verified access succeeds with External Location

---

## Key Commands Reference

### AWS Console Actions

| Action | Steps |
|--------|-------|
| **Create IAM Cross-Account Role** | IAM > Roles > Create role |
| **Create S3 Bucket** | S3 > Create bucket |
| **Attach IAM Policy** | IAM > Roles > Role > Add permissions > Create inline policy |
| **Create Folder** | S3 > Bucket > Create folder |

### Databricks Commands

**Test Access (Magic Command):**
```python
%fs ls s3://{bucket-name}/{path}/
```

**Create External Location (SQL):**
```sql
CREATE EXTERNAL LOCATION IF NOT EXISTS {location_name}
URL 's3://{bucket-name}/{path}/'
WITH (STORAGE CREDENTIAL {credential_name})
COMMENT '{description}';
```

---

## Naming Conventions Used

### Resource Naming Pattern

| Resource | Pattern | Example |
|----------|---------|---------|
| **IAM Cross-Account Role** | `{project}-ext-role` | `d-course-ext-role` |
| **S3 Bucket** | `{project}extdl` | `dcoursextdl` |
| **Storage Credential** | `{project}-ext-sc` | `d-course-ext-sc` |
| **External Location** | `{project}_ext_dl_{folder}` | `d_course_ext_dl_demo` |

**Key Components:**
- `{project}`: Course or project identifier
- `ext`: External (not default)
- `role`: IAM cross-account role
- `dl`: Data Lake
- `sc`: Storage Credential

---

## Troubleshooting Guide

### Common Issues and Solutions

| Issue | Cause | Solution |
|-------|-------|----------|
| **"Access denied" error** | No External Location | Create External Location |
| **Can't find IAM role** | Wrong account or search | Check IAM console and role name |
| **S3 bucket name taken** | Not globally unique | Add unique identifier |
| **IAM policy not working** | Wrong resource ARN | Verify bucket ARN in policy |
| **Role assumption fails** | Wrong trust policy | Verify Databricks account ID in trust policy |
| **External Location creation fails** | Wrong credential name | Verify Storage Credential name |

---

## Best Practices Demonstrated

### Good Practices We Followed

1. **Consistent Naming:**
   - Clear naming conventions
   - Easy to identify resources
   - No naming conflicts

2. **Resource Organization:**
   - Consistent tagging for related resources
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

6. **Least Privilege:**
   - IAM policy scoped to specific bucket
   - Only necessary S3 permissions granted

---

## What's Next

### You Can Now:

- Create IAM cross-account roles for authentication
- Set up Amazon S3 buckets for data lakes
- Attach IAM policies for access control
- Create Unity Catalog Storage Credentials
- Create External Locations programmatically
- Access cloud storage via Unity Catalog

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
1. IAM cross-account role
2. Amazon S3 bucket
3. IAM policy attachment for authorization
4. Unity Catalog Storage Credential
5. External Location for bucket access
6. Verified end-to-end access

**Key Learnings:**

| Concept | Understanding |
|---------|--------------|
| **IAM Cross-Account Role** | Provides IAM role for Databricks to access AWS resources |
| **Storage Credential** | Unity Catalog authentication object |
| **External Location** | Combines credential + URL for access |
| **S3 Bucket** | Cloud storage for data lake |
| **IAM Policies** | Control access to AWS resources |
| **Programmatic Creation** | Better than UI for repeatability |

### Critical Points:

1. **IAM trust policy must reference the correct Databricks account ID**
2. **S3 bucket names must be globally unique**
3. **IAM policy attachment is critical** for access
4. **External Location combines** credential and URL
5. **Test before and after** to verify configuration

### Result:

**We've successfully configured access to cloud storage via Unity Catalog from Databricks!**

---

## CONCEPT GAP: S3 Protocol and AWS Storage URL Formats

Understanding AWS storage URL formats is essential for certification exams and practical work.

### AWS Storage URL Formats

```
┌──────────────────────────────────────────────────────────────────┐
│                    AWS STORAGE URL FORMATS                        │
│                                                                  │
│  S3 Protocol -- RECOMMENDED                                      │
│  ══════════════════════════                                      │
│  s3://<bucket>/<path>                                            │
│                                                                  │
│  Example:                                                        │
│  s3://dcoursextdl/catalogs/dev/                                  │
│      ^^^^^^^^^^^  ^^^^^^^^^^^^^                                  │
│       bucket       path                                          │
│                                                                  │
│  - Uses HTTPS encryption by default                              │
│  - Recommended for all Databricks workloads                      │
│  - Works with Amazon S3                                          │
│                                                                  │
├──────────────────────────────────────────────────────────────────┤
│                                                                  │
│  S3A Protocol -- HADOOP COMPATIBLE                               │
│  ════════════════════════════════                                 │
│  s3a://<bucket>/<path>                                           │
│                                                                  │
│  - Hadoop-compatible S3 connector                                │
│  - Used by some open-source tools                                │
│  - s3:// preferred in Databricks                                 │
│                                                                  │
└──────────────────────────────────────────────────────────────────┘
```

### Protocol Comparison

| Protocol | Encryption | Storage Type | Recommended |
|----------|-----------|-------------|-------------|
| **s3** | HTTPS (secure) | Amazon S3 | Yes |
| **s3a** | HTTPS (secure) | Amazon S3 (Hadoop connector) | For Hadoop tools |

---

## CONCEPT GAP: S3 Bucket Configuration -- Why It Matters

Proper S3 bucket configuration is a critical but often misunderstood concept tested on exams.

### Flat Object Storage vs Structured Data Lake

```
S3 Default (Flat Object Storage):
══════════════════════════════════
  Flat namespace -- directories are simulated via key prefixes

  Stored as:
  /data/customers/part-00000.parquet  (single S3 object)
  /data/customers/part-00001.parquet  (single S3 object)
  /data/orders/part-00000.parquet     (single S3 object)

  "Rename /data/customers/" = copy ALL files + delete originals
  Performance: SLOW for directory operations
  ACLs: At bucket level or via IAM policies


S3 with Delta Lake / Databricks:
════════════════════════════════
  Transaction log provides structure on top of S3

  /data/
    ├── customers/          (prefix simulating directory)
    │   ├── part-00000.parquet
    │   └── part-00001.parquet
    └── orders/             (prefix simulating directory)
        └── part-00000.parquet

  Delta Lake provides ACID transactions on top of S3
  Performance: Optimized via Delta transaction log
  ACLs: Managed via Unity Catalog + IAM policies
```

### Key Differences

| Operation | Plain S3 (Flat) | S3 with Delta Lake |
|-----------|-------------------|------------------------|
| **Rename directory** | Copy all files + delete (O(n)) | Transaction log update |
| **Delete directory** | Delete each file individually | Transaction log update |
| **Access Control** | IAM policies only | Unity Catalog + IAM policies |
| **File-level ACLs** | Via IAM policies | Via Unity Catalog |
| **Atomic operations** | Limited | Full support via Delta |
| **Delta Lake performance** | Base performance | Optimized |
| **Unity Catalog support** | Supported | Required for best results |

---

## CONCEPT GAP: SQL Commands for Managing External Locations and Credentials

These SQL commands are frequently tested and used in practice.

```sql
-- ═══════════════════════════════════════════════
-- STORAGE CREDENTIAL MANAGEMENT
-- ═══════════════════════════════════════════════

-- Create storage credential (IAM Role)
CREATE STORAGE CREDENTIAL IF NOT EXISTS my_credential
WITH (
  AWS_IAM_ROLE_ARN = 'arn:aws:iam::123456789012:role/my-cross-account-role'
)
COMMENT 'Storage credential for production data lake';

-- List all storage credentials
SHOW STORAGE CREDENTIALS;

-- Describe a storage credential
DESCRIBE STORAGE CREDENTIAL my_credential;

-- Grant permission to use a storage credential
GRANT USE STORAGE CREDENTIAL ON STORAGE CREDENTIAL my_credential
TO `data-engineers@company.com`;

-- Drop storage credential
DROP STORAGE CREDENTIAL IF EXISTS my_credential;


-- ═══════════════════════════════════════════════
-- EXTERNAL LOCATION MANAGEMENT
-- ═══════════════════════════════════════════════

-- Create external location
CREATE EXTERNAL LOCATION IF NOT EXISTS my_location
URL 's3://bucket-name/path/'
WITH (STORAGE CREDENTIAL my_credential)
COMMENT 'External location for production data';

-- List all external locations
SHOW EXTERNAL LOCATIONS;

-- Describe an external location
DESCRIBE EXTERNAL LOCATION my_location;

-- Grant permissions on external location
GRANT CREATE EXTERNAL TABLE ON EXTERNAL LOCATION my_location
TO `data-engineers@company.com`;

GRANT READ FILES ON EXTERNAL LOCATION my_location
TO `data-analysts@company.com`;

-- Drop external location
DROP EXTERNAL LOCATION IF EXISTS my_location;


-- ═══════════════════════════════════════════════
-- TESTING AND VALIDATION
-- ═══════════════════════════════════════════════

-- Validate external location connectivity
VALIDATE EXTERNAL LOCATION my_location;

-- List files at an external location
LIST 's3://bucket-name/path/';
```

---

## CONCEPT GAP: IAM Cross-Account Role vs Instance Profile

This distinction appears on exams when discussing Databricks access configuration.

### Access Method Types

```
IAM CROSS-ACCOUNT ROLE:
═══════════════════════
  ┌─────────────────────────────────┐
  │   Databricks AWS Account        │
  │   ┌─────────────────────────┐   │
  │   │  Assumes Role           │   │
  │   │  (via trust policy)     │   │
  │   └─────────────────────────┘   │
  └─────────────┬───────────────────┘
                │ assumes
                ▼
  ┌─────────────────────────────────┐
  │   Your AWS Account              │
  │   ┌─────────────────────────┐   │
  │   │  IAM Role               │   │
  │   │  (with S3 policy)       │   │
  │   └─────────────────────────┘   │
  └─────────────────────────────────┘
  Recommended for Unity Catalog
  Fine-grained access control
  No credential rotation needed


INSTANCE PROFILE (Legacy):
══════════════════════════
  ┌─────────────────────────────────┐
  │  EC2 Instance (Databricks)      │
  │  ┌─────────────────────────┐   │
  │  │  Instance Profile        │   │
  │  │  (attached to cluster)   │   │
  │  └─────────────────────────┘   │
  └─────────────────────────────────┘
  Legacy approach
  Cluster-level access
  Less granular control
```

| Aspect | IAM Cross-Account Role | Instance Profile |
|--------|----------------------|------------------|
| **Scope** | Unity Catalog level | Cluster level |
| **Granularity** | Fine-grained per credential | All users on cluster |
| **Lifecycle** | Managed via IAM | Tied to cluster config |
| **Sharing** | Can share across workspaces | Per cluster |
| **Recommendation** | Preferred for Unity Catalog | Legacy, not recommended |
| **Our demo** | Used this | N/A |

---

## KEY INTERVIEW QUESTIONS AND ANSWERS

### Q1: Walk through the end-to-end process of configuring access to Amazon S3 from Databricks via Unity Catalog.
**A:** The process has six steps across two phases. AWS phase: (1) Create an IAM cross-account role that trusts the Databricks AWS account, (2) Create an Amazon S3 bucket, (3) Attach an IAM policy with S3 permissions (s3:GetObject, s3:PutObject, s3:DeleteObject, s3:ListBucket) to the cross-account role scoped to the S3 bucket. Unity Catalog phase: (4) Create a Storage Credential in Databricks that wraps the IAM cross-account role using its ARN, (5) Create a folder in the S3 bucket, then (6) Create an External Location combining the Storage Credential with the S3 URL. Users can then access data through the External Location with Unity Catalog managing permissions.

### Q2: How does Amazon S3 differ from a traditional hierarchical file system, and how does Delta Lake address this?
**A:** Amazon S3 is a flat object store where "directories" are simulated via key prefixes, not real directory objects. This means operations like renaming or deleting a "directory" require copying/deleting every object with that prefix (O(n) operations). Delta Lake addresses this by maintaining a transaction log on top of S3 that provides ACID transactions, atomic operations, and optimized metadata management. Unity Catalog then layers access control on top of this, providing fine-grained permissions without relying solely on IAM policies.

### Q3: What is the S3 protocol and why is it used in Databricks?
**A:** The S3 protocol uses the URL format `s3://<bucket>/<path>`. It is the recommended protocol for accessing Amazon S3 from Databricks because it uses HTTPS encryption for data in transit, is natively supported by Databricks, and integrates seamlessly with Unity Catalog's External Locations. An alternative is the s3a:// protocol used by Hadoop-based tools, but s3:// is preferred within Databricks.

### Q4: What is the purpose of the IAM cross-account role for Databricks and how does it relate to Storage Credentials?
**A:** The IAM cross-account role is an AWS IAM-based integration that allows Databricks (running in its own AWS account) to access resources in your AWS account. The role's trust policy allows the Databricks AWS account to assume the role, and attached IAM policies define what resources can be accessed. The Storage Credential then wraps the IAM cross-account role into a Unity Catalog object. So the hierarchy is: IAM Policy (AWS permissions) is attached to IAM Cross-Account Role (AWS resource) which is wrapped by Storage Credential (Unity Catalog object). This layered approach lets Unity Catalog use AWS-native authentication without managing secrets directly.

### Q5: Why do S3 bucket names have such restrictive naming rules?
**A:** S3 bucket names must be globally unique across all of AWS, between 3-63 characters, and contain only lowercase letters, numbers, and hyphens. They must start with a letter or number and cannot end with a hyphen. This is because the bucket name becomes part of the DNS name (e.g., `dcoursextdl.s3.amazonaws.com`), and DNS names have specific character restrictions. This is different from IAM roles which allow a wider range of characters in their names.

### Q6: How do you verify that an External Location is configured correctly?
**A:** There are multiple verification methods: (1) Use `%fs ls s3://bucket-name/path/` to list bucket contents -- success means configuration works, (2) Run `DESCRIBE EXTERNAL LOCATION location_name;` to see the configuration details, (3) Check in Catalog Explorer under External Data > External Locations to see the location and its linked credential, (4) Use `VALIDATE EXTERNAL LOCATION location_name;` to run a connectivity test. Before creating the External Location, the `%fs ls` command should fail with an authentication error; after creation, it should succeed.

### Q7: What is the difference between S3 bucket-level IAM policies and Unity Catalog access control, and why does this matter?
**A:** S3 bucket-level IAM policies operate at the AWS infrastructure level, controlling which AWS principals (users, roles) can perform S3 API operations (GetObject, PutObject, etc.) on the bucket. Unity Catalog access control operates at the Databricks level, controlling which Databricks users and groups can access specific tables, schemas, and catalogs stored in S3. For Unity Catalog, the IAM cross-account role needs S3 permissions (s3:GetObject, s3:PutObject, s3:DeleteObject, s3:ListBucket) because it needs to read and write actual data files. Unity Catalog then layers fine-grained access control on top, so individual users don't need direct IAM permissions.

### Q8: What should you do if you get an "Access denied" error when accessing S3 storage from Databricks?
**A:** This error indicates that there is no valid authentication path from Databricks to the S3 bucket. The most common causes are: (1) No External Location has been created for that storage path -- create one using `CREATE EXTERNAL LOCATION`, (2) The Storage Credential is not properly configured or does not wrap the correct IAM cross-account role, (3) The IAM cross-account role does not have the necessary S3 permissions on the bucket, (4) The trust policy on the IAM role does not allow the Databricks AWS account to assume it, (5) The External Location URL does not match the path being accessed. Verify each layer of the authentication chain: External Location, Storage Credential, IAM cross-account role, trust policy, and IAM policy.

---

*End of lesson*
