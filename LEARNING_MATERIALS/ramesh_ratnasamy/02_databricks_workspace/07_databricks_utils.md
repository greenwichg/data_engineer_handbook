# Databricks Utilities (dbutils): Complete Guide

## Introduction to Databricks Utilities

Welcome back. In this lesson we'll explore **Databricks Utilities**.

### What are Databricks Utilities?

Databricks utilities make it easier to **combine different types of tasks in a single notebook**.

**Example Use Case:**
Combine file operations with ETL tasks in a single notebook.

### Important Limitation:

**Supported Languages:**
- ✅ Python cells
- ✅ Scala cells
- ✅ R cells

**Not Supported:**
- ❌ SQL cells

---

## Overview of Databricks Utilities

Databricks has been developing numerous utilities, with some in preview and others generally available.

### Most Commonly Used Utilities:

#### 1. File System Utilities (`dbutils.fs`)

**Purpose:**
- Access Databricks File System from a notebook
- Perform various file system level operations

**Comparison to Magic Commands:**
- Functionality: Same as `%fs` magic command
- Flexibility: **More flexible than magic commands**

#### 2. Secrets Utilities (`dbutils.secrets`)

**Purpose:**
- Get secret values from secrets stored in secret scopes
- Backed by Databricks or Azure Key Vault

**Use Case:**
- Securely access credentials and API keys
- Avoid hardcoding sensitive information

#### 3. Widget Utilities (`dbutils.widgets`)

**Purpose:**
- Parameterize notebooks
- Allow runtime parameter passing

**Use Cases:**
- Calling notebook passes parameters
- External applications (e.g., Azure Data Factory pipeline) pass values at runtime

**Benefits:**
- Makes notebooks reusable
- Dynamic execution based on parameters

#### 4. Notebook Utilities (`dbutils.notebook`)

**Purpose:**
- Invoke one notebook from another
- Chain notebooks together

**⚠️ Current Status:**
- **No longer recommended**
- Databricks wants users to avoid this if possible

**Alternative:**
- Use **Databricks Workflows** instead
- Constantly being improved
- Easier to use
- Better monitoring capabilities

---

## Practical Examples

### Setup

**Notebook Configuration:**
- Notebook name: `03.databricks_utilities`
- Default language: Python
- Cluster: Attached and running
- Ready to execute commands

---

## File System Utilities Deep Dive

### Recall: Magic Command Approach

From the last lesson, we used the `%fs` magic command:

```python
%fs
ls /
```

**What it does:**
Lists files and folders within the Databricks root folder.

**Behind the scenes:**
This magic command uses the `dbutils.fs` package.

---

### Using dbutils.fs Directly

Instead of the `%fs` magic command, we can call the `dbutils.fs` package directly.

#### Example 1: Basic File Listing

**Magic Command Version:**
```python
%fs ls /
```

**dbutils Version:**
```python
dbutils.fs.ls("/")
```

**Important Notes:**
- Folder path must be passed in quotes
- Returns a Python list
- Output is not easily readable in raw format

**Output Example:**
```
[FileInfo(path='dbfs:/databricks-datasets/', name='databricks-datasets/', size=0, ...),
 FileInfo(path='dbfs:/tmp/', name='tmp/', size=0, ...),
 ...]
```

---

### The Display Command

#### Purpose

Make data output more readable and visual.

#### Characteristics:

**Availability:**
- ✅ Python cells
- ✅ Scala cells
- ✅ R cells
- ❌ SQL cells (not available)

**What it does:**
Visualizes data in a more readable table format.

#### Example: Using Display with dbutils

```python
display(dbutils.fs.ls("/"))
```

**Result:**
- Output is now in a readable table format
- Similar to the `%fs` magic command output
- Easy to scan and understand

---

## Magic Commands vs. dbutils: Which to Use?

### Comparison Table

