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
- **One Metastore per cloud region** (Azure region in this case)
- Can attach all workspaces in that region to this Metastore

**For This Course:**
- We'll create one Metastore
- We have one workspace
- We'll attach the workspace to the Metastore

---

## Prerequisites and Important Information

### Where to Create Metastore

**⚠️ Important:**
- Metastore **cannot** be created from Databricks workspace
- Must be created from **Databricks Account Console**

### Access Requirements

**URL for Azure Databricks Account Console:**
```
https://accounts.azure.databricks.net
```

**Required Privileges:**
- User with **Global Administrator** privileges
- User must be listed in **Microsoft Entra ID** (formerly Azure Active Directory)

### Common Issue with Personal Subscriptions

**Problem:**
If you're using a **personal Azure subscription**, the user is generally **not listed** in Microsoft Entra ID.

**Solution:**
We'll create a new admin user with the required privileges to access the Databricks Account Console.

---

## Automatic Metastore Creation

### Important Notice

**⚠️ Some Users May Already Have a Metastore:**

Starting **November 2023**, Databricks automatically creates a Unity Catalog Metastore for all new Azure subscriptions.

### When You Already Have a Metastore:

| Subscription Created | Metastore Status | Action Required |
|---------------------|------------------|-----------------|
| **On or after November 2023** | ✅ Automatically created | ❌ No action needed |
| **Before November 2023** | ❌ Not created | ✅ Follow this lesson |

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

##### ✅ Workspace Attached to Metastore

**Result:**
- Returns the Metastore name
- Example: `metastore-azure-uksouth`

**What This Means:**
- Your workspace is already attached
- No further action needed
- You can skip the remaining steps

##### ❌ Workspace NOT Attached to Metastore

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
https://accounts.azure.databricks.net
```

1. Open browser
2. Navigate to the URL above
3. Click **"Continue"**
4. Sign in with your email address

### Expected Issue with Personal Subscriptions

**Error:**
If using a personal subscription, you'll likely receive an error.

**Why?**
The user doesn't exist in the Microsoft Entra ID tenant.

---

## Step 3: Understanding Microsoft Entra ID Users

### Navigate to Microsoft Entra ID

1. Go to **Azure Portal**
2. Search for **"Microsoft Entra ID"**
   - Previously called "Azure Active Directory"
   - Don't be confused by the name change
3. Click on **Microsoft Entra ID**

### View Users

1. Under **"Manage"**, click **"Users"**
2. Review existing users

### Understanding the User Issue

**What You'll See:**

| User Type | Email Format | Example |
|-----------|-------------|---------|
| **External User** | `email_txt@domain.onmicrosoft.com` | `user_txt@contoso.onmicrosoft.com` |
| **Internal User** | `email@domain.onmicrosoft.com` | `user@contoso.onmicrosoft.com` |

**External User Characteristics:**
- Email has `_txt` suffix (represents external user)
- Full domain name attached
- Can use this to log into Account Console
- Not ideal for admin work

---

## Step 4: Creating a Databricks Admin User

### Why Create a New User?

**Reasons:**
- Better practice than using external user
- Dedicated for Databricks admin work
- Cleaner management
- Proper permissions setup

### Create New User Procedure

#### 1. Start User Creation

In Microsoft Entra ID → Users:
1. Click **"+ New User"**
2. Click **"Create New User"**

#### 2. Configure User Details

**User Principal Name:**
```
db-admin
```
- This becomes: `db-admin@yourdomain.onmicrosoft.com`

**Display Name:**
```
Databricks Admin
```

#### 3. Set Password

**Options:**
- ❌ Don't use auto-generated password
- ✅ Create a custom password

**Password Setup:**
1. Uncheck "Auto-generate password"
2. Enter a strong password
3. Note: Will be asked to reset on first login

#### 4. Create User

1. Click **"Review + Create"**
2. Click **"Create"**
3. User is now created

#### 5. Verify User Creation

1. Refresh the Users page
2. Locate the new user: `db-admin@yourdomain.onmicrosoft.com`
3. **Copy the username** (you'll need it to log in)

---

## Step 5: Assigning Administrator Privileges

### Why Global Administrator?

**Requirement:**
User must be a **Databricks admin** to access Account Console.

**How to Achieve:**
Assign **Global Administrator** privilege → User gets Databricks admin privilege.

### Assign Role Procedure

#### 1. Navigate to User

1. Click on the **`db-admin`** user
2. Go to **"Assigned roles"**

#### 2. Check Current Roles

**Initial State:**
- No roles assigned

#### 3. Add Administrator Role

1. Click **"+ Add Assignments"**
2. Search for **"Global Administrator"**
3. Select **"Global Administrator"**
4. Click **"Add"**

#### 4. Verify Assignment

**Result:**
- User now has Global Administrator privileges
- Ready to access Databricks Account Console

---

## Step 6: Logging into Account Console with New User

### Login Procedure

#### 1. Navigate to Account Console

**URL:**
```
https://accounts.azure.databricks.net
```

#### 2. Use New User

1. Click **"Use another account"** (if needed)
2. Enter username: `db-admin@yourdomain.onmicrosoft.com`
3. Click **"Next"**

#### 3. Enter Password

1. Enter the password you created
2. Click **"Sign in"**

#### 4. Reset Password

**Prompt:**
You'll be asked to reset the password on first login.

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
✅ You're now logged into the **Databricks Account Console**

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
| **Region** | Azure region (e.g., `UK South`) |
| **Metastore** | Attached Metastore (if any) |
| **Status** | Active, Inactive |

**Example:**
```
Workspace: dws
Region: UK South  
Metastore: metastore-azure-uksouth ← Attached
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
- One Metastore in UK South region
- Could have multiple Metastores if working on multiple regions

