# Databricks Magic Commands: Complete Guide

## Introduction to Magic Commands

Welcome back. In this lesson we are going to look at magic commands.

### What are Magic Commands?

Databricks offers a number of **magic commands** to help interact with notebook cells to achieve specific tasks.

We've already seen a couple of these in the last lesson, but let me take you through some of the most commonly used magic commands in this lesson.

---

## Overview of Magic Commands

### Language-Switching Magic Commands

| Magic Command | Purpose |
|--------------|---------|
| `%python` | Switch cell to Python |
| `%sql` | Switch cell to SQL |
| `%scala` | Switch cell to Scala |
| `%r` | Switch cell to R |

**Benefits:**
- Create a single notebook with code in multiple languages
- Powerful for mixed-language workflows

### Documentation Magic Command

| Magic Command | Purpose |
|--------------|---------|
| `%md` | Create Markdown cells |

**Capabilities:**
- Add documentation to your code
- Create headings and structure
- Add images and links using Markdown language

### File System Magic Command

| Magic Command | Purpose |
|--------------|---------|
| `%fs` | Interact with Databricks File System |

**Capabilities:**
- List files
- Copy files from one folder to another
- Move files between folders
- Execute basic file system commands

### Shell Magic Command

| Magic Command | Purpose |
|--------------|---------|
| `%sh` | Run shell commands directly in notebook |

**Capabilities:**
- View running processes on the cluster
- Install new packages
- Execute any shell command on the driver node

### Python Package Management

| Magic Command | Purpose |
|--------------|---------|
| `%pip` | Manage Python libraries |

**Capabilities:**
- Install Python packages from PyPI or other sources
- Manage Python environment within the notebook

### Notebook Import Magic Command

| Magic Command | Purpose |
|--------------|---------|
| `%run` | Include/import another notebook into current notebook |

**Benefits:**
- Define environment variables in separate notebooks
- Create reusable common functions
- Modularize code
- Avoid code duplication
- Keep notebooks maintainable

**Industry Usage:** One of the most commonly used magic commands in the industry.

---

## Practical Examples

### Setup

**Notebook Configuration:**
- Notebook name: `02.magic_commands`
- Default language: Python
- Cluster: Attached and running
- Ready to execute commands

**Note:** We've already covered language-switching (`%python`, `%sql`, `%scala`, `%r`) and Markdown (`%md`) commands, so we'll focus on the other four magic commands.

---

## 1. File System Magic Command (`%fs`)

### Purpose

Interact with the Databricks File System (DBFS).

### Basic Syntax

```python
%fs
ls /
```

**Alternative (single line):**
```python
%fs ls /
```

**Note:** Both versions work the same way. The cell must start with `%fs`.

### Example 1: List Home Directory

```python
%fs
ls /
```

**Output:** Shows all files and folders in the home directory.

### Example 2: List Databricks Datasets

```python
%fs
ls /databricks-datasets
```

**Alternative syntax:**
```python
%fs
ls dbfs:/databricks-datasets
```

**Note:** You can use `dbfs:` as a prefix or omit it—both work.

**What's Available:**

Databricks provides numerous datasets for practice and pet projects:
- COVID-related data
- Airlines data
- Amazon data
- Bike sharing data
- And more

**Encouragement:** Feel free to explore and play with these datasets!

### Common File System Commands

| Command | Purpose | Example |
|---------|---------|---------|
| `ls` | List files/folders | `%fs ls /path` |
| `cp` | Copy file/folder | `%fs cp /source /destination` |
| `mv` | Move file/folder | `%fs mv /source /destination` |
| `rm` | Remove file/folder | `%fs rm /path` |
| `head` | View file contents | `%fs head /path/file.txt` |

**Key Point:** Any file system command can be used, as long as the cell starts with `%fs`.

---

## 2. Shell Magic Command (`%sh`)

### Purpose

Run shell commands on your driver node.

### Basic Syntax

```python
%sh
<shell command>
```

### Example: View Running Processes

```python
%sh
ps
```

**Output:** Shows all processes running on the driver node.

**Processes you might see:**
- R
- Python
- Java
- And more

### Common Use Cases

- View system processes
- Check system resources
- Install system packages
- Execute any shell command available on the driver node

---

## 3. Pip Magic Command (`%pip`)

### Purpose

Install and manage Python libraries within the notebook environment.

### Installing from PyPI or Other Sources

You can install any Python library from PyPI or other sources to change your environment.

### Example 1: List Installed Libraries

```python
%pip list
```

**Output:** Shows all installed Python libraries.

**Common libraries you'll see:**
- Seaborn
- Pandas
- NumPy
- And many more

### Example 2: Install New Library

```python
%pip install faker
```

**What is Faker?**
A library that lets you create dummy data to test applications.

**Execution:** Running this command will install the `faker` library in your notebook environment.

### Common Pip Commands

| Command | Purpose | Example |
|---------|---------|---------|
| `%pip install <package>` | Install a package | `%pip install pandas` |
| `%pip list` | List installed packages | `%pip list` |
| `%pip uninstall <package>` | Uninstall a package | `%pip uninstall faker` |
| `%pip show <package>` | Show package info | `%pip show numpy` |

