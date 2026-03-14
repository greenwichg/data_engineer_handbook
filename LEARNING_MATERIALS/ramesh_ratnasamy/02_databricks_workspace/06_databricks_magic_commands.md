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

## Magic Command Reference Diagram

```
┌─────────────────────────────────────────────────────────────────────┐
│                    DATABRICKS MAGIC COMMANDS                         │
│                                                                      │
│  ┌──────────────────────────────────────────────────────────────┐   │
│  │  LANGUAGE SWITCHING                                          │   │
│  │  ┌──────────┐ ┌──────┐ ┌────────┐ ┌────┐                   │   │
│  │  │ %python  │ │ %sql │ │ %scala │ │ %r │                   │   │
│  │  └──────────┘ └──────┘ └────────┘ └────┘                   │   │
│  └──────────────────────────────────────────────────────────────┘   │
│                                                                      │
│  ┌──────────────────────────────────────────────────────────────┐   │
│  │  DOCUMENTATION                                               │   │
│  │  ┌──────┐                                                    │   │
│  │  │ %md  │  Markdown rendering for documentation              │   │
│  │  └──────┘                                                    │   │
│  └──────────────────────────────────────────────────────────────┘   │
│                                                                      │
│  ┌──────────────────────────────────────────────────────────────┐   │
│  │  SYSTEM INTERACTION                                          │   │
│  │  ┌──────┐  ┌──────┐  ┌──────┐                               │   │
│  │  │ %fs  │  │ %sh  │  │ %pip │                               │   │
│  │  │ DBFS │  │Shell │  │PyPI  │                               │   │
│  │  └──────┘  └──────┘  └──────┘                               │   │
│  └──────────────────────────────────────────────────────────────┘   │
│                                                                      │
│  ┌──────────────────────────────────────────────────────────────┐   │
│  │  NOTEBOOK OPERATIONS                                         │   │
│  │  ┌──────┐                                                    │   │
│  │  │ %run │  Execute another notebook in current context       │   │
│  │  └──────┘                                                    │   │
│  └──────────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────────┘
```

---

## %run Execution Flow

```
┌─────────────────────────┐
│   PARENT NOTEBOOK        │
│                          │
│  Cell 1: Setup code      │
│                          │
│  Cell 2: %run "./child"  │──────┐
│          (blocks here)   │      │
│                          │      ▼
│                          │   ┌─────────────────────┐
│                          │   │   CHILD NOTEBOOK      │
│                          │   │                       │
│                          │   │  env = "dev"          │
│                          │   │  def my_func(): ...   │
│                          │   │                       │
│                          │   │  (executes all cells) │
│                          │   └───────────┬───────────┘
│                          │               │
│  Cell 3: print(env)      │◄──────────────┘
│  (can use child vars!)   │   Variables injected into
│  Output: "dev"           │   parent's execution context
│                          │
│  Cell 4: my_func()       │
│  (can use child funcs!)  │
└─────────────────────────┘
```

---

## CONCEPT GAP: %run vs. import Statement

A common source of confusion is the difference between `%run` and Python's `import`:

| Feature | %run | Python import |
|---------|------|---------------|
| **Executes all cells** | Yes | No (only module-level code) |
| **Shares variables** | Yes (injects into current context) | No (separate module namespace) |
| **Works with notebooks** | Yes | No (requires .py files on sys.path) |
| **Works with .py files** | No | Yes |
| **Relative paths** | `./notebook_name` | Requires sys.path configuration |
| **Can pass parameters** | No (use widgets instead) | N/A |
| **Circular references** | Can cause infinite loops | Python handles with lazy loading |

- To use Python `import` with Databricks, the file must be a `.py` file stored in the workspace or a Git Folder, not a notebook.
- Best practice: Use `%run` for notebook-to-notebook inclusion and Python `import` for reusable Python modules.

---

## CONCEPT GAP: %pip vs. Cluster Libraries

There are two ways to install Python packages on a Databricks cluster:

| Feature | %pip (Notebook-scoped) | Cluster Libraries |
|---------|----------------------|-------------------|
| **Scope** | Current notebook only | All notebooks on the cluster |
| **Persistence** | Lost when notebook detaches | Persists until cluster restarts |
| **Installation** | Via notebook cell | Via Cluster UI > Libraries tab |
| **Restart needed** | Python process restarts in notebook | Cluster restart may be needed |
| **Best for** | Quick experiments, per-notebook deps | Shared dependencies across team |
| **Sources** | PyPI, custom index, wheel files | PyPI, Maven, CRAN, JAR, wheel, egg |

- `%pip install` in a notebook causes the Python interpreter to restart, clearing all variables. Place `%pip` commands at the **top** of your notebook before any other code.
- For production, prefer cluster libraries or init scripts for consistent environments across all users.

---

## CONCEPT GAP: %sh Security Considerations

Understanding `%sh` limitations is important for security-conscious organizations:

- `%sh` commands execute **only on the driver node**, not on worker nodes.
- Output and files created by `%sh` are local to the driver node's filesystem, not DBFS.
- The driver node's local filesystem is ephemeral and will be lost when the cluster terminates.
- `%sh` runs with the permissions of the cluster's OS user (typically `ubuntu` or `root`).
- In **Shared access mode** clusters, `%sh` is **disabled** for security reasons (to prevent cross-user access).
- To execute commands on all nodes (driver + workers), use init scripts instead.

---

## CONCEPT GAP: %md Advanced Markdown Features

