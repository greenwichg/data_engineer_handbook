# Python Packaging & Virtual Environments - Interview Quick Reference

**Print this and review 30 minutes before your interview!**

---

## 1-Minute Explanation

"Virtual environments create isolated Python installations with independent packages. I use them for every project to prevent dependency conflicts and ensure reproducibility. Combined with requirements.txt and setup.py, I can package my data pipelines for consistent deployment across dev, staging, and production."

---

## Core Concepts (Memorize!)

### Virtual Environment
```bash
# Create
python -m venv venv

# Activate
source venv/bin/activate  # Linux/Mac
venv\Scripts\activate     # Windows

# Verify
which python              # Should show venv path

# Deactivate
deactivate
```

### Requirements File
```txt
# requirements.txt
pandas==1.5.3            # Exact version
numpy>=1.24.0            # Minimum version
boto3~=1.26.0            # Compatible release (1.26.x)
```

### Install from Requirements
```bash
pip install -r requirements.txt
pip freeze > requirements.txt  # Save current
```

### Package Structure
```
my_package/
├── src/my_package/     # Source code
│   ├── __init__.py
│   └── module.py
├── tests/              # Tests
├── setup.py            # Package config
└── requirements.txt    # Dependencies
```

### Install Package Locally
```bash
pip install -e .        # Editable mode
```

---

## Interview Questions & Answers

### Q1: "What is a virtual environment and why use it?"

**Answer:** 
"A virtual environment is an isolated Python installation with its own packages. I use them because:

1. **Isolation**: Different projects need different package versions
2. **Reproducibility**: Same environment in dev and production  
3. **Clean system**: Don't pollute global Python

**Example:**
```bash
python -m venv venv
source venv/bin/activate
pip install pandas==1.5.3  # Only in this environment
```

In my retail sales pipeline, I have separate venvs for development (with pytest, black) and production (minimal dependencies). This prevents my testing tools from bloating production deployments."

---

### Q2: "requirements.txt vs setup.py - what's the difference?"

**Answer:**

| Aspect | requirements.txt | setup.py |
|--------|------------------|----------|
| **Purpose** | Deploy app | Distribute library |
| **Versions** | Exact (pandas==1.5.3) | Ranges (pandas>=1.5.0) |
| **Use** | Production deployment | PyPI distribution |

**Example:**
```python
# setup.py (library - flexible)
install_requires=['pandas>=1.5.0']

# requirements.txt (app - exact)
pandas==1.5.3
```

**My approach:** 
- Use `setup.py` to define my ETL package structure
- Use `requirements.txt` to pin exact versions for deployment
- Often have both: setup.py says 'need pandas', requirements.txt says 'use pandas==1.5.3'"

---

### Q3: "How do you manage dependencies in production?"

**Answer:**
"Four-layer approach:

**1. Pin exact versions:**
```txt
pandas==1.5.3  # Not >=1.5.3
```

**2. Separate files:**
```
requirements/
├── base.txt     # Core dependencies
├── prod.txt     # Production-only
└── dev.txt      # Dev tools (pytest, black)
```

**3. Lock dependencies:**
```bash
pip freeze > requirements-lock.txt
```

**4. Use Docker:**
```dockerfile
COPY requirements.txt .
RUN pip install -r requirements.txt
```

**In my project:** Production uses pinned versions in Docker. Dev environment uses requirements-dev.txt with testing tools. Both built from same base.txt."

---

### Q4: "Explain your project structure."

**Answer:**
"I use the src layout for my retail sales ETL:

```
retail_sales_etl/
├── src/retail_sales_etl/    # Installable code
│   ├── __init__.py
│   ├── extract/             # Extraction modules
│   ├── transform/           # Transform logic
│   └── load/                # Loading modules
├── tests/                   # Mirror src structure
├── setup.py                 # Package definition
└── requirements.txt         # Dependencies
```

**Why src/?** 
- Prevents importing from source instead of installed package
- Forces proper package installation
- Cleaner separation

**Benefits:**
- Clean imports: `from retail_sales_etl.extract import PostgresExtractor`
- Easy to package: `pip install -e .`
- Professional structure everyone recognizes"

---

### Q5: "How do you handle different environments (dev/staging/prod)?"

**Answer:**
"Multi-layered configuration:

**1. Environment variables:**
```bash
# .env
DATABASE_URL=postgresql://localhost/dev_db
AWS_REGION=us-east-1
```

