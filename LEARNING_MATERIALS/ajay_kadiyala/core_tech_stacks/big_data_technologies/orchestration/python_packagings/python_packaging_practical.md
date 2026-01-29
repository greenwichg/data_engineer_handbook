# Python Packaging - Practical Examples

Hands-on examples you can run right now to practice Python packaging and virtual environments.

---

## Example 1: Create and Use Virtual Environment

### Step-by-Step Practice

```bash
# 1. Create a project directory
mkdir my_data_project
cd my_data_project

# 2. Create virtual environment
python -m venv venv

# 3. Activate it
# Linux/Mac:
source venv/bin/activate
# Windows:
# venv\Scripts\activate

# 4. Verify activation
which python
# Should show: /path/to/my_data_project/venv/bin/python

python --version
# Should show your Python version

# 5. Install some packages
pip install pandas numpy

# 6. Verify installation
python -c "import pandas; print(pandas.__version__)"

# 7. List installed packages
pip list

# 8. Create requirements.txt
pip freeze > requirements.txt

# 9. View requirements.txt
cat requirements.txt

# 10. Deactivate
deactivate

# 11. Delete and recreate environment
rm -rf venv
python -m venv venv
source venv/bin/activate

# 12. Install from requirements.txt
pip install -r requirements.txt

# 13. Verify packages restored
pip list
```

---

## Example 2: Build a Simple Package

### Create Project Structure

```bash
# Create directory structure
mkdir -p simple_etl/src/simple_etl
mkdir -p simple_etl/tests
cd simple_etl

# Create files
touch src/simple_etl/__init__.py
touch src/simple_etl/extract.py
touch src/simple_etl/transform.py
touch setup.py
touch requirements.txt
touch README.md
```

### Write the Code

**src/simple_etl/__init__.py:**
```python
"""Simple ETL Package"""

__version__ = "0.1.0"

from .extract import extract_data
from .transform import transform_data

__all__ = ['extract_data', 'transform_data']
```

**src/simple_etl/extract.py:**
```python
"""Data extraction module"""

import pandas as pd
from typing import Dict

def extract_data(source: str) -> pd.DataFrame:
    """
    Extract data from source
    
    Args:
        source: Data source identifier
        
    Returns:
        DataFrame with extracted data
    """
    # Simulated extraction
    data = {
        'id': [1, 2, 3, 4, 5],
        'value': [10, 20, 30, 40, 50],
        'category': ['A', 'B', 'A', 'C', 'B']
    }
    
    df = pd.DataFrame(data)
    print(f"Extracted {len(df)} records from {source}")
    return df

def extract_summary() -> Dict:
    """Get extraction summary"""
    return {
        'status': 'success',
        'records': 5,
        'source': 'sample_data'
    }
```

**src/simple_etl/transform.py:**
```python
"""Data transformation module"""

import pandas as pd

def transform_data(df: pd.DataFrame) -> pd.DataFrame:
    """
    Transform data
    
    Args:
        df: Input DataFrame
        
    Returns:
        Transformed DataFrame
    """
    # Add calculated column
    df['value_doubled'] = df['value'] * 2
    
    # Add category count
    category_counts = df.groupby('category').size()
    df['category_count'] = df['category'].map(category_counts)
    
    print(f"Transformed {len(df)} records")
    return df

def validate_data(df: pd.DataFrame) -> bool:
    """
    Validate transformed data
    
    Args:
        df: DataFrame to validate
        
    Returns:
        True if valid, False otherwise
    """
    # Check required columns
    required = ['id', 'value', 'category', 'value_doubled']
    
    for col in required:
        if col not in df.columns:
            print(f"Missing column: {col}")
            return False
    
    # Check no nulls in critical columns
    if df[['id', 'value']].isnull().any().any():
        print("Found null values in critical columns")
        return False
    
    print("Data validation passed")
    return True
```

**setup.py:**
```python
"""Setup configuration for simple_etl package"""

from setuptools import setup, find_packages

with open("README.md", "r", encoding="utf-8") as fh:
    long_description = fh.read()

setup(
    name="simple-etl",
    version="0.1.0",
    author="Your Name",
    author_email="your.email@example.com",
    description="A simple ETL package",
    long_description=long_description,
    long_description_content_type="text/markdown",
    url="https://github.com/yourusername/simple-etl",
    package_dir={"": "src"},
    packages=find_packages(where="src"),
    classifiers=[
        "Programming Language :: Python :: 3",
        "License :: OSI Approved :: MIT License",
        "Operating System :: OS Independent",
    ],
    python_requires=">=3.7",
    install_requires=[
        "pandas>=1.3.0",
    ],
    extras_require={
        "dev": [
            "pytest>=7.0.0",
            "black>=22.0.0",
        ],
    },
)
```

**requirements.txt:**
```txt
pandas>=1.3.0
```