#### View Metastore Details

1. Click on a **Metastore name**
2. Navigate to **"Workspaces"** tab
3. See all workspaces attached to this Metastore

---

## Step 8: Creating a New Metastore

### When to Create a Metastore

**Create a new Metastore if:**
- ❌ Your workspace is not attached to a Metastore
- ❌ No Metastore exists for your region
- ✅ You need to set up Unity Catalog

**Skip this step if:**
- ✅ Subscription created after November 2023
- ✅ Metastore already exists and workspace is attached

### Example Scenario

**Situation:**
- Have a workspace in **UK West** region
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
metastore-azure-<region>
```

**Example:**
```
metastore-azure-ukwest
```

**Best Practice:**
- Use descriptive names
- Include cloud provider (Azure)
- Include region
- Use lowercase and hyphens

##### Select Region

**⚠️ Critical Requirement:**
Metastore and workspace **must exist in the same region**.

**Example:**
- Workspace in: **UK West**
- Metastore in: **UK West** ← Must match

**Selection:**
1. Click region dropdown
2. Select **"UK West"** (or your workspace region)

##### ADLS Gen2 Path (Default Storage)

**What is this?**
Default storage location for the Metastore.

**Databricks Recommendation: Leave Blank** ⭐

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
- ✅ Leave **ADLS Gen2 Path** blank
- ✅ Leave **Access Connector ID** blank (not needed without default storage)

**Databricks Recommendation Shown:**
You'll see Databricks' recommendation to leave this blank in the UI.

#### 3. Create the Metastore

1. Review settings:
   - Name: `metastore-azure-ukwest`
   - Region: `UK West`
   - ADLS Gen2 Path: (blank)
   - Access Connector ID: (blank)
2. Click **"Create"**

**Result:**
✅ Metastore is now created

---

## Step 9: Assigning Workspace to Metastore

### Assignment Options

**Two Ways to Assign:**
1. **Immediate:** Right after creating Metastore (current screen)
2. **Later:** From Catalog → Metastore → Workspaces tab

**We'll use:** Immediate assignment

### Assignment Procedure

#### 1. Select Workspace

**From the Create Success Screen:**
1. Look for workspace assignment section
2. Find workspace in **UK West** region
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
✅ Workspace is now assigned to Unity Catalog Metastore

---

## Step 10: Configuring Metastore Admin Permissions

### Understanding the Permission Issue

**Current State:**
- Created new user: `db-admin@domain.onmicrosoft.com`
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

1. In Account Console → Catalog
2. Click on your **Metastore name**
3. View Metastore details

#### 2. Check Current Admin

**What You'll See:**
```
Metastore Admin: db-admin@domain.onmicrosoft.com
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
youremail@domain.com
```

**Best Practice:**
✅ Use this approach in production environments
- Specific user control
- Better security
- Clear accountability

##### Option B: All Users (Learning/Development)

**For Learning Purposes:**
1. Click **"Edit"** next to Metastore Admin
2. Type: `all users` or `all account users`
3. Select **"All account users"**
4. Click **"Save"**

**⚠️ Warning:**
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
✅ Metastore admin permissions updated
✅ Your main user can now access and manage Metastore

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
metastore-azure-ukwest
```

