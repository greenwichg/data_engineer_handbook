# Databricks Notebooks: Complete Guide

## Introduction to Databricks Notebooks

Welcome back. In this lesson we're going to look at Databricks notebooks.

### What is a Databricks Notebook?

Databricks offers a **Jupyter-style notebook environment** with additional features to streamline development.

**Definition:**
A notebook is a **collection of cells** that execute commands on a Databricks cluster.

Now that we've created our compute/cluster, let's explore working with notebooks in the Databricks workspace.

---

## Prerequisite: Starting Your Cluster

Before creating a notebook, ensure your cluster is up and running.

### Steps to Start a Terminated Cluster:

1. Navigate to the **Compute** section
2. Check cluster status (may be terminated from previous session)
3. Click the **Play button** to start the cluster
4. **Confirm** you want to start the cluster

**Note**: You can create notebooks while the cluster is starting.

---

## Workspace Organization

### Understanding the Workspace Structure

Notebooks exist under the **Workspace** section, which contains:

#### 1. Users Folder
- Contains a folder for each user with workspace access
- Personal workspace for individual users
- Example: `cloudboxacademy@gmail.com`

#### 2. Shared Folder
- Used to share resources and notebooks amongst workspace users
- Collaborative workspace

#### 3. Repos Folder
- Ignore for now (covered later in the course)

---

## Creating a Folder Structure

### Best Practice: Organize Your Notebooks

Before creating notebooks, set up a logical folder structure:

**Example Folder Hierarchy:**
```
Users/
  └── cloudboxacademy@gmail.com/
      └── db-course/
          └── db01-databricks-lakehouse-platform/
```

### How to Create Folders:

1. Navigate to your user folder
2. Right-click and select **"Create Folder"**
3. Name your folder (e.g., "db-course")
4. Create subfolders as needed (e.g., "db01-databricks-lakehouse-platform")

---

## Creating a Notebook

### Two Methods to Create Notebooks:

#### Method 1: Right-Click Menu
- Right-click on the folder
- Select **"Create Notebook"**

#### Method 2: Create Button
- Click the **"Create"** button (top right)
- Navigate to **"Notebook"**

### Notebook Configuration:

**Naming:**
- Databricks assigns a default name
- Provide a meaningful name
- **Example**: "01.notebook_introduction"

**Default Language:**
- Choose the default language for the notebook
- Options: Python, SQL, Scala, R
- **For this demo**: Python

**Important Note:**
The default language applies to all commands in the notebook unless overridden in individual cells.

---

## Attaching Notebook to Cluster

### Required Step:

To execute commands, the notebook **must be attached to a cluster**.

### How to Attach:

1. Click **"Connect"**
2. Select your cluster (e.g., "course-cluster")
3. Wait for connection to establish

---

## Working with Code Cells

### Executing Cells

#### Sample Python Command:

```python
print("Hello")
```

#### Multiple Ways to Execute:

| Method | Action |
|--------|--------|
| **Play Button** | Click the play button on the cell |
| **Shift + Enter** | Execute cell and move to next cell |
| **Run Menu** | Go to Run → Run Selected Cell |
| **Run All** | Execute entire notebook |

#### Keyboard Shortcuts:

**To view all shortcuts:**
1. Go to **Help** menu
2. Click **"Keyboard Shortcuts"**
3. View complete list of available commands

### Executing Partial Code

**Select and Run Specific Lines:**

1. Select the line(s) you want to execute
2. Use **Control + Shift + Enter**
3. Or click **"Run Selected Text"**

**Example:**
```python
print("Hello")
print("World")  # Select only this line to execute it alone
```

### Running Multiple Cells

**Run Entire Notebook:**
- Click the **"Run All"** button at the top
- All cells execute sequentially

---

## Creating Additional Cells

### How to Add Cells:

1. **Hover** the mouse between cells
2. Two options appear:
   - **Code Cell**: For executable code
   - **Text Cell**: For documentation (Markdown)

---

## Working with Text Cells (Documentation)

### Text Cell Basics

