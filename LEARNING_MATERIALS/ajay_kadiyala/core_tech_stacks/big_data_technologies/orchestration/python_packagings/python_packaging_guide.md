# Python Packaging & Virtual Environments - Complete Interview Guide

A comprehensive guide to Python packaging, virtual environments, and dependency management for data engineering interviews.

---

## Table of Contents

1. [Virtual Environments](#virtual-environments)
2. [Package Management](#package-management)
3. [Project Structure](#project-structure)
4. [Creating Packages](#creating-packages)
5. [Requirements Files](#requirements-files)
6. [Docker for Python](#docker-for-python)
7. [Best Practices](#best-practices)
8. [Interview Preparation](#interview-preparation)

---

## Virtual Environments

### What is a Virtual Environment?

**Virtual Environment** = Isolated Python environment with its own packages and dependencies.

**Why use them?**
- Different projects need different package versions
- Avoid conflicts between project dependencies
- Keep global Python installation clean
- Easy to recreate environments
- Essential for reproducible data pipelines

### Types of Virtual Environments

#### 1. venv (Built-in, Python 3.3+)

```bash
# Create virtual environment
python -m venv myenv

# Activate (Linux/Mac)
source myenv/bin/activate

# Activate (Windows)
myenv\Scripts\activate

# Verify activation
which python  # Should show path to myenv/bin/python
python --version

# Install packages
pip install pandas numpy

# Deactivate
deactivate
```

#### 2. virtualenv (Third-party, More Features)

```bash
# Install virtualenv
pip install virtualenv

# Create environment
virtualenv myenv

# Create with specific Python version
virtualenv -p python3.9 myenv

# Activate (same as venv)
source myenv/bin/activate

# Deactivate
deactivate
```

#### 3. conda (Anaconda/Miniconda)

```bash
# Create environment
conda create -n myenv python=3.9

# Create with packages
conda create -n myenv python=3.9 pandas numpy scipy

# Activate
conda activate myenv

# Install packages
conda install pandas
# or
pip install pandas

# List environments
conda env list

# Export environment
conda env export > environment.yml

# Create from file
conda env create -f environment.yml

# Deactivate
conda deactivate

# Remove environment
conda env remove -n myenv
```

#### 4. pipenv (Package + Environment Manager)

```bash
# Install pipenv
pip install pipenv

# Create environment and install packages
pipenv install pandas numpy

# Activate
pipenv shell

# Install dev dependencies
pipenv install --dev pytest black

# Run command in environment
pipenv run python script.py

# Lock dependencies
pipenv lock

# Install from Pipfile
pipenv install
```

#### 5. poetry (Modern Package Manager)

```bash
# Install poetry
curl -sSL https://install.python-poetry.org | python3 -

# Create new project
poetry new myproject

# Add dependencies
poetry add pandas numpy

# Add dev dependencies
poetry add --dev pytest black

# Install dependencies
poetry install

# Run in environment
poetry run python script.py

# Activate shell
poetry shell

# Build package
poetry build
```

### Virtual Environment Comparison

| Tool | Pros | Cons | Best For |
|------|------|------|----------|
| **venv** | Built-in, simple, no install | Basic features | Simple projects |
| **virtualenv** | Fast, flexible, works with Python 2 | Requires install | Legacy projects |
| **conda** | Handles non-Python deps, good for data science | Large, slower | Data science, complex deps |
| **pipenv** | Combines pip + venv, Pipfile.lock | Slower, less mature | Modern web apps |
| **poetry** | Modern, great dependency resolution | Learning curve | New projects, libraries |

---

## Package Management

### pip (Standard Package Manager)

```bash
# Install package
pip install pandas

# Install specific version
pip install pandas==1.5.3

# Install minimum version
pip install "pandas>=1.5.0"

# Install from requirements.txt
pip install -r requirements.txt

# Upgrade package
pip install --upgrade pandas

# Uninstall package
pip uninstall pandas

# List installed packages
pip list

# Show package info
pip show pandas

# Search packages
pip search airflow

# Freeze dependencies
pip freeze > requirements.txt

# Install in editable mode (for development)
pip install -e .
```

### pip Advanced Usage

```bash
# Install from GitHub
pip install git+https://github.com/user/repo.git

# Install from specific branch
pip install git+https://github.com/user/repo.git@branch-name

# Install from local directory
pip install /path/to/package

# Install with extras
pip install apache-airflow[postgres,aws]

# Download packages without installing
pip download pandas -d ./packages

# Install offline
pip install --no-index --find-links=./packages pandas

# Check for security vulnerabilities
pip install pip-audit
pip-audit
```

### requirements.txt Best Practices

```txt
# requirements.txt

# ============================================================================
# Core Dependencies (Production)
# ============================================================================

# Data Processing
pandas==1.5.3
numpy==1.24.2
pyarrow==11.0.0

# Database
psycopg2-binary==2.9.5
sqlalchemy==1.4.46

# AWS
boto3==1.26.137
botocore==1.29.137

# Airflow
apache-airflow==2.5.3
apache-airflow-providers-postgres==5.4.0
apache-airflow-providers-amazon==8.0.0

# ============================================================================
# Version Constraints
# ============================================================================

# Pin exact version (most restrictive)
pandas==1.5.3

# Minimum version (allows upgrades)
pandas>=1.5.0

# Compatible release (allows patch updates)
pandas~=1.5.0  # Allows 1.5.x but not 1.6.0

# Version range
pandas>=1.5.0,<2.0.0

# Exclude specific version
pandas!=1.5.1

# ============================================================================
# Comments and Organization
# ============================================================================

# Group by purpose
# Testing dependencies in requirements-dev.txt
```

### Multiple Requirements Files

```bash
# Structure
requirements/
├── base.txt          # Core dependencies
├── dev.txt           # Development tools
├── test.txt          # Testing tools
└── prod.txt          # Production-only

# base.txt
pandas==1.5.3
numpy==1.24.2

# dev.txt
-r base.txt           # Include base requirements
black==23.3.0
flake8==6.0.0
ipython==8.12.0

# test.txt
-r base.txt
pytest==7.3.1
pytest-cov==4.0.0

# prod.txt
-r base.txt
gunicorn==20.1.0

# Install for development
pip install -r requirements/dev.txt

# Install for production
pip install -r requirements/prod.txt
```

---

## Project Structure

### Standard Python Project Layout

```
my_data_pipeline/
├── README.md                 # Project documentation
├── LICENSE                   # License file
├── .gitignore               # Git ignore patterns
├── setup.py                 # Package setup script
├── setup.cfg                # Setup configuration
├── pyproject.toml           # Modern Python project metadata
├── requirements.txt         # Dependencies
├── requirements-dev.txt     # Dev dependencies
│
├── src/                     # Source code (recommended)
│   └── my_package/
│       ├── __init__.py
│       ├── extract.py
│       ├── transform.py
│       └── load.py
│
├── tests/                   # Test files
│   ├── __init__.py
│   ├── test_extract.py
│   ├── test_transform.py
│   └── test_load.py
│
├── docs/                    # Documentation
│   ├── conf.py
│   └── index.rst
│
├── scripts/                 # Utility scripts
│   ├── setup_database.py
│   └── run_pipeline.py
│
├── configs/                 # Configuration files
│   ├── dev.yaml
│   └── prod.yaml
│
├── data/                    # Sample data (not in git)
│   ├── raw/
│   └── processed/
│
└── notebooks/               # Jupyter notebooks
    └── exploratory_analysis.ipynb
```

### Retail Sales ETL Project Structure

```
retail_sales_etl/
├── README.md
├── setup.py
├── requirements.txt
├── requirements-dev.txt
├── .env.template
│
├── src/
│   └── retail_sales_etl/
│       ├── __init__.py
│       ├── config.py              # Configuration management
│       ├── extract/
│       │   ├── __init__.py
│       │   ├── postgres.py        # PostgreSQL extraction
│       │   └── api.py             # API extraction
│       ├── transform/
│       │   ├── __init__.py
│       │   ├── cleaner.py         # Data cleaning
│       │   ├── validator.py       # Data validation
│       │   └── enricher.py        # Data enrichment
│       ├── load/
│       │   ├── __init__.py
│       │   ├── s3.py              # S3 upload
│       │   └── snowflake.py       # Snowflake load
│       └── utils/
│           ├── __init__.py
│           ├── logger.py          # Logging utilities
│           └── helpers.py         # Helper functions
│
├── dags/                          # Airflow DAGs
│   ├── retail_sales_etl_dag.py
│   └── utils/
│       └── dag_helpers.py
│
├── tests/
│   ├── conftest.py                # Pytest fixtures
│   ├── test_extract/
│   │   └── test_postgres.py
│   ├── test_transform/
│   │   ├── test_cleaner.py
│   │   └── test_validator.py
│   └── test_integration/
│       └── test_end_to_end.py
│
├── configs/
│   ├── logging.yaml
│   ├── dev.yaml
│   └── prod.yaml
│
└── scripts/
    ├── setup_environment.sh
    └── run_tests.sh
```

### __init__.py Files

```python
# src/retail_sales_etl/__init__.py

"""
Retail Sales ETL Pipeline

A production-grade ETL pipeline for consolidating regional sales data.
"""

__version__ = "1.0.0"
__author__ = "Your Name"

# Expose main classes/functions
from .extract.postgres import PostgresExtractor
from .transform.cleaner import DataCleaner
from .transform.validator import DataValidator
from .load.snowflake import SnowflakeLoader

__all__ = [
    'PostgresExtractor',
    'DataCleaner',
    'DataValidator',
    'SnowflakeLoader',
]

# Package-level configuration
import logging
logging.getLogger(__name__).addHandler(logging.NullHandler())
```

---

## Creating Packages

### setup.py (Traditional)

```python
# setup.py

from setuptools import setup, find_packages

with open("README.md", "r", encoding="utf-8") as fh:
    long_description = fh.read()

with open("requirements.txt", "r", encoding="utf-8") as fh:
    requirements = [line.strip() for line in fh if line.strip() and not line.startswith("#")]

setup(
    name="retail-sales-etl",
    version="1.0.0",
    author="Your Name",
    author_email="your.email@company.com",
    description="ETL pipeline for retail sales data",
    long_description=long_description,
    long_description_content_type="text/markdown",
    url="https://github.com/yourcompany/retail-sales-etl",
    project_urls={
        "Bug Tracker": "https://github.com/yourcompany/retail-sales-etl/issues",
        "Documentation": "https://docs.yourcompany.com/retail-sales-etl",
    },
    classifiers=[
        "Development Status :: 5 - Production/Stable",
        "Intended Audience :: Developers",
        "Topic :: Software Development :: Libraries :: Python Modules",
        "License :: OSI Approved :: MIT License",
        "Programming Language :: Python :: 3",
        "Programming Language :: Python :: 3.8",
        "Programming Language :: Python :: 3.9",
        "Programming Language :: Python :: 3.10",
    ],
    package_dir={"": "src"},
    packages=find_packages(where="src"),
    python_requires=">=3.8",
    install_requires=requirements,
    extras_require={
        "dev": [
            "pytest>=7.3.1",
            "pytest-cov>=4.0.0",
            "black>=23.3.0",
            "flake8>=6.0.0",
            "mypy>=1.2.0",
        ],
        "docs": [
            "sphinx>=6.1.0",
            "sphinx-rtd-theme>=1.2.0",
        ],
    },
    entry_points={
        "console_scripts": [
            "retail-etl=retail_sales_etl.cli:main",
        ],
    },
    include_package_data=True,
    package_data={
        "retail_sales_etl": ["configs/*.yaml"],
    },
)
```

### pyproject.toml (Modern)

```toml
# pyproject.toml

[build-system]
requires = ["setuptools>=61.0", "wheel"]
build-backend = "setuptools.build_meta"

[project]
name = "retail-sales-etl"
version = "1.0.0"
description = "ETL pipeline for retail sales data"
readme = "README.md"
requires-python = ">=3.8"
license = {text = "MIT"}
authors = [
    {name = "Your Name", email = "your.email@company.com"}
]
keywords = ["etl", "data-pipeline", "airflow", "snowflake"]
classifiers = [
    "Development Status :: 5 - Production/Stable",
    "Intended Audience :: Developers",
    "Programming Language :: Python :: 3",
    "Programming Language :: Python :: 3.8",
    "Programming Language :: Python :: 3.9",
]

dependencies = [
    "pandas>=1.5.3",
    "numpy>=1.24.2",
    "apache-airflow>=2.5.3",
    "psycopg2-binary>=2.9.5",
    "boto3>=1.26.137",
]

[project.optional-dependencies]
dev = [
    "pytest>=7.3.1",
    "pytest-cov>=4.0.0",
    "black>=23.3.0",
    "flake8>=6.0.0",
]
test = [
    "pytest>=7.3.1",
    "pytest-mock>=3.10.0",
]

[project.urls]
Homepage = "https://github.com/yourcompany/retail-sales-etl"
Documentation = "https://docs.yourcompany.com/retail-sales-etl"
Repository = "https://github.com/yourcompany/retail-sales-etl.git"
Changelog = "https://github.com/yourcompany/retail-sales-etl/blob/main/CHANGELOG.md"

[project.scripts]
retail-etl = "retail_sales_etl.cli:main"

[tool.setuptools]
package-dir = {"" = "src"}

[tool.setuptools.packages.find]
where = ["src"]

[tool.pytest.ini_options]
minversion = "7.0"
addopts = "-ra -q --strict-markers"
testpaths = ["tests"]
pythonpath = ["src"]

[tool.black]
line-length = 100
target-version = ['py38', 'py39']
include = '\.pyi?$'

[tool.mypy]
python_version = "3.8"
warn_return_any = true
warn_unused_configs = true
disallow_untyped_defs = true
```

### Building and Installing Package

```bash
# Install in development mode (editable)
pip install -e .

# Install with extras
pip install -e ".[dev]"

# Build distribution packages
python -m build
# Creates:
# dist/retail_sales_etl-1.0.0-py3-none-any.whl
# dist/retail_sales_etl-1.0.0.tar.gz

# Install from wheel
pip install dist/retail_sales_etl-1.0.0-py3-none-any.whl

# Upload to PyPI (if public)
python -m twine upload dist/*

# Upload to private PyPI server
twine upload --repository-url https://pypi.yourcompany.com dist/*
```

---

## Requirements Files

### Basic requirements.txt

```txt
# requirements.txt

# Production dependencies
pandas==1.5.3
numpy==1.24.2
apache-airflow==2.5.3
psycopg2-binary==2.9.5
boto3==1.26.137
snowflake-connector-python==3.0.2
```

### Advanced requirements.txt with Comments

```txt
# requirements.txt
# Production dependencies for Retail Sales ETL Pipeline
# Last updated: 2024-01-15

# ============================================================================
# Core Data Processing
# ============================================================================
pandas==1.5.3              # DataFrame operations
numpy==1.24.2              # Numerical computing
pyarrow==11.0.0            # Efficient data serialization

# ============================================================================
# Workflow Orchestration
# ============================================================================
apache-airflow==2.5.3
apache-airflow-providers-postgres==5.4.0
apache-airflow-providers-amazon==8.0.0
apache-airflow-providers-snowflake==4.1.0

# ============================================================================
# Database Connectors
# ============================================================================
psycopg2-binary==2.9.5     # PostgreSQL adapter
SQLAlchemy==1.4.46         # SQL toolkit
snowflake-connector-python==3.0.2
snowflake-sqlalchemy==1.4.7

# ============================================================================
# Cloud Services
# ============================================================================
boto3==1.26.137            # AWS SDK
botocore==1.29.137
s3fs==2023.4.0

# ============================================================================
# Utilities
# ============================================================================
python-dotenv==1.0.0       # Environment variables
pyyaml==6.0                # YAML parser
requests==2.28.2           # HTTP library
tenacity==8.2.2            # Retry logic

# ============================================================================
# Monitoring & Logging
# ============================================================================
datadog==0.47.0            # Datadog integration
sentry-sdk==1.22.2         # Error tracking
```

### requirements-dev.txt

```txt
# requirements-dev.txt
# Development dependencies

# Include production requirements
-r requirements.txt

# ============================================================================
# Testing
# ============================================================================
pytest==7.3.1
pytest-cov==4.0.0          # Coverage plugin
pytest-mock==3.10.0        # Mocking plugin
pytest-xdist==3.2.1        # Parallel testing
great-expectations==0.16.7 # Data validation

# ============================================================================
# Code Quality
# ============================================================================
black==23.3.0              # Code formatter
flake8==6.0.0              # Linter
mypy==1.2.0                # Type checker
isort==5.12.0              # Import sorter
pylint==2.17.2             # Code analyzer

# ============================================================================
# Development Tools
# ============================================================================
ipython==8.12.0            # Enhanced Python shell
jupyter==1.0.0             # Jupyter notebooks
ipdb==0.13.13              # Debugger

# ============================================================================
# Documentation
# ============================================================================
sphinx==6.1.0              # Documentation generator
sphinx-rtd-theme==1.2.0    # ReadTheDocs theme

# ============================================================================
# Pre-commit Hooks
# ============================================================================
pre-commit==3.2.2          # Git hooks framework
```

### Creating requirements.txt from environment

```bash
# Simple freeze (all packages)
pip freeze > requirements.txt

# Only top-level packages (recommended)
pip list --format=freeze > requirements.txt

# Using pipreqs (analyzes imports)
pip install pipreqs
pipreqs . --force

# Export conda environment
conda list --export > requirements.txt
conda env export > environment.yml
```

---

## Docker for Python

### Dockerfile for Data Pipeline

```dockerfile
# Dockerfile

FROM python:3.9-slim

# Set environment variables
ENV PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1 \
    PIP_NO_CACHE_DIR=1 \
    PIP_DISABLE_PIP_VERSION_CHECK=1

# Set working directory
WORKDIR /app

# Install system dependencies
RUN apt-get update && apt-get install -y \
    gcc \
    postgresql-client \
    && rm -rf /var/lib/apt/lists/*

# Copy requirements first (for caching)
COPY requirements.txt .

# Install Python dependencies
RUN pip install --no-cache-dir -r requirements.txt

# Copy application code
COPY src/ ./src/
COPY dags/ ./dags/
COPY configs/ ./configs/

# Install package in editable mode
COPY setup.py .
RUN pip install -e .

# Create non-root user
RUN useradd -m -u 1000 etl && \
    chown -R etl:etl /app

USER etl

# Default command
CMD ["python", "-m", "retail_sales_etl"]
```

### Multi-stage Dockerfile (Optimized)

```dockerfile
# Multi-stage Dockerfile for production

# ============================================================================
# Stage 1: Builder
# ============================================================================
FROM python:3.9-slim as builder

ENV PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1

WORKDIR /app

# Install build dependencies
RUN apt-get update && apt-get install -y \
    gcc \
    g++ \
    && rm -rf /var/lib/apt/lists/*

# Install Python dependencies
COPY requirements.txt .
RUN pip install --user --no-cache-dir -r requirements.txt

# ============================================================================
# Stage 2: Runtime
# ============================================================================
FROM python:3.9-slim

ENV PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1

WORKDIR /app

# Install runtime dependencies only
RUN apt-get update && apt-get install -y \
    postgresql-client \
    && rm -rf /var/lib/apt/lists/*

# Copy Python packages from builder
COPY --from=builder /root/.local /root/.local

# Copy application code
COPY src/ ./src/
COPY dags/ ./dags/
COPY configs/ ./configs/
COPY setup.py .

# Install package
RUN pip install --no-cache-dir -e .

# Create non-root user
RUN useradd -m -u 1000 etl && \
    chown -R etl:etl /app

USER etl

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD python -c "import sys; sys.exit(0)"

# Default command
CMD ["python", "-m", "retail_sales_etl"]
```

### docker-compose.yml for Development

```yaml
# docker-compose.yml

version: '3.8'

services:
  etl:
    build:
      context: .
      dockerfile: Dockerfile
    container_name: retail_sales_etl
    env_file:
      - .env
    volumes:
      - ./src:/app/src
      - ./dags:/app/dags
      - ./configs:/app/configs
      - ./data:/app/data
    depends_on:
      - postgres
      - localstack
    networks:
      - etl_network

  postgres:
    image: postgres:14-alpine
    container_name: etl_postgres
    environment:
      POSTGRES_DB: sales_db
      POSTGRES_USER: etl_user
      POSTGRES_PASSWORD: etl_password
    ports:
      - "5432:5432"
    volumes:
      - postgres_data:/var/lib/postgresql/data
    networks:
      - etl_network

  localstack:
    image: localstack/localstack:latest
    container_name: etl_localstack
    environment:
      SERVICES: s3,secretsmanager
      DEBUG: 1
      DATA_DIR: /tmp/localstack/data
    ports:
      - "4566:4566"
    volumes:
      - localstack_data:/tmp/localstack
    networks:
      - etl_network

volumes:
  postgres_data:
  localstack_data:

networks:
  etl_network:
    driver: bridge
```

### .dockerignore

```
# .dockerignore

# Python
__pycache__/
*.py[cod]
*$py.class
*.so
.Python
env/
venv/
ENV/
build/
dist/
*.egg-info/

# IDE
.vscode/
.idea/
*.swp
*.swo

# Testing
.pytest_cache/
.coverage
htmlcov/

# Data
data/
*.csv
*.parquet

# Logs
*.log
logs/

# Environment
.env
.env.local

# Git
.git/
.gitignore

# Documentation
docs/_build/

# OS
.DS_Store
Thumbs.db
```

---

## Best Practices

### 1. Version Pinning Strategy

```txt
# Different strategies for different scenarios

# ============================================================================
# Production (requirements.txt)
# Pin exact versions for reproducibility
# ============================================================================
pandas==1.5.3
numpy==1.24.2

# ============================================================================
# Development (requirements-dev.txt)
# Allow minor updates for dev tools
# ============================================================================
black~=23.3.0          # Allows 23.3.x
pytest>=7.3.0,<8.0.0   # Range

# ============================================================================
# CI/CD (requirements-ci.txt)
# Pin exact versions
# ============================================================================
pytest==7.3.1
coverage==7.2.3
```

### 2. Dependency Management Workflow

```bash
# 1. Create virtual environment
python -m venv venv
source venv/bin/activate

# 2. Install dependencies
pip install -r requirements.txt
pip install -r requirements-dev.txt

# 3. Add new dependency
pip install new-package

# 4. Update requirements.txt
pip freeze > requirements-new.txt
# Manually review and update requirements.txt

# 5. Test
pytest

# 6. Commit changes
git add requirements.txt
git commit -m "Add new-package dependency"
```

### 3. Environment Variable Management

```python
# src/retail_sales_etl/config.py

import os
from typing import Optional
from dataclasses import dataclass
from dotenv import load_dotenv

# Load .env file
load_dotenv()

@dataclass
class Config:
    """Application configuration"""
    
    # PostgreSQL
    POSTGRES_HOST: str = os.getenv('POSTGRES_HOST', 'localhost')
    POSTGRES_PORT: int = int(os.getenv('POSTGRES_PORT', '5432'))
    POSTGRES_DB: str = os.getenv('POSTGRES_DB', 'sales_db')
    POSTGRES_USER: str = os.getenv('POSTGRES_USER', 'etl_user')
    POSTGRES_PASSWORD: str = os.getenv('POSTGRES_PASSWORD', '')
    
    # AWS
    AWS_REGION: str = os.getenv('AWS_REGION', 'us-east-1')
    S3_BUCKET: str = os.getenv('S3_BUCKET', 'data-pipeline-staging')
    
    # Snowflake
    SNOWFLAKE_ACCOUNT: str = os.getenv('SNOWFLAKE_ACCOUNT', '')
    SNOWFLAKE_USER: str = os.getenv('SNOWFLAKE_USER', '')
    SNOWFLAKE_PASSWORD: str = os.getenv('SNOWFLAKE_PASSWORD', '')
    
    # Application
    LOG_LEVEL: str = os.getenv('LOG_LEVEL', 'INFO')
    ENVIRONMENT: str = os.getenv('ENVIRONMENT', 'development')
    
    def validate(self) -> None:
        """Validate required configuration"""
        required = {
            'POSTGRES_PASSWORD': self.POSTGRES_PASSWORD,
            'SNOWFLAKE_ACCOUNT': self.SNOWFLAKE_ACCOUNT,
            'SNOWFLAKE_PASSWORD': self.SNOWFLAKE_PASSWORD,
        }
        
        missing = [k for k, v in required.items() if not v]
        if missing:
            raise ValueError(f"Missing required config: {', '.join(missing)}")

# Usage
config = Config()
config.validate()
```

### 4. .gitignore for Python Projects

```
# .gitignore

# Python
__pycache__/
*.py[cod]
*$py.class
*.so
.Python
build/
develop-eggs/
dist/
downloads/
eggs/
.eggs/
lib/
lib64/
parts/
sdist/
var/
wheels/
*.egg-info/
.installed.cfg
*.egg
MANIFEST

# Virtual Environments
venv/
ENV/
env/
.venv

# IDE
.vscode/
.idea/
*.swp
*.swo
.spyderproject
.spyproject

# Testing
.pytest_cache/
.coverage
.coverage.*
htmlcov/
.tox/
.hypothesis/

# Jupyter
.ipynb_checkpoints
*.ipynb

# Environment
.env
.env.local
.env.*.local

# Logs
*.log
logs/

# Data (often shouldn't be in git)
data/
*.csv
*.parquet
*.json
*.xlsx

# OS
.DS_Store
Thumbs.db

# Distribution
dist/
build/
*.egg-info/
```

---

## Interview Preparation

### Common Interview Questions

#### Q1: "What is a virtual environment and why use it?"

**Answer:**
"A virtual environment is an isolated Python environment with its own packages and dependencies. I use them because:

1. **Isolation**: Different projects can have different package versions
2. **Reproducibility**: Same environment on dev, staging, production
3. **Clean global install**: Don't pollute system Python

**Example from my project:**
```bash
# Create environment
python -m venv venv
source venv/bin/activate

# Install project dependencies
pip install -r requirements.txt

# Verify isolation
which python  # Shows venv/bin/python, not system python
```

Each team member and deployment environment uses identical packages, preventing 'works on my machine' issues."

---

#### Q2: "What's the difference between requirements.txt and setup.py?"

**Answer:**

| Aspect | requirements.txt | setup.py |
|--------|------------------|----------|
| **Purpose** | Install dependencies | Package metadata + dependencies |
| **Use Case** | Deploy applications | Distribute libraries |
| **Version Pinning** | Exact versions | Version ranges |
| **Content** | Flat list of packages | Abstract dependencies |

**Example:**

```python
# requirements.txt (application deployment)
pandas==1.5.3        # Exact version
numpy==1.24.2

# setup.py (library distribution)
install_requires=[
    'pandas>=1.5.0',  # Minimum version
    'numpy>=1.24.0',
]
```

**My approach:**
- `requirements.txt` for deploying my ETL pipeline (exact versions)
- `setup.py` if distributing as reusable library (version ranges)
- Often use both: setup.py defines abstract deps, requirements.txt pins them"

---

#### Q3: "How do you manage dependencies in production?"

**Answer:**
"I use a multi-layered approach:

**1. Pin exact versions in production:**
```txt
# requirements.txt
pandas==1.5.3  # Not pandas>=1.5.0
```
Prevents unexpected breakage from package updates.

**2. Separate dev and prod requirements:**
```
requirements/
├── base.txt     # Core dependencies
├── prod.txt     # Production-only (monitoring)
└── dev.txt      # Development tools (pytest, black)
```

**3. Lock files for reproducibility:**
```bash
# Generate lock file
pip freeze > requirements-lock.txt

# Install from lock
pip install -r requirements-lock.txt
```

**4. Regular dependency audits:**
```bash
pip install pip-audit
pip-audit  # Check for security vulnerabilities
```

**5. Docker for consistency:**
```dockerfile
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt
```
Same environment in dev, CI, and production."

---

#### Q4: "Explain your project structure."

**Answer:**
"I follow the src layout pattern for my retail sales ETL:

```
retail_sales_etl/
├── src/retail_sales_etl/    # Source code (installable)
│   ├── extract/              # Extraction modules
│   ├── transform/            # Transformation logic
│   └── load/                 # Loading modules
├── tests/                    # Test files (mirrors src/)
├── dags/                     # Airflow DAGs
├── configs/                  # Configuration files
└── setup.py                  # Package definition
```

**Why this structure?**
1. **src/ layout**: Prevents accidentally importing from source instead of installed package
2. **Separation of concerns**: Extract/Transform/Load clearly separated
3. **Testability**: tests/ mirrors src/ structure
4. **Installability**: `pip install -e .` for development

**Benefits in production:**
- Clear imports: `from retail_sales_etl.extract import PostgresExtractor`
- Easy packaging: `python -m build`
- Consistent across environments"

---

#### Q5: "How do you handle configuration across environments?"

**Answer:**
"I use a combination of techniques:

**1. Environment variables (.env files):**
```python
# .env
DATABASE_URL=postgresql://user:pass@localhost/db
AWS_REGION=us-east-1

# .env.production
DATABASE_URL=postgresql://prod-host/prod-db
AWS_REGION=us-west-2
```

**2. Config class with defaults:**
```python
import os
from dotenv import load_dotenv

load_dotenv()  # Load .env

class Config:
    DATABASE_URL = os.getenv('DATABASE_URL')
    AWS_REGION = os.getenv('AWS_REGION', 'us-east-1')  # Default
    
    def validate(self):
        if not self.DATABASE_URL:
            raise ValueError('DATABASE_URL required')
```

**3. YAML configs for complex settings:**
```yaml
# configs/prod.yaml
database:
  pool_size: 20
  timeout: 30

processing:
  batch_size: 10000
  parallelism: 4
```

**4. Never commit secrets:**
```
# .gitignore
.env
.env.*
configs/secrets.yaml
```

**In production:**
- Secrets in AWS Secrets Manager / HashiCorp Vault
- Config injected via environment variables
- Different .env files never committed to git"

---

#### Q6: "What's your Docker strategy for Python data pipelines?"

**Answer:**
"I use multi-stage builds for optimization:

```dockerfile
# Stage 1: Build dependencies
FROM python:3.9-slim as builder
COPY requirements.txt .
RUN pip install --user --no-cache-dir -r requirements.txt

# Stage 2: Runtime (smaller)
FROM python:3.9-slim
COPY --from=builder /root/.local /root/.local
COPY src/ ./src/
RUN pip install -e .
```

**Benefits:**
1. **Smaller images**: Runtime stage only has necessities
2. **Faster builds**: Dependencies cached in builder stage
3. **Security**: No build tools in production image

**docker-compose for local development:**
```yaml
services:
  etl:
    build: .
    volumes:
      - ./src:/app/src  # Live code reload
    depends_on:
      - postgres
      - localstack  # Local AWS
```

**In production:**
- Build once, deploy everywhere
- Same image in staging and production
- Environment-specific config via env vars"

---

### Real-World Scenario Questions

#### Scenario 1: "Dependency conflict - pandas requires numpy<1.24, but your other package needs numpy>=1.24. How do you resolve?"

**Answer:**
"This is a common dependency conflict. Here's my approach:

**1. Check if conflict is real:**
```bash
pip install pandas your-package
# See actual error
```

**2. Try using compatible versions:**
```bash
# Find compatible versions
pip index versions pandas
pip index versions your-package

# Try different pandas version
pip install pandas==1.4.0 your-package
```

**3. If conflict persists, use separate environments:**
```bash
# Environment 1: For pandas work
python -m venv env_pandas
pip install pandas

# Environment 2: For other package
python -m venv env_other
pip install your-package
```

**4. Consider alternatives:**
- Use `conda` which handles non-Python deps better
- Fork and update the conflicting package
- Use containerization to isolate

**In my retail sales project:**
I had Airflow requiring specific boto3 version, but AWS SDK needed newer. Solution: upgraded Airflow to compatible version. Always prefer upgrading to compatible versions over maintaining multiple environments."

---

#### Scenario 2: "Your pipeline works locally but fails in production with 'Module not found'. How do you debug?"

**Answer:**
"Classic environment mismatch issue. My debugging process:

**1. Verify package installation:**
```bash
# In production environment
pip list | grep module-name
python -c 'import module_name'  # Test import directly
```

**2. Check Python path:**
```python
import sys
print(sys.path)  # Where Python looks for modules
```

**3. Common causes:**
- Package not in requirements.txt
- Different Python version (2 vs 3, 3.8 vs 3.9)
- Package installed in user site, not venv
- Import path issue (relative vs absolute)

**4. Ensure identical environments:**
```bash
# Generate from working environment
pip freeze > requirements-working.txt

# Install in production
pip install -r requirements-working.txt

# Compare
pip list > prod-packages.txt
diff requirements-working.txt prod-packages.txt
```

**Prevention:**
```dockerfile
# Dockerfile ensures identical environment
FROM python:3.9-slim
COPY requirements.txt .
RUN pip install -r requirements.txt
# Same everywhere
```

**In my project:**
Had this exact issue - import worked locally but not in Docker. Cause: local had package installed globally. Fix: Added to requirements.txt and verified with fresh venv."

---

### Best Practices Summary for Interviews

**Say These Things:**

✅ "I use virtual environments for every project to ensure isolation"

✅ "I pin exact versions in production requirements.txt for reproducibility"

✅ "I separate development and production dependencies"

✅ "I use Docker to ensure identical environments across dev, staging, and prod"

✅ "I never commit .env files or secrets to git"

✅ "I use the src/ layout pattern to prevent import issues"

✅ "I regularly audit dependencies for security vulnerabilities"

**Don't Say:**

❌ "I install packages globally on the system"

❌ "I don't pin versions, latest is fine"

❌ "I commit my .env file for convenience"

❌ "I don't use version control for requirements.txt"

❌ "I don't test in production-like environments"

---

### Quick Commands Reference

```bash
# Virtual Environments
python -m venv venv          # Create
source venv/bin/activate     # Activate (Linux/Mac)
venv\Scripts\activate        # Activate (Windows)
deactivate                   # Deactivate

# Package Management
pip install package          # Install
pip install -r requirements.txt
pip freeze > requirements.txt
pip list                     # List installed
pip show package             # Package info

# Development
pip install -e .             # Editable install
pip install -e ".[dev]"      # With extras

# Building
python -m build              # Build distribution
python setup.py sdist        # Source distribution
twine upload dist/*          # Upload to PyPI

# Docker
docker build -t my-app .     # Build image
docker run my-app            # Run container
docker-compose up            # Start services
```

---

**Next: Interview Quick Reference Card...**
