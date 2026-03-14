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

## Git Folders Architecture Diagram

```
┌──────────────────────────────────────────────────────────────────────┐
│                     GIT PROVIDER (e.g., GitHub)                       │
│                                                                       │
│  ┌──────────────────────────────────────────────────────────────┐    │
│  │                    REMOTE REPOSITORY                          │    │
│  │  main branch ──────────────────────────────────────────────   │    │
│  │  feature/etl-pipeline ─────────────────────                   │    │
│  │  feature/dashboard-v2 ──────────────                          │    │
│  └──────────────────────────────────────────────────────────────┘    │
│                                                                       │
└──────────────────────────┬───────────────────────────────────────────┘
                           │
              clone / pull / push
                           │
┌──────────────────────────▼───────────────────────────────────────────┐
│                  DATABRICKS WORKSPACE                                 │
│                                                                       │
│  ┌──────────────────────────────────────────────────────────────┐    │
│  │                    GIT FOLDERS (Repos)                         │    │
│  │                                                               │    │
│  │  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐       │    │
│  │  │  Developer 1  │  │  Developer 2  │  │  Developer 3  │       │    │
│  │  │  Clone of repo│  │  Clone of repo│  │  Clone of repo│       │    │
│  │  │              │  │              │  │              │       │    │
│  │  │  Branch:      │  │  Branch:      │  │  Branch:      │       │    │
│  │  │  feature/etl  │  │  feature/dash │  │  main         │       │    │
│  │  └──────────────┘  └──────────────┘  └──────────────┘       │    │
│  └──────────────────────────────────────────────────────────────┘    │
│                                                                       │
└──────────────────────────────────────────────────────────────────────┘
```

---

## Git Workflow in Databricks

```
Developer A                    GitHub                    Developer B
    │                            │                            │
    │  1. Clone repo             │                            │
    │◄───────────────────────────│                            │
    │                            │                            │
    │  2. Create feature branch  │                            │
    │─────────────────────────►  │                            │
    │                            │                            │
    │  3. Make changes           │                            │
    │  (edit notebooks)          │                            │
    │                            │                            │
    │  4. Commit + Push          │                            │
    │─────────────────────────►  │                            │
    │                            │                            │
    │  5. Create Pull Request    │  6. Review + Approve       │
    │─────────────────────────►  │◄───────────────────────────│
    │                            │                            │
    │  7. Merge to main          │                            │
    │─────────────────────────►  │                            │
    │                            │                            │
    │                            │  8. Pull latest changes    │
    │                            │───────────────────────────►│
    │                            │                            │
```

---

## CONCEPT GAP: Supported File Types in Git Folders

Git Folders support more than just notebooks:

| File Type | Support | Notes |
|-----------|---------|-------|
| **Databricks Notebooks** | Full | .py, .sql, .scala, .r with Databricks header |
| **Python files** (.py) | Full | Can be imported as modules |
| **SQL files** (.sql) | Full | Can be referenced in workflows |
| **R files** (.r) | Full | Supported |
| **Scala files** (.scala) | Full | Supported |
| **YAML / JSON** | Full | Configuration files, pipeline definitions |
| **requirements.txt** | Full | Python dependency management |
| **Markdown** (.md) | Full | Documentation, README files |
| **Data files** | Limited | Small files only (< 10 MB recommended) |
| **JAR / wheel files** | Not recommended | Use artifact repositories instead |

- Git Folders have a **size limit** per repo (typically around 10 GB).
- **Large binary files** should not be stored in Git Folders; use cloud storage or artifact repositories instead.

---

## CONCEPT GAP: Git Folders vs. Workspace Files

Databricks has two locations where files can exist:

| Feature | Git Folders (Repos) | Workspace Files |
|---------|-------------------|----------------|
| **Location** | Under `/Repos/<user>/` | Under `/Users/<user>/` or `/Shared/` |
| **Version control** | Full Git integration | Built-in version history only |
| **Branching** | Yes | No |
| **Collaboration** | Via Git PR workflow | Direct sharing |
| **CI/CD integration** | Yes (via Git provider) | No |
| **File types** | Notebooks + arbitrary files | Notebooks + limited file types |
| **Best for** | Production code, team projects | Quick experiments, personal work |
| **Sync method** | Git clone / pull / push | Manual import/export |

---

## CONCEPT GAP: Databricks Asset Bundles (DABs)

For production CI/CD, Databricks Asset Bundles are the modern approach:

- **DABs** allow you to define Databricks resources (jobs, pipelines, clusters) as code in YAML files alongside your notebooks and scripts in a Git repository.
- A `databricks.yml` file defines the bundle configuration including targets (dev, staging, prod), resource definitions, and variable substitutions.
- DABs integrate with CI/CD pipelines (GitHub Actions, Azure DevOps, GitLab CI) to deploy resources automatically.
- This is the evolution beyond simple Git Folders -- Git Folders manage code, while DABs manage code AND infrastructure together.

```
my-project/
├── databricks.yml          # Bundle configuration
├── resources/
│   ├── my_job.yml          # Job definition
│   └── my_pipeline.yml     # DLT pipeline definition
├── src/
│   ├── etl_notebook.py     # Notebook source
│   └── utils.py            # Python module
└── tests/
    └── test_etl.py         # Unit tests
```

---

## CONCEPT GAP: Authentication Methods Comparison