**README.md:**
```markdown
# Simple ETL Package

A simple example ETL package for learning Python packaging.

## Installation

```bash
pip install -e .
```

## Usage

```python
from simple_etl import extract_data, transform_data

# Extract data
df = extract_data('source')

# Transform data
df_transformed = transform_data(df)
```

## Development

```bash
# Install with dev dependencies
pip install -e ".[dev]"

# Run tests
pytest
```
```

### Install and Test

```bash
# Create virtual environment
python -m venv venv
source venv/bin/activate

# Install package in editable mode
pip install -e .

# Test the package
python -c "
from simple_etl import extract_data, transform_data
df = extract_data('sample')
df_transformed = transform_data(df)
print(df_transformed.head())
"

# Verify package is installed
pip list | grep simple-etl

# Check package info
pip show simple-etl
```

---

## Example 3: Multiple Requirements Files

### Create Structure

```bash
mkdir -p my_project/requirements
cd my_project

# Create requirements files
touch requirements/base.txt
touch requirements/dev.txt
touch requirements/prod.txt
touch requirements/test.txt
```

### Fill Requirements Files

**requirements/base.txt:**
```txt
# Core dependencies for all environments

pandas==1.5.3
numpy==1.24.2
requests==2.28.2
python-dotenv==1.0.0
```

**requirements/dev.txt:**
```txt
# Development dependencies

-r base.txt

# Code formatting
black==23.3.0
isort==5.12.0

# Linting
flake8==6.0.0
pylint==2.17.2

# Type checking
mypy==1.2.0

# Development tools
ipython==8.12.0
jupyter==1.0.0
```

**requirements/test.txt:**
```txt
# Testing dependencies

-r base.txt

pytest==7.3.1
pytest-cov==4.0.0
pytest-mock==3.10.0
```

**requirements/prod.txt:**
```txt
# Production-only dependencies

-r base.txt

# Monitoring
datadog==0.47.0

# Production server
gunicorn==20.1.0
```

### Use Different Environments

```bash
# Create virtual environment
python -m venv venv
source venv/bin/activate

# Install for development
pip install -r requirements/dev.txt

# Or for production
# pip install -r requirements/prod.txt

# Or for testing
# pip install -r requirements/test.txt

# Verify installation
pip list
```

---

## Example 4: Docker for Python Project

### Create Dockerfile

**Dockerfile:**
```dockerfile
FROM python:3.9-slim

# Set environment variables
ENV PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1

# Set working directory
WORKDIR /app

# Install system dependencies
RUN apt-get update && apt-get install -y \
    gcc \
    && rm -rf /var/lib/apt/lists/*

# Copy and install requirements
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy application code
COPY src/ ./src/
COPY setup.py .

# Install package
RUN pip install -e .

# Default command
CMD ["python", "-m", "simple_etl"]
```

**.dockerignore:**
```
__pycache__/
*.py[cod]
*$py.class
venv/
.venv/
.git/
.gitignore
.DS_Store
*.log
.pytest_cache/
.coverage
htmlcov/
dist/
build/
*.egg-info/
```

**docker-compose.yml:**
```yaml
version: '3.8'

services:
  app:
    build: .
    container_name: simple_etl_app
    volumes:
      - ./src:/app/src
      - ./data:/app/data
    environment:
      - LOG_LEVEL=INFO
    command: python -c "from simple_etl import extract_data, transform_data; df = extract_data('docker'); print(transform_data(df))"
```

### Build and Run

```bash
# Build Docker image
docker build -t simple-etl .

# Run container
docker run simple-etl

# Or use docker-compose
docker-compose up

# Run interactively
docker run -it simple-etl bash

# Inside container:
python -c "from simple_etl import extract_data; print(extract_data('test'))"
```

---

## Example 5: Configuration Management

### Create Config Module

**src/simple_etl/config.py:**
```python
"""Configuration management"""

import os
from dataclasses import dataclass
from typing import Optional
from dotenv import load_dotenv

# Load environment variables
load_dotenv()

@dataclass
class DatabaseConfig:
    """Database configuration"""
    host: str = os.getenv('DB_HOST', 'localhost')
    port: int = int(os.getenv('DB_PORT', '5432'))
    database: str = os.getenv('DB_NAME', 'mydb')
    user: str = os.getenv('DB_USER', 'user')
    password: str = os.getenv('DB_PASSWORD', '')
    
    @property
    def connection_string(self) -> str:
        """Get database connection string"""
        return f"postgresql://{self.user}:{self.password}@{self.host}:{self.port}/{self.database}"

@dataclass
class AppConfig:
    """Application configuration"""
    environment: str = os.getenv('ENVIRONMENT', 'development')
    log_level: str = os.getenv('LOG_LEVEL', 'INFO')
    batch_size: int = int(os.getenv('BATCH_SIZE', '1000'))
    debug: bool = os.getenv('DEBUG', 'false').lower() == 'true'
    
    # Database config
    database: DatabaseConfig = DatabaseConfig()
    
    def validate(self) -> None:
        """Validate configuration"""
        if not self.database.password:
            raise ValueError("Database password is required")
        
        if self.environment not in ['development', 'staging', 'production']:
            raise ValueError(f"Invalid environment: {self.environment}")
    
    def __repr__(self) -> str:
        """Safe string representation (no passwords)"""
        return (
            f"AppConfig(environment={self.environment}, "
            f"log_level={self.log_level}, "
            f"batch_size={self.batch_size})"
        )

# Global config instance
config = AppConfig()

# Usage example
if __name__ == '__main__':
    print(config)
    print(f"Database: {config.database.host}:{config.database.port}")
    print(f"Environment: {config.environment}")
```