**Key Identifier:**
- Text cells start with `%md` (Markdown magic command)
- This is the only difference between text and code cells
- Removing `%md` converts it to a code cell

### Markdown Formatting

#### Creating Headers:

**Using Hash Characters:**
```markdown
# Heading 1
## Heading 2
### Heading 3
```

**Using Menu Options:**
- Recently introduced toolbar
- Click header button to insert
- Select header level (H1, H2, H3, etc.)

#### Creating Bullet Points:

**Manual Method:**
```markdown
- Bullet point 1
- Bullet point 2
```

**Menu Method:**
- Click bullet point button in toolbar
- Adds hyphen and space automatically

**Example Output:**
```markdown
%md
## Notebook Introduction

This notebook demonstrates basic operations.

- First bullet point
- Second bullet point
```

**Tip**: Remember to add line breaks (`Enter`) between elements for proper formatting.

---

## Multi-Language Support

### Default vs. Cell-Specific Languages

**Default Language:**
- Set when creating the notebook (e.g., Python)
- Applies to all cells unless overridden

### Magic Commands

**Purpose:**
Magic commands allow you to switch languages for specific cells.

### Using Magic Commands

#### Method 1: Dropdown Menu
1. Click the language dropdown in a cell
2. Select desired language (SQL, Scala, R, etc.)
3. Magic command is automatically added

#### Method 2: Manual Entry
Simply type the magic command at the beginning of the cell:

```sql
%sql
SELECT "Hello from SQL" as greeting
```

### Available Magic Commands:

| Magic Command | Language |
|--------------|----------|
| `%python` | Python |
| `%sql` | SQL |
| `%scala` | Scala |
| `%r` | R |
| `%md` | Markdown |

### Example: Mixed Language Notebook

```python
# Cell 1 - Python (default)
print("Hello from Python")
```

```sql
# Cell 2 - SQL
%sql
SELECT "Hello from SQL" as greeting
```

```python
# Cell 3 - Back to Python
print("Back to Python")
```

**Benefits:**
- Mix Python, SQL, Scala, and R in one notebook
- All commands execute seamlessly
- "That's the beauty of Databricks notebooks!"

---

## Menu Options

### File Menu

#### Import
- Import a notebook or folder into your workspace
- Supports various formats

#### Export
- Export notebook or entire folder
- **File Format Options**:
  - **DBC**: Databricks proprietary format (includes all metadata)
  - **Source File**: Language-specific format (Python, SQL, Scala)

#### Clone
- Create a copy of the notebook

#### Move
- Move notebook to a different folder

### View Menu

#### View Options:

| View Mode | Description |
|-----------|-------------|
| **Standard** | Shows code and results together |
| **Results Only** | Shows only output/results |
| **Side by Side** | Code and results displayed side by side |

**Recommendation**: Use the view that matches your preference (Standard is commonly used).

#### Clear and Rerun
- **Clear State**: Resets all variables and execution state
- **Rerun**: Execute notebook from clean state

### Run Menu

Options to execute cells and manage execution.

### Cluster Menu

- **Detach**: Disconnect from cluster
- **Restart**: Restart the attached cluster
- **Detach and Restart**: Both actions together

---

## Side Menu Features (Left Side)

### 1. Table of Contents

**Purpose:**
- Automatically populated from document headings
- Easy navigation in large notebooks

**Benefits:**
- Click on any heading to jump to that section
- Essential for well-documented notebooks with many sections
- Makes navigation much easier

**Best Practice**: Properly document notebooks with headings and subheadings.

### 2. Workspace Navigation

**Purpose:**
- Navigate within workspace without leaving the notebook

**Old Way:**
- Go to Workspace menu
- Exit notebook
- Navigate to another notebook

**New Way:**
- Use workspace menu in sidebar
- Navigate directly between notebooks
- Switch between notebooks seamlessly

**Benefits**: Much easier to work with multiple notebooks.

### 3. Catalog

**Purpose:**
- Shows all tables and volumes
- Available in Unity Catalog or Hive Metastore

**Note**: Will be covered later in the course.

### 4. Assistant

**Purpose:**
- AI assistant for help with code