| Aspect | `%fs` Magic Command | `dbutils.fs` |
|--------|-------------------|--------------|
| **Best For** | Quick ad hoc file system queries | Programmatic tasks |
| **Flexibility** | Limited | Highly flexible |
| **Output** | Formatted display | Python list (programmable) |
| **Use with Code** | Difficult to process results | Easy to process with Python/Scala/R |
| **Power** | Basic operations | Advanced programmatic operations |

### When to Use Each:

**Use `%fs` Magic Command:**
- ✅ Quick file browsing
- ✅ Simple one-off queries
- ✅ When you just need to view results

**Use `dbutils.fs`:**
- ✅ Programmatic file operations
- ✅ Need to process results with code
- ✅ Building automated workflows
- ✅ Complex file system tasks

---

## Advanced Example: Programmatic File Processing

### Scenario

Count the number of files and folders separately in the `/databricks-datasets` directory.

### Step 1: List Files with Magic Command

```python
%fs ls /databricks-datasets
```

**Result:**
- 55 rows total
- Folders end with `/` (slash)
- Files don't end with `/`
- Example folder: `databricks-datasets/`
- Example file: `README.md`

### Step 2: Programmatic Solution with dbutils

#### Get the List

```python
# Get list of items
items = dbutils.fs.ls("/databricks-datasets")
```

**What we have:**
- Variable `items` contains a Python list
- Each item in the list represents a file or folder
- Now we can use Python to process this list

#### Process the List

```python
# Initialize counters
folder_count = 0
file_count = 0

# Iterate through items
for item in items:
    if item.name.endswith('/'):
        folder_count += 1
    else:
        file_count += 1

# Print results
print(f"Total folders: {folder_count}")
print(f"Total files: {file_count}")
```

**How it works:**
1. Loop through each item in the list
2. Check if item name ends with `/` (indicates folder)
3. Count folders and files separately
4. Print the totals

**Output:**
```
Total folders: 53
Total files: 2
```

### Key Insight

**Flexibility of Databricks Utilities:**

You can use Databricks utilities together with programming languages (Python, Scala, or R) to:
- Process utility outputs
- Create complex workflows
- Automate tasks
- Build sophisticated data pipelines

This demonstrates the **power and flexibility** of `dbutils` over simple magic commands.

---

## Getting Help on Databricks Utilities

Instead of memorizing all utilities and methods, learn how to access the built-in help system.

### View All Available Utilities

```python
dbutils.help()
```

**Output:**
- Lists all available utilities
- Shows which are experimental/preview
- Shows which are generally available (GA)

**Status Indicators:**
- **Experimental**: Early feature, may change
- **Preview**: Testing phase, near completion
- **Generally Available (GA)**: Production-ready, stable

### Get Help on Specific Utility

#### Example: File System Utility

```python
dbutils.fs.help()
```

**Output:**
- Lists all methods available within the file system utility
- Shows descriptions for each method

**Available Methods Include:**
- Mount/unmount file systems
- Standard operations: `cp` (copy), `mv` (move), `rm` (remove)
- List operations: `ls`
- And many more

### Get Help on Specific Method

#### Example: Copy Method

```python
dbutils.fs.help("cp")
```

**Output:**
- Description of the method
- Syntax/signature
- Example usage
- Parameters required

**Sample Help Output:**
```
cp(from: String, to: String, recurse: boolean = false): boolean

Copy a file or directory, optionally recursively

Example: dbutils.fs.cp("/mnt/source/file.txt", "/mnt/target/file.txt")
```

### Help System Pattern

**General Pattern:**
```python
# View all utilities
dbutils.help()

# View methods in a utility
dbutils.<utility>.help()

# View help for a specific method
dbutils.<utility>.help("<method_name>")
```

**Examples:**
```python
# All utilities
dbutils.help()

# File system methods
dbutils.fs.help()

# Specific method
dbutils.fs.help("cp")

# Secrets utility methods
dbutils.secrets.help()

# Widget utility methods
dbutils.widgets.help()
```

---

## Common dbutils.fs Methods

### File Operations