**.env.example:**
```bash
# Database Configuration
DB_HOST=localhost
DB_PORT=5432
DB_NAME=etl_db
DB_USER=etl_user
DB_PASSWORD=your_password_here

# Application Configuration
ENVIRONMENT=development
LOG_LEVEL=DEBUG
BATCH_SIZE=1000
DEBUG=true
```

### Use Configuration

```bash
# Copy example env file
cp .env.example .env

# Edit with your values
nano .env

# Use in Python
python -c "
from simple_etl.config import config
print(config)
print(f'Batch size: {config.batch_size}')
"
```

---

## Example 6: Complete Project Setup Script

**setup_project.sh:**
```bash
#!/bin/bash

# Setup script for new Python data project

set -e  # Exit on error

PROJECT_NAME=$1

if [ -z "$PROJECT_NAME" ]; then
    echo "Usage: ./setup_project.sh <project_name>"
    exit 1
fi

echo "Creating project: $PROJECT_NAME"

# Create directory structure
mkdir -p $PROJECT_NAME/{src/$PROJECT_NAME,tests,configs,scripts,docs}

# Create __init__.py files
touch $PROJECT_NAME/src/$PROJECT_NAME/__init__.py
touch $PROJECT_NAME/tests/__init__.py

# Create main module files
cat > $PROJECT_NAME/src/$PROJECT_NAME/main.py << 'EOF'
"""Main module"""

def main():
    """Main entry point"""
    print("Hello from {project_name}!")

if __name__ == '__main__':
    main()
EOF

# Create setup.py
cat > $PROJECT_NAME/setup.py << EOF
from setuptools import setup, find_packages

setup(
    name="$PROJECT_NAME",
    version="0.1.0",
    package_dir={"": "src"},
    packages=find_packages(where="src"),
    python_requires=">=3.8",
    install_requires=[
        "pandas>=1.5.0",
    ],
)
EOF

# Create requirements files
mkdir -p $PROJECT_NAME/requirements

cat > $PROJECT_NAME/requirements/base.txt << 'EOF'
pandas>=1.5.0
numpy>=1.24.0
EOF

cat > $PROJECT_NAME/requirements/dev.txt << 'EOF'
-r base.txt

pytest>=7.3.0
black>=23.3.0
flake8>=6.0.0
EOF

# Create README
cat > $PROJECT_NAME/README.md << EOF
# $PROJECT_NAME

## Installation

\`\`\`bash
python -m venv venv
source venv/bin/activate
pip install -e .
\`\`\`

## Usage

\`\`\`python
from $PROJECT_NAME import main
main()
\`\`\`
EOF

# Create .gitignore
cat > $PROJECT_NAME/.gitignore << 'EOF'
__pycache__/
*.py[cod]
venv/
.venv/
*.egg-info/
dist/
build/
.pytest_cache/
.coverage
.env
EOF

# Create .env.example
cat > $PROJECT_NAME/.env.example << 'EOF'
# Environment variables
LOG_LEVEL=INFO
DEBUG=false
EOF

# Create virtual environment
cd $PROJECT_NAME
python -m venv venv

echo ""
echo "Project $PROJECT_NAME created successfully!"
echo ""
echo "Next steps:"
echo "  cd $PROJECT_NAME"
echo "  source venv/bin/activate"
echo "  pip install -e ."
echo "  python -m $PROJECT_NAME.main"
```

### Use Setup Script

```bash
# Make executable
chmod +x setup_project.sh

# Create new project
./setup_project.sh my_new_etl

# Navigate and activate
cd my_new_etl
source venv/bin/activate

# Install
pip install -e .

# Run
python -m my_new_etl.main
```

---

## Example 7: Testing Package Installation