**Access Points:**
- Sidebar
- Top right corner (multiple locations)

---

## Side Menu Features (Right Side)

### 1. Comments

**Purpose:**
- Collaborative feature for shared notebooks
- Add comments for team members

**Use Case:**
- Working with others on the same notebook
- Leave notes for specific sections
- Team collaboration

**Note**: Not widely used but available when needed.

### 2. MLflow Experiments

**Purpose:**
- Machine learning experiment tracking

**Note**: Not critical for data engineering (can ignore for this course).

### 3. Version History ⭐

**Purpose:**
- Automatic versioning of notebooks
- No manual action required

**Features:**

#### View History
- See all versions with timestamps
- Review changes over time

#### Restore Previous Version
- Click on any version
- Select **"Restore this version"**
- Notebook reverts to that point in time

#### Clear History
- Option to clear version history if needed

**Example Use Case:**
"Let's say we want to go back to how the notebook was at 2:50 PM - simply find that version and restore it."

### 4. Variables and Libraries

**Purpose:**
- View all variables used in the notebook
- See imported libraries

**Benefits**: Quick reference for debugging and understanding dependencies.

### 5. Environment

**Purpose:**
- Environment configuration

**Note**: Only specific for serverless compute.

---

## Sharing Notebooks

### How to Share:

1. Click the **Share** button (top right or sidebar)
2. Add users you want to share with
3. Set permissions as needed

### Collaborative Features:

- Multiple users can work on the same notebook
- Real-time collaboration
- Comments and version history support teamwork

---

## Summary

### Key Concepts Covered:

1. ✅ **Notebook Basics**: Collection of cells executing on a cluster
2. ✅ **Workspace Organization**: Users, Shared, and Repos folders
3. ✅ **Creating Notebooks**: Naming, language selection, cluster attachment
4. ✅ **Executing Code**: Multiple methods and keyboard shortcuts
5. ✅ **Documentation**: Text cells with Markdown formatting
6. ✅ **Multi-Language Support**: Magic commands for language switching
7. ✅ **Menu Options**: Import, export, view modes, clear state
8. ✅ **Side Menus**: Table of contents, workspace navigation, version history
9. ✅ **Collaboration**: Sharing, comments, and version control

### What's Next:

Don't worry if you haven't understood everything yet. We're going to:
- Work with notebooks throughout the course
- Create many notebooks
- Practice these concepts repeatedly
- Build familiarity through hands-on experience

**By the end of this course**, you'll be completely comfortable with Databricks notebooks!

---

## Notebook Architecture Diagram

```
┌─────────────────────────────────────────────────────────────────┐
│                    DATABRICKS NOTEBOOK                           │
│                                                                  │
│  ┌───────────────────────────────────────────────────────────┐  │
│  │  Cell 1: %md   Documentation / Title                      │  │
│  ├───────────────────────────────────────────────────────────┤  │
│  │  Cell 2: %python   print("Hello")                         │  │
│  │  [Output: Hello]                                          │  │
│  ├───────────────────────────────────────────────────────────┤  │
│  │  Cell 3: %sql   SELECT * FROM my_table                    │  │
│  │  [Output: Table results]                                  │  │
│  ├───────────────────────────────────────────────────────────┤  │
│  │  Cell 4: %python   df.show()                              │  │
│  │  [Output: DataFrame results]                              │  │
│  └───────────────────────────────────────────────────────────┘  │
│                                                                  │
│  ┌──────────────┐                                               │
│  │  ATTACHED TO  │──────► Databricks Cluster (compute)          │
│  └──────────────┘                                               │
└─────────────────────────────────────────────────────────────────┘
```

---

## Workspace Folder Structure

```
┌──────────────────────────────────────────┐
│             WORKSPACE                     │
│                                           │
│  ├── Users/                               │
│  │   ├── user1@company.com/               │
│  │   │   ├── project-a/                   │
│  │   │   │   ├── notebook1.py             │
│  │   │   │   └── notebook2.sql            │
│  │   │   └── project-b/                   │
│  │   └── user2@company.com/               │
│  │                                        │
│  ├── Shared/                              │
│  │   ├── team-notebooks/                  │
│  │   └── common-utils/                    │
│  │                                        │
│  └── Repos (Git Folders)/                 │
│      ├── user1@company.com/               │
│      │   └── my-git-repo/                 │
│      └── user2@company.com/               │
└──────────────────────────────────────────┘
```