| Method | Purpose | Example |
|--------|---------|---------|
| `ls(path)` | List files/folders | `dbutils.fs.ls("/")` |
| `cp(from, to)` | Copy file/folder | `dbutils.fs.cp("/source", "/dest")` |
| `mv(from, to)` | Move file/folder | `dbutils.fs.mv("/old", "/new")` |
| `rm(path, recurse)` | Remove file/folder | `dbutils.fs.rm("/path", True)` |
| `head(path)` | Read file contents | `dbutils.fs.head("/file.txt")` |
| `put(path, contents)` | Write to file | `dbutils.fs.put("/file.txt", "data")` |

### Directory Operations

| Method | Purpose | Example |
|--------|---------|---------|
| `mkdirs(path)` | Create directory | `dbutils.fs.mkdirs("/newdir")` |

### Mount Operations

| Method | Purpose | Example |
|--------|---------|---------|
| `mount(source, mount_point)` | Mount storage | `dbutils.fs.mount(...)` |
| `unmount(mount_point)` | Unmount storage | `dbutils.fs.unmount("/mnt/data")` |
| `mounts()` | List all mounts | `dbutils.fs.mounts()` |

---

## Best Practices

### 1. Choose the Right Tool

**For Quick Tasks:**
```python
# Use magic commands
%fs ls /databricks-datasets
```

**For Programmatic Tasks:**
```python
# Use dbutils
items = dbutils.fs.ls("/databricks-datasets")
# Process items with Python code
```

### 2. Use Display for Readability

```python
# Better visualization
display(dbutils.fs.ls("/"))
```

### 3. Leverage Built-in Help

```python
# Don't memorize everything
# Use the help system
dbutils.fs.help("cp")
```

### 4. Combine with Programming Languages

```python
# Powerful combination
files = dbutils.fs.ls("/path")
filtered = [f for f in files if f.size > 1000000]
display(filtered)
```

### 5. Error Handling

```python
# Add error handling for production code
try:
    result = dbutils.fs.ls("/path")
    display(result)
except Exception as e:
    print(f"Error: {e}")
```

---

## Utilities Summary

### File System Utilities (`dbutils.fs`)
- **Purpose**: File system operations
- **Status**: Generally Available
- **Use**: Production-ready

### Secrets Utilities (`dbutils.secrets`)
- **Purpose**: Secure credential management
- **Status**: Generally Available
- **Use**: Production-ready

### Widget Utilities (`dbutils.widgets`)
- **Purpose**: Notebook parameterization
- **Status**: Generally Available
- **Use**: Production-ready

### Notebook Utilities (`dbutils.notebook`)
- **Purpose**: Notebook chaining
- **Status**: ⚠️ No longer recommended
- **Alternative**: Use Databricks Workflows

---

## Key Takeaways

### What We've Learned:

1. ✅ **Databricks Utilities** enable programmatic task combinations
2. ✅ **dbutils.fs** is more flexible than `%fs` magic commands
3. ✅ Use **display()** for readable output
4. ✅ **Help system** provides comprehensive documentation
5. ✅ Combine utilities with Python/Scala/R for powerful workflows

### Remember:

- **Quick tasks** → Use magic commands (`%fs`)
- **Programmatic tasks** → Use dbutils (`dbutils.fs`)
- **Can't remember syntax?** → Use help (`dbutils.fs.help()`)
- **Need to process results?** → dbutils returns programmable data structures

### Self-Exploration:

Using the help system, you can now explore:
- All available utilities
- All methods within each utility
- Specific method syntax and examples

This empowers you to discover and use utilities independently!

---

## Databricks Utilities Overview Diagram

