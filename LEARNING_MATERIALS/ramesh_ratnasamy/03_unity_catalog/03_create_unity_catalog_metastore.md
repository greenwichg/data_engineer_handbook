# Configuring Unity Catalog Metastore

## Introduction

Welcome back. Now that we have had an introduction to Unity Catalog, let's take a look at configuring a **Metastore** for our Databricks workspace that we created earlier.

### What We'll Cover:

In this lesson, we'll:
1. Check if your workspace already has a Metastore
2. Access the Databricks Account Console
3. Create a new Metastore (if needed)
4. Assign workspace to Metastore
5. Configure admin permissions

---

## Understanding Metastore Configuration

### Key Concepts Recap:

**Metastore:**
- Top-level container within Unity Catalog Object Model
- **One Metastore per cloud region** (AWS region in this case)
- Can attach all workspaces in that region to this Metastore

**For This Course:**
- We'll create one Metastore
- We have one workspace
- We'll attach the workspace to the Metastore

---

## Prerequisites and Important Information

### Where to Create Metastore

**Warning:**
- Metastore **cannot** be created from Databricks workspace
- Must be created from **Databricks Account Console**

### Access Requirements

**URL for AWS Databricks Account Console:**
```
https://accounts.cloud.databricks.com
```

**Required Privileges:**
- User with **Account admin** privileges in Databricks

### Common Issue with New Accounts

**Problem:**
If you're using a new **AWS account**, you may need to set up your first account admin user in the Databricks Account Console.

**Solution:**
We'll create a new admin user with the required privileges to access the Databricks Account Console.

---

## Automatic Metastore Creation

### Important Notice

**Some Users May Already Have a Metastore:**

Starting **November 2023**, Databricks automatically creates a Unity Catalog Metastore for all new AWS accounts.

### When You Already Have a Metastore:

| Account Created | Metastore Status | Action Required |
|---------------------|------------------|-----------------|
| **On or after November 2023** | Automatically created | No action needed |
| **Before November 2023** | Not created | Follow this lesson |

**If you already have a Metastore:**
- Workspace already attached
- You don't need to follow the steps in this lesson
- We'll show you how to check this

---

## Step 1: Check if Workspace Has a Metastore

### Method 1: Using SQL Command (Easiest)

#### Create a Notebook

1. Navigate to your workspace
2. Create a new folder for this section
3. Create a new notebook

#### Run the Check Command

```sql
SELECT current_metastore();
```

#### Possible Outcomes:

##### Workspace Attached to Metastore

**Result:**
- Returns the Metastore name
- Example: `metastore-aws-us-east-1`

**What This Means:**
- Your workspace is already attached
- No further action needed
- You can skip the remaining steps

##### Workspace NOT Attached to Metastore

**Error Message:**
```
Operation current_metastore requires Unity Catalog enabled
```

**What This Means:**
- Your workspace is not attached to a Metastore
- You need to follow the remaining steps
- Continue with this lesson

---

### Method 2: Using Databricks Account Console

1. Navigate to Databricks Account Console
2. View Metastores
3. Check workspace assignments

**Note:** We'll cover this method in detail in the next section.

---

## Step 2: Accessing the Databricks Account Console

### Navigate to Account Console

**URL:**
```
https://accounts.cloud.databricks.com
```

1. Open browser
2. Navigate to the URL above
3. Click **"Continue"**
4. Sign in with your email address

### Expected Issue with New Accounts

**Error:**
If using a newly created account, you may need to complete initial account setup first.

**Why?**
The user may not yet be provisioned as an account admin in the Databricks Account Console.

---

## Step 3: Understanding Databricks Account Users

### Navigate to User Management

1. Go to **Databricks Account Console**
2. Click on **"User management"** in the left menu
3. Click on **"Users"** tab

### View Users

1. Under **"Users"** tab, review existing users
2. Review existing users

### Understanding the User Issue

**What You'll See:**

| User Type | Email Format | Example |
|-----------|-------------|---------|
| **Account Owner** | `email@domain.com` | `admin@company.com` |
| **Added User** | `email@domain.com` | `user@company.com` |

