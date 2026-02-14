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

*End of lesson*