```
┌──────────────────────────────────────────────────────────────────────┐
│                       dbutils                                         │
│                                                                       │
│  ┌─────────────┐  ┌──────────────┐  ┌──────────────┐  ┌───────────┐ │
│  │  dbutils.fs  │  │dbutils.secrets│  │dbutils.widgets│  │dbutils.   │ │
│  │              │  │              │  │              │  │ notebook  │ │
│  │  File System │  │  Secrets     │  │  Parameters  │  │ Chaining  │ │
│  │  Operations  │  │  Management  │  │  & Widgets   │  │ (Legacy)  │ │
│  │              │  │              │  │              │  │           │ │
│  │  - ls        │  │  - get       │  │  - text      │  │  - run    │ │
│  │  - cp        │  │  - list      │  │  - dropdown  │  │  - exit   │ │
│  │  - mv        │  │  - listScopes│  │  - combobox  │  │           │ │
│  │  - rm        │  │              │  │  - multiselect│  │           │ │
│  │  - mkdirs    │  │              │  │  - get       │  │           │ │
│  │  - head      │  │              │  │  - remove    │  │           │ │
│  │  - put       │  │              │  │  - removeAll │  │           │ │
│  │  - mount     │  │              │  │              │  │           │ │
│  │  - unmount   │  │              │  │              │  │           │ │
│  │  - mounts    │  │              │  │              │  │           │ │
│  └─────────────┘  └──────────────┘  └──────────────┘  └───────────┘ │
│                                                                       │
│  Status:  GA          GA              GA              Deprecated      │
│                                                    (Use Workflows)    │
└──────────────────────────────────────────────────────────────────────┘
```

---

## dbutils.fs vs. %fs Decision Flow

```
┌───────────────────────────────┐
│  Need to interact with DBFS?  │
└──────────────┬────────────────┘
               │
       ┌───────┴────────┐
       ▼                 ▼
┌─────────────┐   ┌──────────────────┐
│ Quick check │   │ Programmatic     │
│ / browse?   │   │ processing?      │
└──────┬──────┘   └────────┬─────────┘
       │                    │
       ▼                    ▼
┌─────────────┐   ┌──────────────────┐
│  Use %fs    │   │  Use dbutils.fs  │
│             │   │                  │
│  %fs ls /   │   │  items =         │
│             │   │   dbutils.fs.ls  │
│  Simple,    │   │   ("/path")      │
│  formatted  │   │                  │
│  output     │   │  Process with    │
│             │   │  Python/Scala/R  │
└─────────────┘   └──────────────────┘
```

---

## CONCEPT GAP: dbutils.secrets Deep Dive

Secret management is critical for production data engineering and frequently tested:

### Secret Scopes

Databricks supports two types of secret scopes:

| Feature | Databricks-backed Scope | Azure Key Vault-backed Scope |
|---------|------------------------|------------------------------|
| **Storage** | Encrypted in Databricks | Stored in Azure Key Vault |
| **Management** | Via Databricks CLI/API | Via Azure Key Vault portal |
| **Access control** | Databricks ACLs | Azure RBAC + Databricks ACLs |
| **Best for** | Simple use cases, non-Azure | Enterprise Azure deployments |
| **Creation** | `databricks secrets create-scope` | Link to existing Key Vault |

### Common dbutils.secrets Methods

```python
# List all available secret scopes
dbutils.secrets.listScopes()

# List secrets in a scope (shows names only, not values)
dbutils.secrets.list("my-scope")

# Get a secret value
password = dbutils.secrets.get(scope="my-scope", key="db-password")

# IMPORTANT: Secret values are REDACTED in notebook output
# print(password) shows [REDACTED] in cell output
```

### Security Features

- Secret values are automatically **redacted** in notebook output -- printing a secret shows `[REDACTED]`.
- Secrets are only accessible to users with appropriate ACL permissions on the scope.
- Secrets are encrypted at rest and in transit.
- Never hardcode credentials in notebooks; always use `dbutils.secrets`.

---

## CONCEPT GAP: dbutils.widgets Deep Dive

Widget utilities are essential for creating parameterized, reusable notebooks:

### Widget Types

```
┌────────────────────────────────────────────────────────────────┐
│                    WIDGET TYPES                                 │
│                                                                 │
│  ┌──────────────┐  ┌──────────────┐                            │
│  │  TEXT         │  │  DROPDOWN    │                            │
│  │              │  │              │                            │
│  │  Free-form   │  │  Select one  │                            │
│  │  text input  │  │  from list   │                            │
│  └──────────────┘  └──────────────┘                            │
│                                                                 │
│  ┌──────────────┐  ┌──────────────┐                            │
│  │  COMBOBOX    │  │  MULTISELECT │                            │
│  │              │  │              │                            │
│  │  Text input  │  │  Select many │                            │
│  │  + dropdown  │  │  from list   │                            │
│  └──────────────┘  └──────────────┘                            │
└────────────────────────────────────────────────────────────────┘
```