**2. Config class:**
```python
import os
from dotenv import load_dotenv

load_dotenv()

class Config:
    DB_URL = os.getenv('DATABASE_URL')
    AWS_REGION = os.getenv('AWS_REGION', 'us-east-1')
```

**3. Different .env files:**
```
.env               # Local dev
.env.staging       # Staging
.env.production    # Production (not in git!)
```

**4. Secrets management:**
- AWS Secrets Manager for prod
- Never commit .env to git

**In production:** Secrets injected via environment variables. Config validates on startup. Same code, different config."

---

### Q6: "What's your Docker strategy?"

**Answer:**
"Multi-stage build for optimization:

```dockerfile
# Stage 1: Build
FROM python:3.9-slim as builder
COPY requirements.txt .
RUN pip install --user -r requirements.txt

# Stage 2: Runtime (smaller)
FROM python:3.9-slim
COPY --from=builder /root/.local /root/.local
COPY src/ ./src/
RUN pip install -e .
```

**Benefits:**
- Smaller final image (no build tools)
- Faster builds (cached layers)
- Consistent environment everywhere

**docker-compose for local dev:**
```yaml
services:
  etl:
    build: .
    volumes:
      - ./src:/app/src  # Live reload
```

**Result:** Same Docker image from dev to production. Environment differences only in config."

---

### Q7: "How do you distribute internal packages?"

**Answer:**
"For internal company packages:

**1. Private PyPI server:**
```bash
pip install --index-url https://pypi.company.com my-package
```

**2. Git installation:**
```bash
pip install git+https://github.com/company/my-package.git
```

**3. Artifactory/Nexus:**
```bash
pip install --extra-index-url https://artifactory.company.com/pypi my-package
```

**In my company:** We use Artifactory. Packages built in CI/CD, uploaded to Artifactory, installed with custom index URL. Versioning via Git tags."

---

## Common Scenarios

### Scenario 1: Dependency Conflict

**Problem:** "pandas requires numpy<1.24, but your code needs numpy>=1.24"

**Solution:**
```bash
# 1. Try finding compatible versions
pip install pandas==1.4.0  # Older pandas

# 2. Use conda (better dependency resolution)
conda install pandas numpy

# 3. Separate environments if necessary
python -m venv env_old_pandas
python -m venv env_new_numpy
```

**Interview answer:** "Check if conflict is real. Try compatible versions. Use conda for complex deps. Last resort: separate environments. In my experience, upgrading the older package usually works."

---

### Scenario 2: Works Locally, Fails in Production

**Problem:** "Module not found" in production

**Debug steps:**
```bash
# 1. Check package installed
pip list | grep module_name

# 2. Check Python path
python -c "import sys; print(sys.path)"

# 3. Verify Python version
python --version

# 4. Check requirements.txt
cat requirements.txt | grep module_name
```

**Prevention:**
```dockerfile
# Use Docker for identical environments
FROM python:3.9-slim
COPY requirements.txt .
RUN pip install -r requirements.txt
```

**Interview answer:** "Usually missing from requirements.txt or different Python version. I prevent this with Docker and comprehensive requirements.txt. Always test in production-like environment before deploy."

---

## Best Practices Checklist

### Development Workflow

✅ Create venv for every project
```bash
python -m venv venv && source venv/bin/activate
```

✅ Pin exact versions in production
```txt
pandas==1.5.3  # Not pandas>=1.5.3
```

✅ Separate dev and prod dependencies
```
requirements/base.txt, dev.txt, prod.txt
```

✅ Use .gitignore for sensitive files
```
venv/, .env, *.pyc, __pycache__/
```

✅ Never commit .env files
```bash
# .gitignore
.env
.env.*
!.env.example
```

✅ Use src/ layout
```
src/mypackage/ instead of mypackage/
```

✅ Install in editable mode for dev
```bash
pip install -e ".[dev]"
```

✅ Use Docker for consistency
```dockerfile
FROM python:3.9-slim
COPY requirements.txt .
RUN pip install -r requirements.txt
```

---

## Commands Cheat Sheet

```bash
# Virtual Environments
python -m venv venv          # Create
source venv/bin/activate     # Activate (Linux/Mac)
venv\Scripts\activate        # Activate (Windows)
deactivate                   # Deactivate
rm -rf venv                  # Delete

# Package Management
pip install package          # Install
pip install -r requirements.txt
pip freeze > requirements.txt
pip list                     # List installed
pip show package             # Package info
pip uninstall package        # Remove

# Development
pip install -e .             # Editable install
pip install -e ".[dev]"      # With extras
python -m build              # Build package

# Docker
docker build -t app .        # Build image
docker run app               # Run
docker-compose up            # Start services
```