---

## CONCEPT GAP: Notebook Export Formats

Understanding notebook file formats is important for certification:

| Format | Extension | Description | Use Case |
|--------|-----------|-------------|----------|
| **DBC** | `.dbc` | Databricks Archive (proprietary) | Full backup with metadata, results, dashboards |
| **Source** | `.py`, `.sql`, `.scala`, `.r` | Language-specific source file | Version control, external editing |
| **HTML** | `.html` | Rendered notebook with results | Sharing with non-Databricks users |
| **IPython/Jupyter** | `.ipynb` | Jupyter Notebook format | Interoperability with Jupyter ecosystem |

- **DBC format** preserves everything: code, results, visualizations, metadata, and dashboard configurations.
- **Source format** exports only the code and magic commands; results and visualizations are not included.
- When importing a source file, Databricks uses the first line magic command (e.g., `# Databricks notebook source`) to identify it as a Databricks notebook.

---

## CONCEPT GAP: Notebook Workflows vs. Databricks Workflows

Understanding the difference is critical for exam prep:

| Feature | Notebook Workflows (%run, dbutils.notebook.run) | Databricks Workflows (Jobs) |
|---------|------------------------------------------------|----------------------------|
| **Invocation** | From within a notebook | From the Jobs UI, API, or CLI |
| **Orchestration** | Manual, code-based | Visual DAG, declarative |
| **Error handling** | Custom try/except | Built-in retry policies |
| **Monitoring** | Limited (manual logging) | Full UI with run history, alerts |
| **Scheduling** | Not built-in (needs external trigger) | Built-in cron scheduling |
| **Parameters** | Widgets or %run arguments | Job parameters, task values |
| **Recommendation** | Simple, ad hoc chaining | Production pipelines |

- `%run` executes the child notebook in the **same** execution context (shares variables, SparkSession).
- `dbutils.notebook.run()` executes the child notebook in a **separate** execution context (isolated variables, returns a string result).

---

## CONCEPT GAP: Notebook Widgets for Parameterization

Widgets allow notebooks to accept parameters at runtime:

```python
# Create a text widget
dbutils.widgets.text("environment", "dev", "Environment")

# Create a dropdown widget
dbutils.widgets.dropdown("region", "us-east-1", ["us-east-1", "us-west-2", "eu-west-1"])

# Get widget value
env = dbutils.widgets.get("environment")

# Remove a widget
dbutils.widgets.remove("environment")

# Remove all widgets
dbutils.widgets.removeAll()
```

- Widgets appear as input controls at the top of the notebook.
- Values can be passed externally via `dbutils.notebook.run()` or Databricks Jobs.
- Four widget types: **text**, **dropdown**, **combobox**, **multiselect**.

---

## CONCEPT GAP: Notebook Execution Context and State

Key concepts for understanding notebook behavior:

- **Execution context**: When a notebook is attached to a cluster, it gets an execution context (essentially a REPL session) that holds the SparkSession, variables, and imported libraries.
- **State persistence**: Variables and objects persist in memory between cell executions within the same session. They are lost when the cluster is terminated, the notebook is detached, or "Clear State" is used.
- **Cell execution order**: Cells can be executed in any order. This can lead to issues if cells depend on each other. Best practice is to write notebooks that can be run top-to-bottom.
- **Detach and re-attach**: Detaching a notebook from a cluster destroys the execution context. Re-attaching starts a fresh context.
- **Concurrent execution**: Multiple notebooks can share the same cluster (subject to access mode). Each notebook gets its own isolated execution context.

---

## KEY INTERVIEW QUESTIONS AND ANSWERS

