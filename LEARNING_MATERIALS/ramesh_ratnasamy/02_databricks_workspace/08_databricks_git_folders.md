# Databricks Git Folders: Collaborative Development Guide

## Introduction to Databricks Git Folders

Welcome back. In this lesson we are going to talk about **Databricks Git Folders**.

### Important Terminology Note:

**Git Folders** used to be called **"Databricks Repos"** until recently.

**⚠️ Exam Alert:**
You may come across the term **"repos"** in:
- Documentation
- Exam questions

Both terms refer to the same feature.

---

## What are Databricks Git Folders?

### Definition

Databricks Git Folders is a **visual Git client** made available in the Databricks workspace to enable **collaborative development** amongst developers.

### Purpose

Integrate Databricks projects with popular Git providers:
- GitHub
- Azure DevOps
- Bitbucket
- GitLab
- And more

---

## Understanding Version Control in Databricks

### Recall: Built-in Version History

From previous lessons, you may remember that Databricks offers **built-in version history for notebooks**.

**What it does:**
- Tracks changes made to notebooks
- Allows reverting to previous versions
- Automatic versioning

**However:** There are significant limitations when implementing software engineering solutions.

---

## Limitations of Built-in Version History

### 1. Limited Scope

**Problem:**
- Only tracks changes within a **specific notebook**
- No holistic view of changes across related notebooks
- Cannot track changes at project or feature level

**Impact:**
Difficult to manage complex projects with multiple interdependent notebooks.

### 2. Missing Advanced Git Features

**Absent Features:**
- ❌ Branching
- ❌ Merging
- ❌ Pull requests

**Impact:**
- Cannot work collaboratively in teams effectively
- No code review process before production deployment
- Limited ability to manage parallel development

### 3. No DevOps Integration

**Problem:**
- Doesn't integrate with DevOps tools (e.g., Azure DevOps)
- No automated testing
- No automated deployment

**Impact:**
Cannot implement modern CI/CD (Continuous Integration/Continuous Deployment) workflows.

---

## How Git Folders Overcome These Limitations

Databricks Git Folders (repos) help overcome these limitations by providing all the benefits of **Git-based source control tools**.

### Key Benefits:

#### 1. Comprehensive Change Tracking

**Capabilities:**
- ✅ Track changes to notebooks
- ✅ Track changes to scripts
- ✅ Track changes to any files in the project
- ✅ Manage changes across entire project

**Benefits:**
- Easily manage changes
- Revert to previous release of the project when required
- Full project version history

#### 2. Collaborative Development

**Capabilities:**
- ✅ Multiple users work on the same project
- ✅ Clone the same repository
- ✅ Work on separate branches
- ✅ Review and approve changes
- ✅ Merge changes to main branch

**Workflow:**
1. Developers clone repository
2. Create feature branches
3. Make changes independently
4. Submit pull requests
5. Team reviews code
6. Approved changes merge to main

#### 3. CI/CD Integration

**Capabilities:**
- ✅ Integration with Git providers
- ✅ Automated testing pipelines
- ✅ Automated deployment processes
- ✅ DevOps workflow support

**Benefits:**
- Automated quality checks
- Consistent deployment processes
- Reduced manual errors

---

## Comparison: Built-in Version History vs. Git Folders

| Feature | Built-in Version History | Git Folders |
|---------|-------------------------|-------------|
| **Scope** | Single notebook only | Entire project |
| **Branching** | ❌ Not available | ✅ Full branching support |
| **Merging** | ❌ Not available | ✅ Advanced merge capabilities |
| **Pull Requests** | ❌ Not available | ✅ Code review workflows |
| **Multi-file Tracking** | ❌ Single notebook | ✅ All files and scripts |
| **Team Collaboration** | Limited | ✅ Full team collaboration |
| **DevOps Integration** | ❌ Not available | ✅ CI/CD pipelines |
| **Automated Testing** | ❌ Not available | ✅ Via CI/CD |
| **Automated Deployment** | ❌ Not available | ✅ Via CI/CD |

---

## Git Integration with Databricks

### Supported Git Providers

Databricks integrates with popular Git providers:

| Provider | Support |
|----------|---------|
| **GitHub** | ✅ Fully supported |
| **Azure DevOps** | ✅ Fully supported |
| **Bitbucket** | ✅ Fully supported |
| **GitLab** | ✅ Fully supported |
| **AWS CodeCommit** | ✅ Fully supported |

**For this demo:** We'll use GitHub as an example (other integrations are very similar).

---

## Connection Methods

There are **two ways** to establish connection between Databricks and GitHub:

### Method 1: Databricks GitHub App (Recommended) ⭐

**Characteristics:**
- Official Databricks application
- OAuth-based authentication
- Modern integration approach

**Benefits:**