**What This Confirms:**
- ✅ Workspace successfully attached to Metastore
- ✅ Unity Catalog is enabled
- ✅ Configuration is complete

---

## Complete Configuration Summary

### What We Accomplished:

1. ✅ **Checked Metastore Status**
   - Used SQL command to verify
   - Identified if Metastore exists

2. ✅ **Created Admin User**
   - In Microsoft Entra ID
   - Assigned Global Administrator role

3. ✅ **Accessed Account Console**
   - Logged in with new admin user
   - Navigated the Account Console

4. ✅ **Created Metastore**
   - Named appropriately
   - Selected correct region
   - Skipped default storage (best practice)

5. ✅ **Assigned Workspace**
   - Attached workspace to Metastore
   - Enabled Unity Catalog

6. ✅ **Configured Permissions**
   - Set Metastore admin
   - Ensured access for main user

---

## Best Practices Checklist

### ✅ Naming Conventions

- [ ] Use descriptive Metastore names
- [ ] Include cloud provider
- [ ] Include region
- [ ] Use lowercase and hyphens

### ✅ Region Alignment

- [ ] Metastore in same region as workspace
- [ ] Verify region before creation
- [ ] One Metastore per region

### ✅ Storage Configuration

- [ ] Don't set default Metastore storage
- [ ] Plan separate storage per catalog
- [ ] Enable efficient capacity planning

### ✅ Security

- [ ] Create dedicated admin users
- [ ] Use specific users in production
- [ ] Avoid "all users" in production
- [ ] Follow least privilege principle

### ✅ Testing

- [ ] Verify with `SELECT current_metastore()`
- [ ] Confirm workspace attachment
- [ ] Test with main user account

---

## Troubleshooting Guide

### Common Issues and Solutions

| Issue | Cause | Solution |
|-------|-------|----------|
| **Can't access Account Console** | User not in Entra ID | Create new user in Entra ID |
| **Permission denied in Console** | No admin privileges | Assign Global Administrator role |
| **Workspace not in list** | Different region | Create Metastore in correct region |
| **Can't create Metastore** | Already exists for region | Use existing Metastore |
| **SQL command fails** | Workspace not attached | Complete assignment process |

---

## Quick Reference

### Key URLs

| Resource | URL |
|----------|-----|
| **Account Console** | `https://accounts.azure.databricks.net` |
| **Azure Portal** | `https://portal.azure.com` |

### Key Commands

| Purpose | Command |
|---------|---------|
| **Check Metastore** | `SELECT current_metastore();` |

### Important Locations

| Task | Location in Azure Portal |
|------|-------------------------|
| **Manage Users** | Microsoft Entra ID → Users |
| **Assign Roles** | User → Assigned Roles |

| Task | Location in Account Console |
|------|---------------------------|
| **View Workspaces** | Workspaces menu |
| **Manage Metastores** | Catalog menu |
| **Create Metastore** | Catalog → Create Metastore |

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

- ✅ Use Unity Catalog in your workspace
- ✅ Create and manage data objects
- ✅ Implement proper data governance
- ✅ Follow best practices for data organization

---

## Summary

### Key Takeaways:

1. **Metastore Creation** happens in Account Console, not workspace
2. **One Metastore per region** - workspace must be in same region
3. **Auto-creation** for subscriptions after November 2023
4. **Don't set default storage** - better to separate per catalog
5. **Proper permissions** critical for access and management
6. **Verification** essential - always test configuration

### Configuration Complete! 🎉

You've successfully:
- ✅ Set up Unity Catalog Metastore
- ✅ Attached workspace to Metastore
- ✅ Configured admin permissions
- ✅ Ready for data engineering work

---

*End of lesson*