### Q1: What is the difference between a Databricks notebook and a standard Jupyter notebook?
**A:** Databricks notebooks share the cell-based execution model with Jupyter but offer several additional features: (1) native multi-language support via magic commands (%python, %sql, %scala, %r) in a single notebook; (2) built-in collaboration with real-time co-editing, comments, and sharing; (3) automatic version history without needing Git; (4) native integration with Databricks clusters for distributed computing; (5) built-in visualization capabilities and the display() function; (6) integration with Unity Catalog for data governance; and (7) support for Databricks Workflows for production scheduling.

### Q2: How does the %run magic command differ from dbutils.notebook.run()?
**A:** `%run` executes the child notebook in the **same execution context** as the calling notebook, meaning all variables, functions, and imports from the child notebook become available in the parent. It is synchronous and blocks until completion. `dbutils.notebook.run()` executes the child notebook in a **new, isolated execution context** on the same cluster. It can accept parameters, returns a string result, and supports a timeout parameter. The key difference is variable sharing: %run shares state, dbutils.notebook.run() does not.

### Q3: What export formats are available for Databricks notebooks and when would you use each?
**A:** Four export formats are available: (1) **DBC** (Databricks Archive) -- preserves everything including code, results, visualizations, and metadata; best for full backups. (2) **Source file** (.py, .sql, etc.) -- exports only code; best for version control in Git. (3) **HTML** -- rendered notebook with results; best for sharing with non-Databricks users. (4) **IPython/Jupyter** (.ipynb) -- standard Jupyter format; best for interoperability with the Jupyter ecosystem. For production Git workflows, source format is most common.

### Q4: How does version history work in Databricks notebooks?
**A:** Databricks automatically tracks version history for every notebook without requiring manual action. Each time a cell is executed or the notebook is saved, a new version is created with a timestamp. Users can view the complete version history, compare versions to see differences, and restore any previous version. However, this built-in version history has limitations: it only tracks individual notebooks (not project-wide changes), does not support branching or merging, and does not integrate with CI/CD pipelines. For professional version control, use Databricks Git Folders.

### Q5: What are the different ways to execute code in a Databricks notebook?
**A:** There are several execution methods: (1) Click the **Play button** on a cell; (2) **Shift + Enter** to run a cell and move to the next; (3) **Ctrl + Enter** to run a cell and stay on it; (4) **Run All** button to execute all cells sequentially; (5) **Run menu** options for selective execution; (6) **Ctrl + Shift + Enter** to run only selected/highlighted text within a cell. Additionally, notebooks can be executed programmatically via `dbutils.notebook.run()`, the Databricks Jobs API, or the Databricks CLI.

### Q6: What happens when you attach a notebook to a cluster with a different access mode?
**A:** The access mode determines what languages and features are available. In **Single User** mode, all four languages (Python, SQL, Scala, R) are available but only the designated user can use the cluster. In **Shared** mode, Python and SQL are supported (Scala from DBR 13.3+ with Unity Catalog), and multiple users share the cluster with process isolation. In **No Isolation Shared** mode, all four languages are available but there is no process isolation. If a notebook uses a language not supported by the cluster's access mode (e.g., Scala on a Shared mode cluster), those cells will fail to execute.

### Q7: How can multiple users collaborate on the same notebook?
**A:** Databricks supports real-time collaboration on notebooks. Users can share a notebook by clicking the Share button and adding users with appropriate permission levels (Can Read, Can Run, Can Edit, Can Manage). Multiple users can edit the same notebook simultaneously with real-time updates visible to all collaborators. The Comments feature allows users to add contextual notes to specific cells. Version history tracks who made which changes and when. For team-based development with code review workflows, Git Folders (Repos) provide a more structured collaboration model.

### Q8: What is the purpose of the Table of Contents feature in notebooks?
**A:** The Table of Contents is automatically generated from Markdown headings (H1, H2, H3, etc.) in the notebook's documentation cells (%md). It appears in the left sidebar and provides clickable navigation links to jump to any section. This is essential for large notebooks with many sections, as it enables quick navigation without scrolling. Best practice is to structure notebooks with clear Markdown headings and documentation cells to make the Table of Contents useful for both the author and anyone reviewing the notebook.

---

*End of lesson*