**Account Owner Characteristics:**
- The user who first set up the Databricks account
- Automatically becomes an account admin
- Can manage other users and roles

---

## Step 4: Creating a Databricks Admin User

### Why Create a New User?

**Reasons:**
- Better practice than using a shared account
- Dedicated for Databricks admin work
- Cleaner management
- Proper permissions setup

### Create New User Procedure

#### 1. Start User Creation

In Databricks Account Console -> User management -> Users:
1. Click **"Add User"**
2. Enter the user's email address

#### 2. Configure User Details

**Email:**
```
db-admin@company.com
```

**Display Name:**
```
Databricks Admin
```

#### 3. Set Initial Access

**Options:**
- The user will receive an invitation email
- They will set their own password on first login

**Setup:**
1. Enter the user's email address
2. Enter first and last name
3. Click **"Send invite"** or **"Add"**

#### 4. Create User

1. Click **"Add"**
2. User is now created

#### 5. Verify User Creation

1. Refresh the Users page
2. Locate the new user: `db-admin@company.com`
3. **Copy the username** (you'll need it to log in)

---

## Step 5: Assigning Administrator Privileges

### Why Account Admin?

**Requirement:**
User must be a **Databricks account admin** to access the Account Console and create Metastores.

**How to Achieve:**
Assign **Account admin** role in the Databricks Account Console.

### Assign Role Procedure

#### 1. Navigate to User

1. Click on the **`db-admin`** user
2. Go to **"Roles"** tab

#### 2. Check Current Roles

**Initial State:**
- No admin roles assigned

#### 3. Add Administrator Role

1. Toggle **"Account admin"** role to enabled
2. The role is assigned immediately

#### 4. Verify Assignment

**Result:**
- User now has Account admin privileges
- Ready to access Databricks Account Console

---

## Step 6: Logging into Account Console with New User

### Login Procedure

#### 1. Navigate to Account Console

**URL:**
```
https://accounts.cloud.databricks.com
```

#### 2. Use New User

1. Click **"Use another account"** (if needed)
2. Enter username: `db-admin@company.com`
3. Click **"Next"**

#### 3. Enter Password

1. Enter the password you created
2. Click **"Sign in"**

#### 4. Reset Password

**Prompt:**
You may be asked to set a password on first login (if invited via email).

**Actions:**
1. Enter new password
2. Confirm new password
3. Click **"Sign in"**

#### 5. Multi-Factor Authentication (Optional)

**Prompt:**
May be asked to set up MFA.

**Options:**
- Set up now
- Click **"Ask later"** to skip for now

#### 6. Successful Login

**Result:**
You're now logged into the **Databricks Account Console**

---

## Step 7: Exploring the Account Console

### Change Theme (Optional)

**For Better Visibility:**
1. Click on settings/preferences
2. Change to **lighter theme** (or your preference)

### View Workspaces

#### Navigate to Workspaces

1. Click **"Workspaces"** in the left menu
2. View all workspaces in this Databricks account

#### Workspace Information

**What You'll See:**

| Column | Information |
|--------|-------------|
| **Name** | Workspace name (e.g., `dws`) |
| **Region** | AWS region (e.g., `us-east-1`) |
| **Metastore** | Attached Metastore (if any) |
| **Status** | Active, Inactive |

**Example:**
```
Workspace: dws
Region: us-east-1
Metastore: metastore-aws-us-east-1 <- Attached
```

---

### View Metastores

#### Navigate to Catalog

1. Click **"Catalog"** in the left menu
2. View all Metastores in the account

#### Metastore Information

**What You'll See:**
- All Metastores (one per region)
- Metastore details
- Assigned workspaces

**Example Scenario:**
- One Metastore in us-east-1 region
- Could have multiple Metastores if working on multiple regions

#### View Metastore Details

1. Click on a **Metastore name**
2. Navigate to **"Workspaces"** tab
3. See all workspaces attached to this Metastore

---

## Step 8: Creating a New Metastore

### When to Create a Metastore

**Create a new Metastore if:**
- Your workspace is not attached to a Metastore
- No Metastore exists for your region
- You need to set up Unity Catalog

**Skip this step if:**
- Account created after November 2023
- Metastore already exists and workspace is attached

### Example Scenario

**Situation:**
- Have a workspace in **us-west-2** region
- Workspace name: `d-course-dws`
- **Not attached** to any Metastore
- Need to create Metastore and attach workspace

---

### Create Metastore Procedure

#### 1. Navigate to Create Metastore

1. Go to **"Catalog"** in Account Console
2. Click **"Create Metastore"** (top right)

#### 2. Configure Metastore Settings

##### Metastore Name

**Naming Convention:**
```
metastore-aws-<region>
```

**Example:**
```
metastore-aws-us-west-2
```

**Best Practice:**
- Use descriptive names
- Include cloud provider (AWS)
- Include region
- Use lowercase and hyphens

##### Select Region

**Critical Requirement:**
Metastore and workspace **must exist in the same region**.

**Example:**
- Workspace in: **us-west-2**
- Metastore in: **us-west-2** <- Must match

**Selection:**
1. Click region dropdown
2. Select **"us-west-2"** (or your workspace region)

##### S3 Path (Default Storage)

**What is this?**
Default storage location for the Metastore.

**Databricks Recommendation: Leave Blank**

**Why NOT Set Default Storage?**

| Issue | Explanation |
|-------|-------------|
| **Dumping Ground Risk** | All catalogs write to same location |
| **No Separation** | Data mixed across catalogs |
| **Difficult Planning** | Can't track storage per catalog |
| **Capacity Issues** | Can't efficiently plan capacity |
| **Becomes Data Swamp** | Unorganized data storage |

**Better Approach:**
- Strict separation of storage across catalogs
- Separate storage for different environments
- Data separated based on catalogs
- Efficient capacity planning
- Track storage usage per catalog

**Our Selection:**
- Leave **S3 Path** blank
- Leave **IAM cross-account role** ARN blank (not needed without default storage)

**Databricks Recommendation Shown:**
You'll see Databricks' recommendation to leave this blank in the UI.

#### 3. Create the Metastore

1. Review settings:
   - Name: `metastore-aws-us-west-2`
   - Region: `us-west-2`
   - S3 Path: (blank)
   - IAM cross-account role ARN: (blank)
2. Click **"Create"**

**Result:**
Metastore is now created

---

## Step 9: Assigning Workspace to Metastore

### Assignment Options

**Two Ways to Assign:**
1. **Immediate:** Right after creating Metastore (current screen)
2. **Later:** From Catalog -> Metastore -> Workspaces tab

**We'll use:** Immediate assignment

### Assignment Procedure

#### 1. Select Workspace

**From the Create Success Screen:**
1. Look for workspace assignment section
2. Find workspace in **us-west-2** region
3. Example: `d-course-dws`
4. Select the checkbox

#### 2. Assign Workspace

1. Click **"Assign"**
2. Review the confirmation dialog

#### 3. Understand the Warning

**Databricks Warning:**
Shows the effects of enabling Unity Catalog Metastore to a workspace.

**Key Points:**
- Unity Catalog will be enabled
- Three-level namespace required
- Access control changes
- Governance features activated

#### 4. Confirm Assignment

1. Read the warning
2. Click **"Enable"**

**Result:**
Workspace is now assigned to Unity Catalog Metastore

---

## Step 10: Configuring Metastore Admin Permissions

### Understanding the Permission Issue

**Current State:**
- Created new user: `db-admin@company.com`
- Used this user to create Metastore
- **This user** is the Metastore admin

**Problem:**
- You normally use a **different user** to log into Databricks workspace
- That user might **not have permissions** on the Metastore

**Solution:**
Assign the other user as Metastore admin.

---

### Configure Admin Procedure

#### 1. Navigate to Metastore Settings

1. In Account Console -> Catalog
2. Click on your **Metastore name**
3. View Metastore details

#### 2. Check Current Admin

**What You'll See:**
```
Metastore Admin: db-admin@company.com
```

**This is the new user we created.**

#### 3. Add Additional Admin

**Two Options:**

##### Option A: Specific User (Production)

**For Production Environments:**
1. Click **"Edit"** next to Metastore Admin
2. Type in the email address of your main user
3. Click **"Save"**

**Example:**
```
youremail@company.com
```

**Best Practice:**
Use this approach in production environments
- Specific user control
- Better security
- Clear accountability

##### Option B: All Users (Learning/Development)

**For Learning Purposes:**
1. Click **"Edit"** next to Metastore Admin
2. Type: `all users` or `all account users`
3. Select **"All account users"**
4. Click **"Save"**

**Warning:**
- Only suitable for learning/development
- **DO NOT** use in production
- Security risk with broad permissions

**Our Selection (For This Course):**
```
All account users
```

**Justification:**
- This is a learning account
- Safe for educational purposes
- Simplifies access during course

#### 4. Verify Changes

**Result:**
Metastore admin permissions updated. Your main user can now access and manage Metastore.

---

## Verification and Testing

### Test Workspace Connection

#### 1. Log into Databricks Workspace

Use your **main user** (not db-admin):
1. Navigate to Databricks workspace
2. Log in with your usual credentials

#### 2. Run Verification Command

Create a notebook and run:
```sql
SELECT current_metastore();
```

**Expected Result:**
```
metastore-aws-us-west-2
```

**What This Confirms:**
- Workspace successfully attached to Metastore
- Unity Catalog is enabled
- Configuration is complete

---

## Complete Configuration Summary

### What We Accomplished:

1. **Checked Metastore Status**
   - Used SQL command to verify
   - Identified if Metastore exists

2. **Created Admin User**
   - In Databricks Account Console
   - Assigned Account admin role

3. **Accessed Account Console**
   - Logged in with new admin user
   - Navigated the Account Console

4. **Created Metastore**
   - Named appropriately
   - Selected correct region
   - Skipped default storage (best practice)

5. **Assigned Workspace**
   - Attached workspace to Metastore
   - Enabled Unity Catalog

6. **Configured Permissions**
   - Set Metastore admin
   - Ensured access for main user

---

## Best Practices Checklist

### Naming Conventions

- [ ] Use descriptive Metastore names
- [ ] Include cloud provider
- [ ] Include region
- [ ] Use lowercase and hyphens

### Region Alignment

- [ ] Metastore in same region as workspace
- [ ] Verify region before creation
- [ ] One Metastore per region

### Storage Configuration

- [ ] Don't set default Metastore storage
- [ ] Plan separate storage per catalog
- [ ] Enable efficient capacity planning

### Security

- [ ] Create dedicated admin users
- [ ] Use specific users in production
- [ ] Avoid "all users" in production
- [ ] Follow least privilege principle

### Testing

- [ ] Verify with `SELECT current_metastore()`
- [ ] Confirm workspace attachment
- [ ] Test with main user account

---

## Troubleshooting Guide

### Common Issues and Solutions

| Issue | Cause | Solution |
|-------|-------|----------|
| **Can't access Account Console** | User not an account admin | Add user as account admin in Databricks Account Console |
| **Permission denied in Console** | No admin privileges | Assign Account admin role in Account Console |
| **Workspace not in list** | Different region | Create Metastore in correct region |
| **Can't create Metastore** | Already exists for region | Use existing Metastore |
| **SQL command fails** | Workspace not attached | Complete assignment process |

---

## Quick Reference

### Key URLs

| Resource | URL |
|----------|-----|
| **Account Console** | `https://accounts.cloud.databricks.com` |
| **AWS Console** | `https://console.aws.amazon.com` |

### Key Commands

| Purpose | Command |
|---------|---------|
| **Check Metastore** | `SELECT current_metastore();` |

### Important Locations

| Task | Location in AWS Console |
|------|-------------------------|
| **Manage IAM Users** | IAM -> Users |
| **Manage IAM Roles** | IAM -> Roles |

| Task | Location in Account Console |
|------|---------------------------|
| **View Workspaces** | Workspaces menu |
| **Manage Metastores** | Catalog menu |
| **Create Metastore** | Catalog -> Create Metastore |
| **Manage Users** | User management -> Users |
| **Assign Roles** | User management -> Users -> Select user -> Roles |

---

## What's Next

### Upcoming Topics:

Now that Unity Catalog Metastore is configured, we'll:
1. Create catalogs
2. Create schemas
3. Work with tables and volumes
4. Implement data governance
5. Configure access controls

### You're Ready to:

- Use Unity Catalog in your workspace
- Create and manage data objects
- Implement proper data governance
- Follow best practices for data organization

---

## Summary

### Key Takeaways:

1. **Metastore Creation** happens in Account Console, not workspace
2. **One Metastore per region** - workspace must be in same region
3. **Auto-creation** for accounts created after November 2023
4. **Don't set default storage** - better to separate per catalog
5. **Proper permissions** critical for access and management
6. **Verification** essential - always test configuration

### Configuration Complete!

You've successfully:
- Set up Unity Catalog Metastore
- Attached workspace to Metastore
- Configured admin permissions
- Ready for data engineering work

---

## CONCEPT GAP: Metastore Architecture Across Cloud Providers

Understanding how metastore setup differs across cloud providers is important for certification exams, especially when questions reference multi-cloud scenarios.

### Metastore Setup Comparison by Cloud Provider

```
+---------------------------------------------------------------------+
|                     AWS DATABRICKS                                   |
|                                                                      |
|  Account Console: https://accounts.cloud.databricks.com              |
|  Identity Provider: Databricks-native or SCIM from IdP               |
|  Admin Requirement: Account admin in Databricks                      |
|  Auto-creation: Since November 2023 for new accounts                 |
|  Default Storage: S3 bucket (optional, not recommended)              |
|  Access: IAM roles for cross-account access                          |
+---------------------------------------------------------------------+

+---------------------------------------------------------------------+
|                    AZURE DATABRICKS                                   |
|                                                                      |
|  Account Console: https://accounts.azure.databricks.net              |
|  Identity Provider: Microsoft Entra ID (formerly Azure AD)           |
|  Admin Requirement: Global Administrator in Entra ID                 |
|  Auto-creation: Since November 2023 for new subscriptions            |
|  Default Storage: ADLS Gen2 (optional, not recommended)              |
|  Access Connector: Azure-native first-party service                  |
+---------------------------------------------------------------------+

+---------------------------------------------------------------------+
|                     GCP DATABRICKS                                   |
|                                                                      |
|  Account Console: https://accounts.gcp.databricks.com                |
|  Identity Provider: Google Identity or SCIM                          |
|  Admin Requirement: Account admin in Databricks                      |
|  Auto-creation: Since November 2023 for new accounts                 |
|  Default Storage: GCS bucket (optional, not recommended)             |
|  Access: Service accounts for storage access                         |
+---------------------------------------------------------------------+
```

### Key Rule: One Metastore Per Region

```
+-------------------------------------------------------------+
|              Databricks Account                              |
|                                                              |
|  Region: us-east-1        Region: us-west-2                 |
|  +-------------------+   +-------------------+              |
|  |   Metastore       |   |   Metastore       |              |
|  |   (us-east-1)     |   |   (us-west-2)     |              |
|  |                   |   |                   |              |
|  |  +-------------+  |   |  +-------------+  |              |
|  |  | Workspace A |  |   |  | Workspace C |  |              |
|  |  +-------------+  |   |  +-------------+  |              |
|  |  +-------------+  |   |  +-------------+  |              |
|  |  | Workspace B |  |   |  | Workspace D |  |              |
|  |  +-------------+  |   |  +-------------+  |              |
|  +-------------------+   +-------------------+              |
|                                                              |
|  Rule: Workspace and Metastore MUST be in same region        |
|  Rule: Multiple workspaces can share one Metastore           |
|  Rule: A workspace can attach to only ONE Metastore          |
+-------------------------------------------------------------+
```

---

## CONCEPT GAP: Metastore Admin vs Account Admin vs Workspace Admin

A common source of confusion on exams is the distinction between admin roles. Each has a different scope of control.

### Admin Role Comparison

| Role | Scope | Key Responsibilities | Where Managed |
|------|-------|---------------------|---------------|
| **Account Admin** | Entire Databricks account | Create workspaces, manage users at account level, manage billing | Account Console |
| **Metastore Admin** | One Unity Catalog Metastore | Manage catalogs, storage credentials, external locations, grants | Account Console or Workspace |
| **Workspace Admin** | One Databricks workspace | Manage workspace users, clusters, notebooks, workspace settings | Workspace Admin Console |

### Permission Flow

```
+--------------------------------------------------+
|               ACCOUNT ADMIN                      |
|  - Creates metastores                            |
|  - Assigns metastore admins                      |
|  - Manages account-level identity                |
|  - Can do everything below                       |
+------------------+-------------------------------+
                   | delegates to
                   v
+--------------------------------------------------+
|              METASTORE ADMIN                     |
|  - Creates catalogs and storage credentials      |
|  - Manages data governance policies              |
|  - Grants privileges on metastore objects        |
|  - Manages external locations                    |
+------------------+-------------------------------+
                   | delegates to
                   v
+--------------------------------------------------+
|             WORKSPACE ADMIN                      |
|  - Manages compute resources                     |
|  - Manages workspace-level users                 |
|  - Cannot override metastore-level governance    |
+--------------------------------------------------+
```

---

## CONCEPT GAP: Default Metastore Storage -- Why Databricks Recommends Leaving It Blank

This is a best-practice question frequently asked in interviews and on exams.

### Default Storage Problems vs Dedicated Storage

```
ANTI-PATTERN: Default Metastore Storage
========================================

  +-----------------------------------------------+
  |         Single S3 Bucket                       |
  |                                                |
  |  /dev_catalog/schema1/table1/                  |
  |  /dev_catalog/schema2/table2/                  |
  |  /prod_catalog/schema1/table3/   <- MIXED!     |
  |  /test_catalog/schema1/table4/   <- MESSY!     |
  |                                                |
  |  Problems:                                     |
  |  - Cannot set different retention policies     |
  |  - Cannot isolate billing per catalog          |
  |  - Difficult to apply catalog-level ACLs       |
  |  - Single point of failure                     |
  +-----------------------------------------------+


BEST PRACTICE: Dedicated Storage Per Catalog
=============================================

  +------------------+  +------------------+  +------------------+
  |  Dev Bucket      |  |  Test Bucket     |  |  Prod Bucket     |
  |                  |  |                  |  |                  |
  |  /schema1/       |  |  /schema1/       |  |  /schema1/       |
  |  /schema2/       |  |  /schema2/       |  |  /schema2/       |
  |                  |  |                  |  |                  |
  |  Own ACLs        |  |  Own ACLs        |  |  Own ACLs        |
  |  Own retention   |  |  Own retention   |  |  Own retention   |
  |  Own billing     |  |  Own billing     |  |  Own billing     |
  +------------------+  +------------------+  +------------------+
```

---

## CONCEPT GAP: Useful SQL Commands for Metastore Management

These commands are important for both practical work and exam scenarios.

```sql
-- Check current metastore
SELECT current_metastore();

-- Check current catalog
SELECT current_catalog();

-- Check current schema
SELECT current_schema();

-- List all catalogs in the metastore
SHOW CATALOGS;

-- List all schemas in a catalog
SHOW SCHEMAS IN my_catalog;

-- List all grants on a securable object
SHOW GRANTS ON CATALOG my_catalog;
SHOW GRANTS ON SCHEMA my_catalog.my_schema;

-- Grant permissions
GRANT USE CATALOG ON CATALOG my_catalog TO `user@example.com`;
GRANT USE SCHEMA ON SCHEMA my_catalog.my_schema TO `user@example.com`;
GRANT SELECT ON TABLE my_catalog.my_schema.my_table TO `user@example.com`;

-- Set default catalog and schema for a session
USE CATALOG my_catalog;
USE SCHEMA my_schema;
```

---

## KEY INTERVIEW QUESTIONS AND ANSWERS

### Q1: Where do you create a Unity Catalog Metastore, and why can it not be created from a workspace?
**A:** A Unity Catalog Metastore must be created from the Databricks Account Console (https://accounts.cloud.databricks.com for AWS). It cannot be created from a workspace because the Metastore is an account-level resource that exists above the workspace level. A single Metastore can serve multiple workspaces in the same region, so it must be managed at the account level. You need Account admin privileges in Databricks to create one.

### Q2: What is the rule regarding Metastores and cloud regions?
**A:** There can be only one Unity Catalog Metastore per cloud region within a Databricks account. A workspace must be in the same region as the Metastore it attaches to. Multiple workspaces in the same region can attach to the same Metastore, enabling cross-workspace data sharing. A workspace can attach to only one Metastore at a time. Since November 2023, Databricks automatically creates a Metastore for new accounts.

### Q3: Why does Databricks recommend NOT setting a default storage location when creating a Metastore?
**A:** Databricks recommends leaving the default S3 path blank because a single default storage location becomes a "dumping ground" where all catalogs write data to the same bucket. This leads to poor data organization, makes capacity planning difficult, prevents per-catalog access control, and creates a data swamp. The recommended approach is to assign dedicated S3 buckets to individual catalogs or schemas, enabling proper separation, independent access control, and efficient capacity planning.

### Q4: What happens when a workspace is assigned to a Unity Catalog Metastore?
**A:** When a workspace is assigned to a Metastore, Unity Catalog is enabled for that workspace. This means: (1) a three-level namespace (catalog.schema.object) becomes required for referencing data objects, (2) the hive_metastore pseudo-catalog is automatically created for backward compatibility, (3) governance features like data lineage and audit logging become available, and (4) access control is managed at the account level rather than workspace level. Existing workloads using the Hive Metastore continue to work through the pseudo-catalog.

### Q5: What is the difference between an Account Admin, a Metastore Admin, and a Workspace Admin?
**A:** The Account Admin manages the entire Databricks account including creating workspaces, managing account-level users, and billing. The Metastore Admin manages a specific Unity Catalog Metastore including creating catalogs, storage credentials, external locations, and managing data governance policies. The Workspace Admin manages a single workspace including compute resources, workspace users, and workspace settings but cannot override metastore-level governance policies. In production, these should be separate roles following least-privilege principles.

### Q6: How do you verify that a workspace is properly connected to a Unity Catalog Metastore?
**A:** Run the SQL command `SELECT current_metastore();` in a notebook. If the workspace is properly attached, it returns the Metastore name (e.g., `metastore-aws-us-east-1`). If not attached, it returns an error: "Operation current_metastore requires Unity Catalog enabled." You can also verify through the Account Console by navigating to Catalog, selecting the Metastore, and checking the Workspaces tab to see which workspaces are attached.

### Q7: What was the significance of November 2023 for Unity Catalog Metastore creation?
**A:** Starting November 2023, Databricks began automatically creating a Unity Catalog Metastore for all new AWS accounts (and new accounts/subscriptions on other clouds). This means workspaces created after this date are automatically attached to a Metastore and have Unity Catalog enabled by default. For accounts created before November 2023, the Metastore must be manually created and the workspace must be manually attached. This change reflects Databricks' push toward universal adoption of Unity Catalog for data governance.

### Q8: In a production environment, what are the best practices for Metastore admin configuration?
**A:** In production: (1) Assign a specific user or a small group as Metastore admin rather than "all account users," (2) Create a dedicated admin user in the Databricks Account Console specifically for Databricks administration, (3) Follow the principle of least privilege so only authorized personnel can manage catalogs and storage credentials, (4) Use naming conventions that include the cloud provider and region (e.g., `metastore-aws-us-east-1`), (5) Do not set default Metastore storage; instead assign dedicated S3 buckets per catalog, and (6) Document the Metastore configuration and admin assignments.

---

*End of lesson*