---

## Quick Comparison Tables

### Virtual Environment Tools

| Tool | Pros | Cons | Best For |
|------|------|------|----------|
| **venv** | Built-in, simple | Basic | Most projects |
| **conda** | Non-Python deps | Large, slow | Data science |
| **poetry** | Modern, great | Learning curve | New projects |
| **pipenv** | Pipfile.lock | Slower | Web apps |

### When to Use What

| Scenario | Tool | Reason |
|----------|------|--------|
| Simple project | venv + requirements.txt | Standard, works everywhere |
| Data science | conda | Handles non-Python deps |
| Library distribution | setup.py + pyproject.toml | PyPI standards |
| Production deploy | Docker + requirements.txt | Reproducible |
| Team project | venv + requirements.txt + Docker | Simple + consistent |

---

## Your Project Example

"In my retail sales ETL pipeline:

**Structure:**
```
retail_sales_etl/
├── src/retail_sales_etl/
│   ├── extract/
│   ├── transform/
│   └── load/
├── tests/
├── setup.py
└── requirements.txt
```

**Development:**
```bash
python -m venv venv
source venv/bin/activate
pip install -e ".[dev]"  # Includes pytest, black
pytest
```

**Production:**
```dockerfile
FROM python:3.9-slim
COPY requirements.txt .
RUN pip install -r requirements.txt
COPY src/ ./src/
RUN pip install -e .
```

**Benefits:**
- Dev and prod use same code
- Tests in isolated environment
- Docker ensures consistency
- Easy to onboard new team members"

---

## Things That Impress Interviewers

✅ "I use virtual environments for every project"

✅ "I pin exact versions in production requirements"

✅ "I separate dev and prod dependencies"

✅ "I use Docker to ensure identical environments"

✅ "I never commit .env files"

✅ "I use the src/ layout pattern"

✅ "I test in production-like environments"

---

## Things to Avoid Saying

❌ "I install packages globally"

❌ "I don't pin versions, latest is fine"

❌ "I commit my .env for convenience"

❌ "I never tested in Docker"

❌ "I don't use version control for requirements"

❌ "Works on my machine ¯\_(ツ)_/¯"

---

## 30-Second Prep Check

Before interview, can you:

- [ ] Explain what virtual environments are
- [ ] Create and activate a venv
- [ ] Explain requirements.txt vs setup.py
- [ ] Describe your project structure
- [ ] Explain how you handle different environments
- [ ] Describe your Docker strategy
- [ ] Explain dependency management
- [ ] Give examples from your project

---

## Sample Interview Exchange

**Interviewer:** "How do you ensure your data pipeline runs consistently across environments?"

**You:** "I use a combination of virtual environments, Docker, and configuration management.

**Locally:**
```bash
python -m venv venv
source venv/bin/activate
pip install -r requirements.txt
```

**In production:**
```dockerfile
FROM python:3.9-slim
COPY requirements.txt .
RUN pip install -r requirements.txt
COPY src/ ./src/
```

This ensures:
- Same Python version (3.9)
- Same package versions (pinned in requirements.txt)
- Same dependencies (Docker includes everything)

**Configuration differences** handled via environment variables:
```python
DATABASE_URL = os.getenv('DATABASE_URL')
```

**Result:** Same code, Docker image, and package versions everywhere. Only config differs. I've never had a 'works on my machine' issue in production with this approach."

---

## Final Tips

**During Interview:**
- Be specific about your project's setup
- Explain *why* you made choices, not just *what*
- Mention trade-offs you considered
- Show you understand the problems you're solving

**If You Don't Know:**
- "I haven't used [tool], but based on my experience with [similar tool], I'd approach it by..."
- "I'm not familiar with that specific pattern, but here's how I'd think through it..."

**Things to Emphasize:**
- Reproducibility
- Isolation
- Best practices (src/ layout, pinned versions, Docker)
- Real examples from your project

---

**You're ready! 🚀**

Remember: Interviewers want to see you understand:
1. **Why** virtual environments matter (isolation, reproducibility)
2. **How** to use them properly (venv, requirements.txt, Docker)
3. **When** to use different tools (dev vs prod, apps vs libraries)

**Good luck with your interview!**