---

## 4. Run Magic Command (`%run`)

### Purpose

Include or import another notebook into your current notebook.

### Use Case: Code Modularization

**Scenario:**
- Create a notebook with environment variables
- Create another notebook with common functions
- Include these in multiple notebooks without code duplication

**Benefits:**
- ✅ Modularize code
- ✅ Avoid duplication
- ✅ Maintain code in one place
- ✅ Include in any notebook as needed

---

### Practical Demonstration

#### Step 1: Create the Child Notebook

**Notebook name:** `02.1.environment_variables_and_functions`

**Content - Environment Variable:**

```python
# Define environment variable
env = "dev"
```

**Content - Function:**

```python
# Function to print environment information
def print_env_info():
    import sys
    import os
    
    python_version = sys.version
    databricks_runtime = os.environ.get('DATABRICKS_RUNTIME_VERSION', 'N/A')
    
    print(f"Python Version: {python_version}")
    print(f"Databricks Runtime Version: {databricks_runtime}")
```

**Note:** You don't need to execute the code in the child notebook. It will run when included in the main notebook.

#### Step 2: Include Child Notebook in Main Notebook

**Using Full Path:**

```python
%run "/Users/cloudboxacademy@gmail.com/db-course/db01-databricks-lakehouse-platform/02.1.environment_variables_and_functions"
```

**How to get the path:**
1. Go to the child notebook
2. Click the three dots (...)
3. Select **"Copy Path"** or **"Copy URL"**
4. Use the full path

**Important:** If the notebook name contains spaces, enclose the entire path in quotes (double or single).

#### Step 3: Test the Included Code

**Test Environment Variable:**

```python
print(env)
```

**Output:** `dev`

**Test Function:**

```python
print_env_info()
```

**Expected Output:**
```
Python Version: 3.x.x
Databricks Runtime Version: 15.4
```

**Verification:** The runtime version matches what's shown on the cluster (15.4 in this example).

---

### Using Relative Paths

#### Why Use Relative Paths?

**Problem with Full Paths:**
- Not suitable for production projects
- Difficult when moving between environments
- Hard to maintain across different workspaces

**Solution:** Use relative paths.

#### Relative Path Syntax

**Same Folder:**
```python
%run "./02.1.environment_variables_and_functions"
```

**One Level Up:**
```python
%run "../folder-name/notebook-name"
```

**Navigation Rules:**

| Path Notation | Meaning |
|--------------|---------|
| `./` | Current directory |
| `../` | One directory up |
| `../../` | Two directories up |

#### Example with Relative Path

```python
%run "./02.1.environment_variables_and_functions"
```

**Testing:**

```python
# Test environment variable
print(env)
# Output: dev

# Test function
print_env_info()
# Output: Python and Databricks version info
```

**Result:** Everything works as expected with relative paths!

---

## Best Practices

### 1. File System Commands (`%fs`)

- Use for basic file operations
- Explore Databricks datasets for learning
- Remember: `dbfs:` prefix is optional

### 2. Shell Commands (`%sh`)

- Use for system-level operations
- Check processes and system status
- Install system packages when needed

### 3. Python Packages (`%pip`)

- Install packages as needed
- List packages to check what's available
- Manage environment within notebook scope

### 4. Notebook Inclusion (`%run`)

**Do:**
- ✅ Use relative paths for portability
- ✅ Centralize common variables and functions
- ✅ Modularize your code
- ✅ Create reusable components

**Don't:**
- ❌ Use full paths in production
- ❌ Duplicate code across notebooks
- ❌ Forget to enclose paths with spaces in quotes

### Modularization Strategy

**Common Pattern:**

1. **Create utility notebooks:**
   - Environment variables
   - Common functions
   - Configuration settings
   - Shared utilities

2. **Include in working notebooks:**
   ```python
   %run "./utils/environment_setup"
   %run "./utils/common_functions"
   ```

3. **Benefits:**
   - Single source of truth
   - Easy updates
   - Consistent across projects
   - Better maintainability

---

## Summary

### Magic Commands Covered:

| Magic Command | Purpose | Key Use Case |
|--------------|---------|--------------|
| `%python`, `%sql`, `%scala`, `%r` | Language switching | Multi-language notebooks |
| `%md` | Markdown cells | Documentation |
| `%fs` | File system operations | List, copy, move files |
| `%sh` | Shell commands | System operations |
| `%pip` | Python package management | Install libraries |
| `%run` | Include notebooks | Code modularization |

### Key Takeaways:

1. ✅ Magic commands enable powerful notebook functionality
2. ✅ `%run` is one of the most commonly used in industry
3. ✅ Use relative paths for better portability
4. ✅ Modularize code with separate notebooks
5. ✅ Avoid code duplication
6. ✅ Keep notebooks maintainable and organized

### What We've Learned:

- How to use each magic command
- Practical examples for each command
- Best practices for code organization
- How to modularize notebooks effectively
- Path management (full vs. relative)

With these magic commands, you now have powerful tools to create efficient, maintainable, and well-organized Databricks notebooks!

---

*End of lesson*