| Benefit | Description |
|---------|-------------|
| **Strong Security** | OAuth authentication, no password sharing |
| **Granular Access** | Fine-grained permissions per repository |
| **Easier Integration** | Simplified setup process |
| **Better Management** | Centralized access control |

**⭐ Databricks Recommendation:**
Use the Databricks GitHub App because it provides many benefits over personal access tokens.

### Method 2: Personal Access Tokens (PAT)

**Characteristics:**
- Token-based authentication
- Manual token management
- Legacy approach

**Limitations:**
- Less secure than OAuth
- Broader access scope
- More complex to manage

---

## Setting Up Git Integration

### High-Level Process

The integration process is straightforward:

#### Step 1: Link GitHub Account to Databricks

**Purpose:**
- Establish trust between Databricks and GitHub
- Grant Databricks access to your GitHub account

#### Step 2: Install Databricks App in GitHub

**Purpose:**
- Configure access permissions
- Specify which repositories Databricks can access

#### Step 3: Configure Repository Access

**Purpose:**
- Provide access to specific GitHub repositories
- Set appropriate permissions

**Result:**
✅ Databricks can now access GitHub repositories on your behalf

---

## Working with Git Folders

### Workflow Overview

Once integration is complete, you can perform standard Git operations:

#### 1. Create Git Folders

**Action:**
- Create Git Folders in Databricks workspace
- Link to remote repository

#### 2. Clone Repository

**Action:**
- Clone repository via Git UI in Databricks
- Pull down existing code

#### 3. Create Development Branches

**Action:**
- Create feature branches
- Isolate development work

#### 4. Commit and Push Changes

**Action:**
- Make code changes
- Commit to local branch
- Push to remote repository

#### 5. Pull Requests and Code Review

**Standard Process:**
1. Raise pull request
2. Team reviews code changes
3. Address feedback
4. Approve changes
5. Merge to main branch

#### 6. Trigger CI/CD Processes

**Automation:**
- Code in Git triggers automated processes
- DevOps pipelines execute
- Automated testing runs
- Automated deployment proceeds

---

## Scope for This Course

### What We'll Cover:

✅ **Git Folders functionality**
✅ **Code development using Git**
✅ **Working with branches**
✅ **Committing and pushing changes**
✅ **Basic Git operations in Databricks**

### What's Out of Scope:

❌ **DevOps Pipelines** (not in course or exam scope)
❌ **Advanced CI/CD configuration**
❌ **Automated testing frameworks**
❌ **Deployment automation details**

**Note:** While CI/CD is mentioned as a benefit, the detailed implementation is beyond the scope of this course and the certification exam.

---

## Complete Workflow Diagram

### Development Lifecycle with Git Folders:

```
1. Link GitHub Account → Databricks
   ↓
2. Install Databricks App → GitHub
   ↓
3. Configure Repository Access
   ↓
4. Create Git Folder → Databricks Workspace
   ↓
5. Clone Repository → Local Workspace
   ↓
6. Create Feature Branch
   ↓
7. Develop Code → Make Changes
   ↓
8. Commit Changes → Local Branch
   ↓
9. Push to Remote Repository
   ↓
10. Create Pull Request
   ↓
11. Code Review → Team Approval
   ↓
12. Merge to Main Branch
   ↓
13. (Optional) Trigger CI/CD Pipeline
   ↓
14. Automated Testing & Deployment
```

---

## Best Practices Preview

### Version Control Best Practices:

1. **Use Branches**: Never commit directly to main
2. **Meaningful Commits**: Write clear commit messages
3. **Regular Commits**: Commit frequently, push regularly
4. **Code Reviews**: Always use pull requests
5. **Keep Sync**: Pull latest changes before starting work

### Collaboration Best Practices:

1. **Clear Naming**: Use descriptive branch names
2. **Small Changes**: Keep pull requests focused
3. **Review Thoroughly**: Check code before approval
4. **Document Changes**: Update documentation with code

---

## Summary

### Key Concepts:

1. **Git Folders** (formerly Repos) = Visual Git client in Databricks
2. **Built-in version history** has limitations for team development
3. **Git integration** provides professional source control
4. **Two connection methods**: Databricks GitHub App (recommended) vs. PAT
5. **Full Git workflow** supported in Databricks

### Benefits of Git Folders:

| Benefit | Impact |
|---------|--------|
| **Project-wide tracking** | Manage entire codebase |
| **Branching & merging** | Parallel development |
| **Pull requests** | Code review process |
| **Team collaboration** | Multiple developers |
| **CI/CD integration** | Automated workflows |
| **DevOps support** | Professional deployment |

### What's Next:

In the next lesson, we'll implement Git Folders hands-on:
- Set up the integration
- Clone a repository
- Make changes
- Commit and push
- Work with branches

---

*End of lesson*