| Method | Security Level | Setup Complexity | Token Rotation | Best For |
|--------|---------------|-----------------|---------------|----------|
| **Databricks GitHub App** (OAuth) | High | Low | Automatic | Most use cases |
| **Personal Access Token (PAT)** | Medium | Medium | Manual | Quick setup, personal use |
| **Service Principal + OAuth** | High | High | Configurable | CI/CD pipelines |
| **SSH Keys** | High | Medium | Manual | Developers comfortable with SSH |

- For **production CI/CD**, use a Service Principal with OAuth tokens rather than personal credentials.
- PATs have an expiration date and must be rotated manually; forgetting to rotate can break integrations.
- The Databricks GitHub App uses OAuth which handles token management automatically.

---

## CONCEPT GAP: Branching Strategy for Databricks Projects

A recommended branching strategy for data engineering teams:

```
main (production)
  │
  ├── develop (integration branch)
  │     │
  │     ├── feature/add-new-etl-pipeline
  │     │
  │     ├── feature/update-data-quality-checks
  │     │
  │     └── bugfix/fix-null-handling
  │
  └── release/v1.2
```

- **main**: Always deployable, represents production code.
- **develop**: Integration branch where feature branches merge before going to main.
- **feature/***: Short-lived branches for new features or changes.
- **bugfix/***: Branches for bug fixes.
- **release/***: Optional release branches for versioned deployments.

Best practices:
- Protect the `main` branch (require PR reviews before merging).
- Keep feature branches short-lived (merge within days, not weeks).
- Use meaningful branch names that reference ticket numbers (e.g., `feature/JIRA-123-add-customer-etl`).

---

## KEY INTERVIEW QUESTIONS AND ANSWERS

### Q1: What are Databricks Git Folders and why are they needed?
**A:** Git Folders (formerly Databricks Repos) is a visual Git client integrated into the Databricks workspace that enables collaborative development using standard Git workflows. They are needed because the built-in notebook version history has significant limitations: it only tracks individual notebooks (not project-wide changes), lacks branching and merging capabilities, does not support pull requests for code review, and cannot integrate with CI/CD pipelines. Git Folders solve all of these by connecting Databricks directly to Git providers like GitHub, Azure DevOps, GitLab, and Bitbucket.

### Q2: What is the difference between the Databricks GitHub App and Personal Access Tokens for Git integration?
**A:** The Databricks GitHub App uses OAuth-based authentication, providing stronger security, granular per-repository access control, automatic token management, and easier setup. Personal Access Tokens (PATs) use token-based authentication with broader access scope, require manual token creation and rotation, and are less secure since a leaked token grants access to all repositories the token has permissions for. Databricks recommends the GitHub App approach. For CI/CD pipelines, Service Principals with OAuth tokens are preferred over PATs.

### Q3: What Git operations can you perform within Databricks Git Folders?
**A:** You can perform standard Git operations including: clone a remote repository, create and switch branches, view file diffs (changes), stage and commit changes, push commits to the remote repository, pull latest changes from remote, and resolve merge conflicts. Pull requests and code reviews are performed in the Git provider's interface (e.g., GitHub), not within Databricks. Git Folders provide a visual UI for these operations, so you do not need to use command-line Git.

### Q4: How does Git Folders differ from the built-in notebook version history?
**A:** Built-in version history tracks changes to a single notebook only, has no branching or merging, does not support pull requests, and cannot integrate with CI/CD tools. Git Folders provide project-wide change tracking across all files (notebooks, scripts, configs), full branching and merging support, pull request workflows for code review, and integration with CI/CD pipelines for automated testing and deployment. Built-in version history is useful for quick personal undo/redo; Git Folders are essential for team-based production development.

### Q5: What types of files can be stored in Databricks Git Folders?
**A:** Git Folders support Databricks notebooks (.py, .sql, .scala, .r with Databricks headers), plain Python/SQL/R/Scala source files, YAML and JSON configuration files, requirements.txt for dependency management, Markdown files for documentation, and small data files. Large binary files and artifacts (JARs, wheels) should not be stored in Git Folders due to size limitations; use cloud storage or artifact repositories instead. There is typically a ~10 GB size limit per repository.

### Q6: What is the recommended workflow for making changes using Git Folders?
**A:** The recommended workflow is: (1) Pull latest changes from the main branch; (2) Create a new feature branch from main; (3) Make code changes in the feature branch; (4) Test changes by running notebooks on a development cluster; (5) Commit and push changes to the remote repository; (6) Create a pull request in the Git provider; (7) Team members review the code; (8) After approval, merge the feature branch to main; (9) Optionally trigger CI/CD pipelines for automated deployment. Never commit directly to the main branch.

### Q7: Can multiple developers work on the same repository simultaneously in Databricks?
**A:** Yes. Each developer clones the repository into their own Git Folder in the workspace (under `/Repos/<username>/`). Each developer works on their own branch, making independent changes without affecting others. Changes are coordinated through the Git provider using pull requests and code reviews. When a developer needs the latest changes from another developer's merged work, they pull from the remote main branch. Git's conflict resolution handles any overlapping changes.

### Q8: What are Databricks Asset Bundles and how do they relate to Git Folders?
**A:** Databricks Asset Bundles (DABs) are a framework for managing Databricks resources (jobs, DLT pipelines, clusters) as code alongside notebooks and scripts in a Git repository. While Git Folders manage the code versioning and collaboration aspects, DABs extend this by allowing you to define and deploy infrastructure-as-code using YAML configuration files (databricks.yml). DABs integrate with CI/CD pipelines to automatically deploy resources across environments (dev, staging, prod). They represent the evolution from "code in Git" to "everything as code" for Databricks projects.

---

*End of lesson*