**test_installation.py:**
```python
"""Test that package is properly installed"""

def test_package_importable():
    """Test that package can be imported"""
    try:
        import simple_etl
        print(f"✓ Package imported successfully")
        print(f"  Version: {simple_etl.__version__}")
        return True
    except ImportError as e:
        print(f"✗ Failed to import package: {e}")
        return False

def test_functions_available():
    """Test that main functions are available"""
    try:
        from simple_etl import extract_data, transform_data
        print(f"✓ Main functions available")
        return True
    except ImportError as e:
        print(f"✗ Functions not available: {e}")
        return False

def test_dependencies_installed():
    """Test that dependencies are installed"""
    try:
        import pandas
        import numpy
        print(f"✓ Dependencies installed")
        print(f"  pandas: {pandas.__version__}")
        print(f"  numpy: {numpy.__version__}")
        return True
    except ImportError as e:
        print(f"✗ Missing dependency: {e}")
        return False

def test_package_works():
    """Test that package actually works"""
    try:
        from simple_etl import extract_data, transform_data
        
        # Extract
        df = extract_data('test')
        assert len(df) > 0, "No data extracted"
        
        # Transform
        df_transformed = transform_data(df)
        assert 'value_doubled' in df_transformed.columns, "Transform failed"
        
        print(f"✓ Package works correctly")
        print(f"  Extracted {len(df)} records")
        print(f"  Transformed successfully")
        return True
    except Exception as e:
        print(f"✗ Package test failed: {e}")
        return False

def run_all_tests():
    """Run all installation tests"""
    print("Testing package installation...")
    print("=" * 50)
    
    tests = [
        test_package_importable,
        test_functions_available,
        test_dependencies_installed,
        test_package_works,
    ]
    
    results = [test() for test in tests]
    
    print("=" * 50)
    passed = sum(results)
    total = len(results)
    
    if passed == total:
        print(f"\n✓ All tests passed ({passed}/{total})")
        return 0
    else:
        print(f"\n✗ Some tests failed ({passed}/{total})")
        return 1

if __name__ == '__main__':
    import sys
    sys.exit(run_all_tests())
```

### Run Installation Tests

```bash
# After installing package
python test_installation.py

# Expected output:
# Testing package installation...
# ==================================================
# ✓ Package imported successfully
#   Version: 0.1.0
# ✓ Main functions available
# ✓ Dependencies installed
#   pandas: 1.5.3
#   numpy: 1.24.2
# Extracted 5 records from test
# Transformed 5 records
# ✓ Package works correctly
#   Extracted 5 records
#   Transformed successfully
# ==================================================
# 
# ✓ All tests passed (4/4)
```

---

## Common Commands Cheat Sheet

```bash
# Virtual Environments
python -m venv venv              # Create
source venv/bin/activate         # Activate (Linux/Mac)
venv\Scripts\activate            # Activate (Windows)
deactivate                       # Deactivate

# Package Management
pip install package              # Install
pip install -r requirements.txt  # Install from file
pip freeze > requirements.txt    # Save dependencies
pip list                         # List installed
pip show package                 # Package details

# Development Installation
pip install -e .                 # Editable install
pip install -e ".[dev]"          # With dev extras

# Building and Distribution
python -m build                  # Build package
python setup.py sdist            # Source dist
twine upload dist/*              # Upload to PyPI

# Docker
docker build -t myapp .          # Build image
docker run myapp                 # Run container
docker-compose up                # Start services
docker-compose down              # Stop services

# Project Setup
mkdir -p src/mypackage tests     # Create structure
touch src/mypackage/__init__.py  # Init file
pip install -e .                 # Install locally
pytest                           # Run tests
```

---

## Troubleshooting

### Problem: "Module not found" after installation

```bash
# Solution 1: Verify package installed
pip list | grep mypackage

# Solution 2: Check Python path
python -c "import sys; print('\n'.join(sys.path))"

# Solution 3: Reinstall in editable mode
pip uninstall mypackage
pip install -e .

# Solution 4: Check you're in correct venv
which python
```

### Problem: "Permission denied" when installing

```bash
# Solution: Don't use sudo, use virtual environment
python -m venv venv
source venv/bin/activate
pip install package
```

### Problem: Requirements don't install

```bash
# Solution 1: Update pip
pip install --upgrade pip

# Solution 2: Install one by one to find issue
cat requirements.txt | xargs -n 1 pip install

# Solution 3: Check Python version
python --version
# Some packages need specific Python versions
```

### Problem: Package import works in terminal but not in script

```bash
# Solution: Check PYTHONPATH
echo $PYTHONPATH

# Set PYTHONPATH to include src
export PYTHONPATH="${PYTHONPATH}:$(pwd)/src"

# Or install package
pip install -e .
```

---

## Next Steps

1. **Practice creating virtual environments** - Do it 5 times until it's muscle memory
2. **Build the simple_etl package** - Follow Example 2 completely
3. **Add Docker** - Containerize your package from Example 4
4. **Create your retail sales ETL as a proper package** - Apply everything you learned

**You're now ready to discuss packaging in interviews!** 🚀