### Widget Usage Patterns

```python
# Create widgets
dbutils.widgets.text("start_date", "2024-01-01", "Start Date")
dbutils.widgets.dropdown("env", "dev", ["dev", "staging", "prod"], "Environment")
dbutils.widgets.combobox("table_name", "default", ["sales", "orders", "users"])
dbutils.widgets.multiselect("regions", "US", ["US", "EU", "APAC"], "Regions")

# Get values
start_date = dbutils.widgets.get("start_date")
env = dbutils.widgets.get("env")

# Use in SQL cells
# %sql
# SELECT * FROM ${env}_catalog.schema.table
# WHERE date >= '${start_date}'

# Passing parameters via dbutils.notebook.run()
result = dbutils.notebook.run("./child_notebook", 60, {"env": "prod", "start_date": "2024-06-01"})

# Cleanup
dbutils.widgets.removeAll()
```

---

## CONCEPT GAP: dbutils.notebook vs. Databricks Workflows

Understanding why `dbutils.notebook` is deprecated in favor of Workflows:

| Feature | dbutils.notebook.run() | Databricks Workflows |
|---------|----------------------|---------------------|
| **Orchestration** | Code-based, in notebook | Visual DAG UI or YAML/JSON |
| **Error handling** | Manual try/except | Built-in retry policies, alerts |
| **Monitoring** | Manual logging | Full run history, UI dashboards |
| **Scheduling** | Requires external trigger | Built-in cron scheduler |
| **Parallelism** | Manual threading | Native parallel task support |
| **Parameters** | Pass as dict argument | Job parameters, task values |
| **Dependencies** | Manual management | Declarative task dependencies |
| **Timeout** | Per-notebook timeout | Per-task and per-job timeout |
| **Notifications** | Not built-in | Email, Slack, webhook alerts |

```python
# Legacy approach (dbutils.notebook) -- still works but NOT recommended
result = dbutils.notebook.run("./etl_notebook", timeout_seconds=3600, arguments={"date": "2024-01-01"})

# The child notebook returns a value using:
dbutils.notebook.exit("success")
```

---

## CONCEPT GAP: display() Function Details

The `display()` function is unique to Databricks and deserves deeper coverage:

- **Works with**: DataFrames (Spark and pandas), lists, dbutils output, MLflow objects.
- **Features**: Renders tabular data with sortable columns, built-in charting (bar, line, scatter, pie, map, etc.), download to CSV, and pagination.
- **Limitation**: `display()` is not available in SQL cells (SQL results auto-render).
- **Performance**: `display()` on a Spark DataFrame triggers a `.collect()` behind the scenes, pulling data to the driver. By default, it renders up to 1,000 rows. Use `.limit(n)` before `display()` for large datasets.
- **Alternative**: `displayHTML()` renders custom HTML content in a cell output.

```python
# Basic display
display(df)

# Display with profile (data profiling / summary statistics)
display(df.summary())

# Display HTML
displayHTML("<h1>Custom HTML Output</h1>")
```

---

## KEY INTERVIEW QUESTIONS AND ANSWERS

### Q1: What is the difference between dbutils.fs and the %fs magic command?
**A:** Both provide access to DBFS, but they serve different purposes. `%fs` is a magic command for quick, ad hoc file system operations -- it produces formatted output directly in the cell. `dbutils.fs` is a programmatic API that returns Python/Scala/R data structures (lists of FileInfo objects) that can be processed with code -- filtering, counting, looping, etc. Use `%fs` for quick exploration and `dbutils.fs` when you need to programmatically work with file system results. Behind the scenes, `%fs` is a shortcut for `dbutils.fs`.