Beyond basic headings and bullets, Databricks Markdown cells support:

```markdown
%md
## Images
![Alt text](https://example.com/image.png)

## Links
[Databricks Documentation](https://docs.databricks.com)

## Code blocks (for documentation, not execution)
```python
def example():
    return "This is documentation, not executable code"
` ` `

## Tables
| Column 1 | Column 2 |
|----------|----------|
| Value 1  | Value 2  |

## LaTeX Math
$$E = mc^2$$

## HTML (supported in some contexts)
<b>Bold text using HTML</b>
```

---

## Comprehensive Magic Commands Comparison Table

| Command | Cell Language | Runs On | Shares State | Access Mode Restrictions | Exam Frequency |
|---------|-------------|---------|-------------|------------------------|----------------|
| `%python` | Python | Driver + Workers | Yes | None | Medium |
| `%sql` | SQL | Driver + Workers | Yes | None | Medium |
| `%scala` | Scala | Driver + Workers | Yes | Not in Shared mode (pre-DBR 13.3) | Low |
| `%r` | R | Driver + Workers | Yes | Not in Shared mode | Low |
| `%md` | Markdown | N/A (rendering) | No | None | Low |
| `%fs` | DBFS CLI | Driver | No | None | Medium |
| `%sh` | Bash shell | Driver only | No | Disabled in Shared mode | Medium |
| `%pip` | pip manager | Driver | No (restarts Python) | None | High |
| `%run` | Notebook exec | Driver + Workers | Yes (injects vars) | None | High |

---

## KEY INTERVIEW QUESTIONS AND ANSWERS

### Q1: What is the difference between %fs and dbutils.fs?
**A:** Both interact with DBFS (Databricks File System), but `%fs` is a magic command designed for quick, ad hoc file operations in a single cell, while `dbutils.fs` is a programmatic API that returns Python/Scala/R data structures (like lists of FileInfo objects) that can be processed with code. Use `%fs` for simple browsing and `dbutils.fs` when you need to loop through results, filter files, or integrate file operations into a larger program. `%fs` is essentially a shorthand for `dbutils.fs` -- behind the scenes, `%fs ls /` calls `dbutils.fs.ls("/")`.

### Q2: Why is %run one of the most commonly used magic commands in industry?
**A:** `%run` enables code modularization in Databricks notebooks. In production environments, common patterns include: creating utility notebooks with shared functions, centralizing environment variables and configuration settings, and building reusable data transformation logic. By using `%run` to include these shared notebooks, teams avoid code duplication, maintain a single source of truth, and can update shared logic in one place. It is especially important because Databricks notebooks do not natively support Python `import` from other notebooks -- `%run` fills this gap.

### Q3: What happens to variables when you run %pip install in a notebook?
**A:** Running `%pip install` causes the Python interpreter in the notebook to restart, which **clears all variables, DataFrames, and imported modules** from memory. This is why `%pip` commands should always be placed at the very top of the notebook, before any other code. The installed package is scoped to the current notebook only and will not affect other notebooks on the same cluster. When the notebook is detached from the cluster, the installed package is lost.

### Q4: Can %sh commands be run on worker nodes?
**A:** No. `%sh` commands execute **only on the driver node**. To run commands on all nodes (driver and workers), use cluster-scoped or global init scripts. Files created by `%sh` are stored on the driver's local filesystem, which is ephemeral (lost when the cluster terminates) and is not the same as DBFS. Additionally, `%sh` is disabled on clusters running in Shared access mode for security reasons, as it could allow cross-user access.

### Q5: How do you use relative paths with %run?
**A:** Relative paths use `./` for the current directory and `../` for the parent directory. For example, `%run "./utils/common_functions"` runs a notebook named "common_functions" inside a "utils" subfolder relative to the current notebook's location. `%run "../shared/config"` goes up one directory level and then into "shared/config". Relative paths are preferred over absolute paths because they make notebooks portable across workspaces and environments (dev, staging, production) without path changes.

### Q6: What magic command would you use to create documentation in a notebook?
**A:** Use `%md` (Markdown) at the beginning of a cell to create documentation. It supports standard Markdown syntax including headings (#, ##, ###), bold/italic text, bullet and numbered lists, code blocks, tables, images, links, and even LaTeX math expressions. Documentation cells are essential for creating self-documenting notebooks. The rendered Markdown also automatically populates the Table of Contents in the left sidebar, enabling quick navigation in large notebooks.

### Q7: How would you install a Python package that is available only from a private PyPI repository?
**A:** Use `%pip install` with the `--index-url` or `--extra-index-url` flag to specify the private repository: `%pip install my-package --index-url https://private.pypi.org/simple/`. For authentication, you can use `%pip install my-package --index-url https://username:token@private.pypi.org/simple/`, though a more secure approach is to store credentials in Databricks Secrets and reference them: `%pip install my-package --index-url https://${TOKEN}@private.pypi.org/simple/` where TOKEN is retrieved via `dbutils.secrets.get()` in a prior cell.

### Q8: What is the default language of a notebook and how can you override it per cell?
**A:** The default language is set when creating the notebook (Python, SQL, Scala, or R) and applies to all cells unless overridden. To override the language for a specific cell, add the appropriate magic command as the **first line** of the cell: `%python`, `%sql`, `%scala`, or `%r`. Only one magic command can be used per cell, and it must be the first line. The default language can also be changed after creation by clicking the language indicator next to the notebook name. This multi-language capability is one of Databricks notebooks' most powerful features.

---

*End of lesson*