### Q2: How do Databricks Secrets work and why are they important?
**A:** Databricks Secrets provide secure credential management through `dbutils.secrets`. Secrets are stored in **secret scopes** (either Databricks-backed with encrypted storage, or Azure Key Vault-backed for enterprise deployments). You retrieve secrets using `dbutils.secrets.get(scope, key)`. A critical security feature is that secret values are **automatically redacted** in notebook output -- even `print(secret_value)` shows `[REDACTED]`. This prevents accidental exposure of credentials in shared notebooks or logs. Secrets should always be used instead of hardcoding passwords, API keys, or connection strings.

### Q3: What are the four types of widgets in dbutils.widgets?
**A:** The four widget types are: (1) **text** -- free-form text input for arbitrary values; (2) **dropdown** -- single selection from a predefined list; (3) **combobox** -- combination of text input and dropdown, allowing either selection or custom input; (4) **multiselect** -- allows selecting multiple values from a list. All widget types take a name, default value, and label. Values are retrieved with `dbutils.widgets.get("name")`. Widgets appear as input controls at the top of the notebook and can be populated by external callers via `dbutils.notebook.run()` or Databricks Jobs.

### Q4: Why is dbutils.notebook no longer recommended?
**A:** Databricks recommends using **Databricks Workflows** instead of `dbutils.notebook.run()` for orchestrating multi-notebook pipelines. Workflows provide a visual DAG-based interface, built-in retry policies, scheduling, monitoring dashboards, alerting (email/Slack/webhook), native parallel task execution, and declarative task dependencies. `dbutils.notebook.run()` requires manual error handling, has no built-in scheduling, lacks a monitoring UI, and makes orchestration logic harder to maintain. While `dbutils.notebook.run()` still functions, Workflows are the modern, production-grade alternative.

### Q5: How do you use the display() function and what are its limitations?
**A:** `display()` is a Databricks-specific function that renders data in a formatted, interactive table with features like sortable columns, built-in charting (bar, line, scatter, pie, map), CSV download, and pagination. It works with Spark DataFrames, pandas DataFrames, lists, and dbutils output. Key limitations: (1) it is not available in SQL cells (SQL results auto-render); (2) it triggers a `.collect()` on Spark DataFrames, pulling data to the driver node; (3) it renders up to 1,000 rows by default; (4) for very large datasets, use `.limit(n)` first to avoid memory issues on the driver.

### Q6: How can you find out what methods are available on dbutils.fs?
**A:** Use the built-in help system with a three-level pattern: (1) `dbutils.help()` lists all available utility categories; (2) `dbutils.fs.help()` lists all methods within the file system utility; (3) `dbutils.fs.help("cp")` shows detailed help for a specific method including its signature, description, and example usage. This pattern works for all utility categories: `dbutils.secrets.help()`, `dbutils.widgets.help()`, etc. The help system eliminates the need to memorize all available methods and their parameters.

### Q7: What are mount operations in dbutils.fs and are they still recommended?
**A:** Mount operations (`dbutils.fs.mount`, `dbutils.fs.unmount`, `dbutils.fs.mounts`) allow you to map external cloud storage (ADLS Gen2, S3, GCS) to a DBFS path (e.g., `/mnt/data`). Once mounted, you can access external storage using DBFS paths instead of full cloud storage URLs. However, mounts are **legacy and no longer recommended** for Unity Catalog-enabled workspaces. The modern approach is to use **external locations** and **storage credentials** managed through Unity Catalog, which provides better security, auditing, and governance. Mounts bypass Unity Catalog's access controls.

### Q8: In which notebook cell languages can you use dbutils?
**A:** dbutils is available in **Python**, **Scala**, and **R** cells. It is **not available in SQL cells**. If you need to use dbutils functionality from a SQL context, you can create a Python cell to perform the dbutils operation and store results in a temporary view or variable, then access that from SQL. The syntax is identical across Python and Scala (`dbutils.fs.ls("/")`) but R uses a slightly different calling convention. Most data engineers use dbutils from Python cells since Python is the most common language in Databricks data engineering.

---

*End of lesson*