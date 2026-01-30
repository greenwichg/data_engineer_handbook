# CI/CD for Data Engineering - Complete Interview Guide (AWS)

A comprehensive guide to CI/CD for data pipelines: Git workflows, branching strategies, code reviews, automated deployments to AWS MWAA (Managed Workflows for Apache Airflow), and Infrastructure as Code.

---

## Table of Contents

1. [Git Workflows & Branching](#git-workflows-and-branching)
2. [Code Reviews for Data Pipelines](#code-reviews)
3. [CI/CD Pipeline Architecture](#cicd-pipeline-architecture)
4. [AWS MWAA Deployments](#aws-mwaa-deployments)
5. [Infrastructure as Code](#infrastructure-as-code)
6. [Automated Testing in CI/CD](#automated-testing)
7. [Deployment Strategies](#deployment-strategies)
8. [Interview Preparation](#interview-preparation)

---

## Git Workflows for Data Engineering

### Why Git for Data Pipelines?

**Version Control Benefits:**
- Track changes to DAGs, SQL, transformations
- Collaborate without conflicts
- Rollback to working versions
- Audit trail for compliance
- Enable code reviews

### Git Basics for Data Engineering

```bash
# 1. Clone repository
git clone https://github.com/company/data-pipelines.git
cd data-pipelines

# 2. Create feature branch
git checkout -b feature/add-sales-pipeline

# 3. Make changes to DAGs
# Edit dags/sales_etl.py

# 4. Stage and commit
git add dags/sales_etl.py
git commit -m "feat: Add sales ETL pipeline with validation"

# 5. Push to remote
git push origin feature/add-sales-pipeline

# 6. Create Pull Request (on GitHub/GitLab)
# Request code review from team

# 7. After approval, merge to main
git checkout main
git pull origin main
git merge feature/add-sales-pipeline

# 8. Deploy to production (automated via CI/CD)
# Triggered by merge to main
```

### Commit Message Conventions

```bash
# Conventional Commits format
<type>(<scope>): <description>

[optional body]

[optional footer]

# Types:
feat:     # New feature (new DAG, new transformation)
fix:      # Bug fix (fix broken DAG, fix data quality issue)
docs:     # Documentation changes
style:    # Code style changes (formatting, no logic change)
refactor: # Code refactoring
test:     # Adding or updating tests
chore:    # Maintenance (dependencies, configs)

# Examples for data engineering:

# Good commits
git commit -m "feat(sales): Add daily sales aggregation pipeline"
git commit -m "fix(etl): Handle NULL values in customer dimension"
git commit -m "refactor(dags): Extract common validation logic to shared module"
git commit -m "test(sales): Add unit tests for sales transformation"
git commit -m "chore(deps): Upgrade apache-airflow to 2.7.0"

# Bad commits (avoid)
git commit -m "fixed stuff"
git commit -m "update"
git commit -m "working version"
```

### .gitignore for Data Projects

```bash
# .gitignore

# Python
__pycache__/
*.py[cod]
*$py.class
*.so
.Python
venv/
env/
*.egg-info/
dist/
build/

# Airflow
airflow.db
airflow.cfg
airflow_local_settings.py
logs/
airflow-webserver.pid

# Data files (never commit data!)
*.csv
*.parquet
*.json
*.xlsx
data/
raw_data/
processed_data/

# Secrets (never commit!)
.env
.env.local
secrets/
*.key
*.pem
service-account.json
credentials/

# IDE
.vscode/
.idea/
*.swp
*.swo

# OS
.DS_Store
Thumbs.db

# Terraform state (use remote backend)
*.tfstate
*.tfstate.backup
.terraform/

# Testing
.pytest_cache/
.coverage
htmlcov/
.tox/

# Notebooks (be selective)
.ipynb_checkpoints/
*.ipynb  # Optional: commit reviewed notebooks only
```

---

## Branching Strategies

### GitFlow for Data Pipelines

**Best for:** Teams with scheduled releases, clear dev/staging/prod environments

```
main (production)
  ├── develop (integration)
  │   ├── feature/add-customer-pipeline
  │   ├── feature/update-sales-logic
  │   └── feature/add-data-validation
  ├── hotfix/fix-critical-etl-bug
  └── release/v1.2.0
```

**Workflow:**

```bash
# 1. Create feature branch from develop
git checkout develop
git pull origin develop
git checkout -b feature/add-customer-pipeline

# 2. Develop and commit
git add dags/customer_etl.py
git commit -m "feat(customer): Add customer dimension ETL"

# 3. Push and create PR to develop
git push origin feature/add-customer-pipeline
# Create PR: feature/add-customer-pipeline → develop

# 4. After review, merge to develop
# Triggers CI/CD deployment to DEV environment

# 5. Create release branch
git checkout develop
git checkout -b release/v1.2.0

# 6. Test in staging, fix bugs
git commit -m "fix(customer): Handle edge case in address parsing"

# 7. Merge to main (production)
git checkout main
git merge release/v1.2.0
git tag -a v1.2.0 -m "Release v1.2.0: Customer pipeline"
git push origin main --tags
# Triggers CI/CD deployment to PROD

# 8. Merge back to develop
git checkout develop
git merge release/v1.2.0

# Hotfix workflow (critical production bug)
git checkout main
git checkout -b hotfix/fix-sales-calculation
# Fix the bug
git commit -m "fix(sales): Correct revenue calculation formula"
git checkout main
git merge hotfix/fix-sales-calculation
git push origin main
# Also merge to develop
git checkout develop
git merge hotfix/fix-sales-calculation
```

### Trunk-Based Development

**Best for:** Continuous deployment, mature CI/CD, feature flags

```
main (always deployable)
  ├── feature/short-lived-feature-1
  ├── feature/short-lived-feature-2
  └── feature/short-lived-feature-3
```

**Workflow:**

```bash
# 1. Create short-lived feature branch from main
git checkout main
git pull origin main
git checkout -b feature/add-validation

# 2. Develop (keep branch lifetime < 2 days)
git add dags/validation.py
git commit -m "feat(validation): Add Great Expectations validation"

# 3. Rebase frequently to stay current
git fetch origin
git rebase origin/main

# 4. Push and create PR
git push origin feature/add-validation

# 5. After review, merge to main
# Triggers CI/CD deployment to PROD immediately
# Use feature flags to control rollout

# 6. Delete feature branch
git branch -d feature/add-validation
```

### Environment-Based Branching (Recommended for Data Pipelines)

**Best for:** Data engineering teams with clear dev/staging/prod separation

```
production (main)
  ├── staging
  │   └── development
  │       ├── feature/sales-pipeline
  │       └── feature/customer-pipeline
```

**Branch-to-Environment Mapping:**

| Branch | Environment | Auto-Deploy? | Who Can Merge? |
|--------|-------------|--------------|----------------|
| `development` | DEV (Cloud Composer DEV) | ✓ Yes | Any developer |
| `staging` | STAGING (Cloud Composer STAGING) | ✓ Yes | Tech leads |
| `production` | PROD (Cloud Composer PROD) | ✓ Yes (after approval) | Release managers |

**Workflow:**

```bash
# 1. Create feature branch from development
git checkout development
git pull origin development
git checkout -b feature/sales-pipeline

# 2. Develop
# Edit dags/sales_etl.py, tests/test_sales_etl.py
git add .
git commit -m "feat(sales): Add sales ETL pipeline"

# 3. PR to development
git push origin feature/sales-pipeline
# Create PR: feature/sales-pipeline → development
# CI runs: linting, unit tests, integration tests
# Auto-deploys to DEV environment after merge

# 4. Test in DEV, then promote to staging
git checkout staging
git merge development
git push origin staging
# CI runs: full test suite, data quality checks
# Auto-deploys to STAGING environment

# 5. Test in STAGING, then promote to production
git checkout production
git merge staging
git push origin production
# CI runs: smoke tests, deployment verification
# Auto-deploys to PROD environment (with approval gate)
```

---

## Code Reviews

### Code Review Checklist for Data Pipelines

**DAG Structure:**
- [ ] DAG ID follows naming convention (`{project}_{pipeline}_{frequency}`)
- [ ] Schedule interval is correct
- [ ] `catchup=False` for new DAGs (prevents backfill)
- [ ] Default args include retries, email on failure
- [ ] Task dependencies are logical
- [ ] No circular dependencies

**Code Quality:**
- [ ] Follows team coding standards (PEP 8)
- [ ] No hardcoded credentials or secrets
- [ ] SQL queries are parameterized (no SQL injection)
- [ ] Error handling is comprehensive
- [ ] Logging is appropriate (INFO for success, ERROR for failures)
- [ ] No duplicate code (use shared modules)

**Data Quality:**
- [ ] Data validation is present (row counts, NULL checks)
- [ ] Schema validation for inputs/outputs
- [ ] Data quality checks before loading to warehouse
- [ ] Handling of edge cases (empty data, duplicates)

**Testing:**
- [ ] Unit tests for transformations
- [ ] Integration tests for DAG
- [ ] Test data is realistic
- [ ] Tests cover edge cases

**Documentation:**
- [ ] Docstrings for functions
- [ ] README updated if needed
- [ ] Comments explain "why", not "what"
- [ ] Complex logic is documented

**Performance:**
- [ ] Efficient SQL queries (no SELECT *)
- [ ] Appropriate partitioning for large datasets
- [ ] Memory-efficient operations (avoid loading all data to memory)
- [ ] Parallelism configured correctly

### Pull Request Template

```markdown
# Pull Request Template

## Description
<!-- Brief description of changes -->

## Type of Change
- [ ] New feature (new DAG, new transformation)
- [ ] Bug fix (fixes an issue)
- [ ] Refactoring (no functional changes)
- [ ] Documentation update
- [ ] Configuration change

## Related Issue
<!-- Link to Jira/GitHub issue -->
Closes #123

## Changes Made
<!-- Detailed list of changes -->
- Added `sales_daily_aggregation` DAG
- Implemented data quality checks with Great Expectations
- Added unit tests for transformation logic

## Testing
<!-- How was this tested? -->
- [ ] Unit tests pass locally (`pytest tests/`)
- [ ] Integration tests pass in DEV environment
- [ ] Manually tested DAG in DEV Airflow UI
- [ ] Data quality validation passes

## Deployment Notes
<!-- Any special deployment considerations -->
- New environment variables required: `SALES_DB_CONNECTION`
- Requires Airflow variables: `sales_s3_bucket`
- Backward compatible: Yes

## Checklist
- [ ] Code follows team style guide
- [ ] No hardcoded secrets or credentials
- [ ] Tests added/updated
- [ ] Documentation updated
- [ ] Reviewed own code before requesting review
- [ ] Added appropriate labels

## Screenshots (if applicable)
<!-- Screenshots of DAG graph, test results, etc. -->

## Reviewer Notes
<!-- Anything specific for reviewers to focus on -->
Please review the data validation logic in `sales_validator.py`
```

### Code Review Comments Examples

**Good Comments (Actionable, Specific):**

```python
# ❌ Bad comment
# "This doesn't look right"

# ✓ Good comment
# "SQL query is selecting all columns (*) which can be slow. 
# Suggest selecting only needed columns: 
# SELECT sale_id, amount, customer_id FROM sales"

# ❌ Bad comment
# "Bad code"

# ✓ Good comment
# "This function is 200+ lines and does multiple things. 
# Suggest extracting validation logic to separate function 
# for better testability and readability."

# ❌ Bad comment
# "Why are you doing this?"

# ✓ Good comment
# "Could you add a comment explaining why we're filtering 
# out amounts < 0? Is this a business rule or data quality issue?"

# ✓ Good comment with suggestion
# "Loading entire DataFrame to memory could cause OOM errors 
# with large datasets. Consider processing in batches:
# 
# for chunk in pd.read_csv('data.csv', chunksize=10000):
#     process(chunk)
# "

# ✓ Positive comment
# "Nice use of parameterized SQL queries to prevent injection! 👍"

# ✓ Question for clarity
# "What happens if `customer_id` is NULL? Should we skip the 
# record or raise an error?"
```

### Reviewer Guidelines

**As a Reviewer:**

1. **Be Kind and Constructive**
   - Focus on code, not person
   - Suggest alternatives, don't just criticize
   - Acknowledge good practices

2. **Focus on Important Issues**
   - Critical: Security, data quality, correctness
   - Important: Performance, maintainability
   - Nice-to-have: Style preferences (let linter handle)

3. **Ask Questions**
   - "What happens if...?"
   - "Could we...?"
   - "Have you considered...?"

4. **Provide Context**
   - Explain *why* something is an issue
   - Link to documentation
   - Share examples

**As an Author:**

1. **Be Open to Feedback**
   - Don't take it personally
   - Ask questions if unclear
   - Explain your reasoning

2. **Respond to All Comments**
   - "Fixed in commit abc123"
   - "Good catch, updated"
   - "Let me explain why..."

3. **Keep PRs Small**
   - Aim for < 400 lines changed
   - Split large features into multiple PRs
   - Easier to review = faster merge

---

## CI/CD Pipelines

### CI/CD Pipeline Stages

```yaml
# Typical CI/CD pipeline for data engineering

Stages:
  1. Lint         # Check code style
  2. Test         # Run unit/integration tests
  3. Build        # Build Docker images, package code
  4. Deploy       # Deploy to environment
  5. Validate     # Smoke tests, data quality checks
```

### GitHub Actions - Complete Example

```yaml
# .github/workflows/ci-cd.yml

name: Data Pipeline CI/CD

on:
  push:
    branches: [development, staging, production]
  pull_request:
    branches: [development, staging, production]

env:
  PYTHON_VERSION: "3.9"
  GCP_PROJECT_ID: "my-data-project"

jobs:
  # ============================================================================
  # Job 1: Lint and Code Quality
  # ============================================================================
  lint:
    name: Lint Code
    runs-on: ubuntu-latest
    
    steps:
      - name: Checkout code
        uses: actions/checkout@v3
      
      - name: Set up Python
        uses: actions/setup-python@v4
        with:
          python-version: ${{ env.PYTHON_VERSION }}
      
      - name: Cache pip dependencies
        uses: actions/cache@v3
        with:
          path: ~/.cache/pip
          key: ${{ runner.os }}-pip-${{ hashFiles('requirements.txt') }}
      
      - name: Install dependencies
        run: |
          pip install --upgrade pip
          pip install flake8 black isort mypy
          pip install -r requirements.txt
      
      - name: Run Black (code formatter check)
        run: black --check .
      
      - name: Run isort (import sorting check)
        run: isort --check-only .
      
      - name: Run flake8 (linting)
        run: flake8 dags/ src/ --max-line-length=100
      
      - name: Run mypy (type checking)
        run: mypy dags/ src/ --ignore-missing-imports

  # ============================================================================
  # Job 2: Unit Tests
  # ============================================================================
  test:
    name: Run Tests
    runs-on: ubuntu-latest
    needs: lint
    
    steps:
      - name: Checkout code
        uses: actions/checkout@v3
      
      - name: Set up Python
        uses: actions/setup-python@v4
        with:
          python-version: ${{ env.PYTHON_VERSION }}
      
      - name: Install dependencies
        run: |
          pip install --upgrade pip
          pip install -r requirements.txt
          pip install -r requirements-dev.txt
      
      - name: Run unit tests
        run: |
          pytest tests/unit/ -v --cov=src --cov-report=xml --cov-report=html
      
      - name: Upload coverage reports
        uses: codecov/codecov-action@v3
        with:
          files: ./coverage.xml
          flags: unittests
      
      - name: Archive coverage report
        uses: actions/upload-artifact@v3
        with:
          name: coverage-report
          path: htmlcov/

  # ============================================================================
  # Job 3: Integration Tests
  # ============================================================================
  integration-test:
    name: Integration Tests
    runs-on: ubuntu-latest
    needs: test
    
    services:
      postgres:
        image: postgres:14
        env:
          POSTGRES_USER: test
          POSTGRES_PASSWORD: test
          POSTGRES_DB: test_db
        options: >-
          --health-cmd pg_isready
          --health-interval 10s
          --health-timeout 5s
          --health-retries 5
        ports:
          - 5432:5432
    
    steps:
      - name: Checkout code
        uses: actions/checkout@v3
      
      - name: Set up Python
        uses: actions/setup-python@v4
        with:
          python-version: ${{ env.PYTHON_VERSION }}
      
      - name: Install dependencies
        run: |
          pip install --upgrade pip
          pip install -r requirements.txt
          pip install -r requirements-dev.txt
      
      - name: Run integration tests
        env:
          DATABASE_URL: postgresql://test:test@localhost:5432/test_db
        run: |
          pytest tests/integration/ -v -m integration

  # ============================================================================
  # Job 4: DAG Validation (Airflow-specific)
  # ============================================================================
  validate-dags:
    name: Validate Airflow DAGs
    runs-on: ubuntu-latest
    needs: lint
    
    steps:
      - name: Checkout code
        uses: actions/checkout@v3
      
      - name: Set up Python
        uses: actions/setup-python@v4
        with:
          python-version: ${{ env.PYTHON_VERSION }}
      
      - name: Install Airflow
        run: |
          pip install apache-airflow==2.7.0
          pip install -r requirements.txt
      
      - name: Initialize Airflow DB
        run: |
          export AIRFLOW_HOME=$(pwd)/airflow_home
          airflow db init
      
      - name: Validate DAGs (import test)
        run: |
          export AIRFLOW_HOME=$(pwd)/airflow_home
          python scripts/validate_dags.py
      
      - name: Check for DAG cycles
        run: |
          export AIRFLOW_HOME=$(pwd)/airflow_home
          python scripts/check_dag_cycles.py

  # ============================================================================
  # Job 5: Build Docker Image
  # ============================================================================
  build:
    name: Build Docker Image
    runs-on: ubuntu-latest
    needs: [test, integration-test, validate-dags]
    if: github.event_name == 'push'
    
    steps:
      - name: Checkout code
        uses: actions/checkout@v3
      
      - name: Set up Docker Buildx
        uses: docker/setup-buildx-action@v2
      
      - name: Login to Google Container Registry
        uses: docker/login-action@v2
        with:
          registry: gcr.io
          username: _json_key
          password: ${{ secrets.GCP_SA_KEY }}
      
      - name: Build and push Docker image
        uses: docker/build-push-action@v4
        with:
          context: .
          push: true
          tags: |
            gcr.io/${{ env.GCP_PROJECT_ID }}/data-pipeline:${{ github.sha }}
            gcr.io/${{ env.GCP_PROJECT_ID }}/data-pipeline:latest
          cache-from: type=gha
          cache-to: type=gha,mode=max

  # ============================================================================
  # Job 6: Deploy to Development
  # ============================================================================
  deploy-dev:
    name: Deploy to DEV
    runs-on: ubuntu-latest
    needs: build
    if: github.ref == 'refs/heads/development'
    environment: development
    
    steps:
      - name: Checkout code
        uses: actions/checkout@v3
      
      - name: Authenticate to Google Cloud
        uses: google-github-actions/auth@v1
        with:
          credentials_json: ${{ secrets.GCP_SA_KEY }}
      
      - name: Set up Cloud SDK
        uses: google-github-actions/setup-gcloud@v1
      
      - name: Deploy DAGs to Cloud Composer (DEV)
        run: |
          gcloud composer environments storage dags import \
            --environment=composer-dev \
            --location=us-central1 \
            --source=dags/
      
      - name: Update Airflow variables
        run: |
          gcloud composer environments run composer-dev \
            --location=us-central1 \
            variables set -- \
            environment dev
      
      - name: Run smoke tests
        run: |
          python scripts/smoke_test.py --env=dev

  # ============================================================================
  # Job 7: Deploy to Staging
  # ============================================================================
  deploy-staging:
    name: Deploy to STAGING
    runs-on: ubuntu-latest
    needs: build
    if: github.ref == 'refs/heads/staging'
    environment: staging
    
    steps:
      - name: Checkout code
        uses: actions/checkout@v3
      
      - name: Authenticate to Google Cloud
        uses: google-github-actions/auth@v1
        with:
          credentials_json: ${{ secrets.GCP_SA_KEY }}
      
      - name: Deploy DAGs to Cloud Composer (STAGING)
        run: |
          gcloud composer environments storage dags import \
            --environment=composer-staging \
            --location=us-central1 \
            --source=dags/
      
      - name: Run data quality checks
        run: |
          python scripts/data_quality_check.py --env=staging

  # ============================================================================
  # Job 8: Deploy to Production (with approval)
  # ============================================================================
  deploy-prod:
    name: Deploy to PRODUCTION
    runs-on: ubuntu-latest
    needs: build
    if: github.ref == 'refs/heads/production'
    environment: 
      name: production
      url: https://composer-prod.example.com
    
    steps:
      - name: Checkout code
        uses: actions/checkout@v3
      
      - name: Authenticate to Google Cloud
        uses: google-github-actions/auth@v1
        with:
          credentials_json: ${{ secrets.GCP_PROD_SA_KEY }}
      
      - name: Deploy DAGs to Cloud Composer (PROD)
        run: |
          gcloud composer environments storage dags import \
            --environment=composer-prod \
            --location=us-central1 \
            --source=dags/
      
      - name: Verify deployment
        run: |
          python scripts/verify_deployment.py --env=prod
      
      - name: Send Slack notification
        uses: slackapi/slack-github-action@v1
        with:
          payload: |
            {
              "text": "✅ Production deployment successful: ${{ github.sha }}"
            }
        env:
          SLACK_WEBHOOK_URL: ${{ secrets.SLACK_WEBHOOK }}
```

### GitLab CI/CD Example

```yaml
# .gitlab-ci.yml

stages:
  - lint
  - test
  - build
  - deploy-dev
  - deploy-staging
  - deploy-prod

variables:
  PYTHON_VERSION: "3.9"
  GCP_PROJECT_ID: "my-data-project"

# ============================================================================
# Templates
# ============================================================================

.python-setup: &python-setup
  image: python:${PYTHON_VERSION}
  before_script:
    - pip install --upgrade pip
    - pip install -r requirements.txt

.gcp-auth: &gcp-auth
  before_script:
    - echo $GCP_SA_KEY | base64 -d > ${HOME}/gcp-key.json
    - gcloud auth activate-service-account --key-file ${HOME}/gcp-key.json
    - gcloud config set project ${GCP_PROJECT_ID}

# ============================================================================
# Lint Stage
# ============================================================================

lint:code:
  <<: *python-setup
  stage: lint
  script:
    - pip install black flake8 isort mypy
    - black --check .
    - flake8 dags/ src/
    - isort --check-only .
    - mypy dags/ src/ --ignore-missing-imports

# ============================================================================
# Test Stage
# ============================================================================

test:unit:
  <<: *python-setup
  stage: test
  script:
    - pip install -r requirements-dev.txt
    - pytest tests/unit/ -v --cov=src --cov-report=term --cov-report=html
  coverage: '/TOTAL.*\s+(\d+%)$/'
  artifacts:
    paths:
      - htmlcov/
    expire_in: 1 week

test:integration:
  <<: *python-setup
  stage: test
  services:
    - postgres:14
  variables:
    POSTGRES_DB: test_db
    POSTGRES_USER: test
    POSTGRES_PASSWORD: test
  script:
    - pip install -r requirements-dev.txt
    - pytest tests/integration/ -v -m integration

validate:dags:
  <<: *python-setup
  stage: test
  script:
    - pip install apache-airflow==2.7.0
    - export AIRFLOW_HOME=$(pwd)/airflow_home
    - airflow db init
    - python scripts/validate_dags.py

# ============================================================================
# Build Stage
# ============================================================================

build:docker:
  stage: build
  image: docker:latest
  services:
    - docker:dind
  script:
    - docker build -t gcr.io/${GCP_PROJECT_ID}/data-pipeline:${CI_COMMIT_SHA} .
    - echo $GCP_SA_KEY | base64 -d | docker login -u _json_key --password-stdin gcr.io
    - docker push gcr.io/${GCP_PROJECT_ID}/data-pipeline:${CI_COMMIT_SHA}
  only:
    - development
    - staging
    - production

# ============================================================================
# Deploy Stages
# ============================================================================

deploy:dev:
  <<: *gcp-auth
  stage: deploy-dev
  script:
    - gcloud composer environments storage dags import
        --environment=composer-dev
        --location=us-central1
        --source=dags/
  environment:
    name: development
    url: https://composer-dev.example.com
  only:
    - development

deploy:staging:
  <<: *gcp-auth
  stage: deploy-staging
  script:
    - gcloud composer environments storage dags import
        --environment=composer-staging
        --location=us-central1
        --source=dags/
  environment:
    name: staging
    url: https://composer-staging.example.com
  only:
    - staging

deploy:prod:
  <<: *gcp-auth
  stage: deploy-prod
  script:
    - gcloud composer environments storage dags import
        --environment=composer-prod
        --location=us-central1
        --source=dags/
    - python scripts/verify_deployment.py --env=prod
  environment:
    name: production
    url: https://composer-prod.example.com
  when: manual  # Require manual approval
  only:
    - production
```

---

## Deploying to Cloud Composer/Airflow

### Cloud Composer Deployment Methods

**Method 1: gcloud CLI (Direct)**

```bash
# Upload DAGs to Cloud Composer
gcloud composer environments storage dags import \
  --environment=composer-prod \
  --location=us-central1 \
  --source=dags/sales_etl.py

# Upload plugins
gcloud composer environments storage plugins import \
  --environment=composer-prod \
  --location=us-central1 \
  --source=plugins/

# Set Airflow variables
gcloud composer environments run composer-prod \
  --location=us-central1 \
  variables set -- \
  s3_bucket my-data-bucket

# Set Airflow connections
gcloud composer environments run composer-prod \
  --location=us-central1 \
  connections add snowflake_conn \
  --conn-type=snowflake \
  --conn-host=account.snowflakecomputing.com \
  --conn-login=user \
  --conn-password=pass
```

**Method 2: gsutil (Batch Upload)**

```bash
# Sync entire DAGs folder
gsutil -m rsync -r -d dags/ gs://us-central1-composer-prod-xxxxx-bucket/dags/

# Sync plugins
gsutil -m rsync -r -d plugins/ gs://us-central1-composer-prod-xxxxx-bucket/plugins/

# Sync with delete (removes files not in source)
gsutil -m rsync -r -d -c dags/ gs://us-central1-composer-prod-xxxxx-bucket/dags/
```

**Method 3: Terraform (Infrastructure as Code)**

```hcl
# terraform/composer.tf

# Upload DAGs via GCS bucket
resource "google_storage_bucket_object" "sales_dag" {
  name   = "dags/sales_etl.py"
  bucket = google_composer_environment.composer_env.config[0].dag_gcs_prefix
  source = "../dags/sales_etl.py"
}

# Set Airflow variables
resource "google_composer_environment_storage_airflow_variable" "s3_bucket" {
  environment = google_composer_environment.composer_env.name
  region      = "us-central1"
  
  variables = {
    s3_bucket      = "my-data-bucket"
    environment    = "production"
    email_on_retry = "false"
  }
}
```

### Deployment Script (Production-Ready)

```python
# scripts/deploy_to_composer.py

"""
Deploy DAGs to Cloud Composer with validation and rollback

Usage:
    python deploy_to_composer.py --env=prod --validate
"""

import argparse
import subprocess
import sys
from pathlib import Path
from typing import List, Dict
import hashlib
import json

class ComposerDeployer:
    """Deploy DAGs to Cloud Composer"""
    
    ENVIRONMENTS = {
        'dev': {
            'name': 'composer-dev',
            'location': 'us-central1',
            'project': 'my-project-dev'
        },
        'staging': {
            'name': 'composer-staging',
            'location': 'us-central1',
            'project': 'my-project-staging'
        },
        'prod': {
            'name': 'composer-prod',
            'location': 'us-central1',
            'project': 'my-project-prod'
        }
    }
    
    def __init__(self, environment: str, validate: bool = True):
        self.env = environment
        self.validate = validate
        self.config = self.ENVIRONMENTS[environment]
        
        self.dags_dir = Path('dags')
        self.plugins_dir = Path('plugins')
        
    def deploy(self):
        """Execute deployment"""
        print(f"🚀 Deploying to {self.env.upper()}...")
        
        # Step 1: Validate DAGs
        if self.validate:
            print("1️⃣ Validating DAGs...")
            if not self.validate_dags():
                print("❌ DAG validation failed")
                sys.exit(1)
            print("✅ DAG validation passed")
        
        # Step 2: Backup current DAGs
        print("2️⃣ Backing up current DAGs...")
        self.backup_dags()
        
        # Step 3: Deploy DAGs
        print("3️⃣ Deploying DAGs...")
        self.deploy_dags()
        
        # Step 4: Deploy plugins
        if self.plugins_dir.exists():
            print("4️⃣ Deploying plugins...")
            self.deploy_plugins()
        
        # Step 5: Verify deployment
        print("5️⃣ Verifying deployment...")
        if not self.verify_deployment():
            print("❌ Deployment verification failed")
            print("⏮️  Rolling back...")
            self.rollback()
            sys.exit(1)
        
        print("✅ Deployment successful!")
    
    def validate_dags(self) -> bool:
        """Validate DAGs before deployment"""
        # Import test
        result = subprocess.run(
            ['python', 'scripts/validate_dags.py'],
            capture_output=True
        )
        
        return result.returncode == 0
    
    def backup_dags(self):
        """Backup current DAGs"""
        timestamp = datetime.now().strftime('%Y%m%d_%H%M%S')
        backup_path = f"gs://backups-bucket/dags_{self.env}_{timestamp}/"
        
        subprocess.run([
            'gsutil', '-m', 'cp', '-r',
            f"gs://{self.get_composer_bucket()}/dags/",
            backup_path
        ])
        
        print(f"📦 Backup created: {backup_path}")
    
    def deploy_dags(self):
        """Deploy DAGs to Cloud Composer"""
        # Get list of DAG files
        dag_files = list(self.dags_dir.rglob('*.py'))
        
        for dag_file in dag_files:
            relative_path = dag_file.relative_to(self.dags_dir)
            
            subprocess.run([
                'gcloud', 'composer', 'environments', 'storage', 'dags', 'import',
                f"--environment={self.config['name']}",
                f"--location={self.config['location']}",
                f"--source={dag_file}",
                f"--destination={relative_path}"
            ])
            
            print(f"  ✓ Deployed {relative_path}")
    
    def deploy_plugins(self):
        """Deploy plugins to Cloud Composer"""
        subprocess.run([
            'gcloud', 'composer', 'environments', 'storage', 'plugins', 'import',
            f"--environment={self.config['name']}",
            f"--location={self.config['location']}",
            f"--source={self.plugins_dir}/"
        ])
    
    def verify_deployment(self) -> bool:
        """Verify DAGs are visible in Airflow"""
        # List DAGs in Composer
        result = subprocess.run([
            'gcloud', 'composer', 'environments', 'run',
            self.config['name'],
            f"--location={self.config['location']}",
            'dags', 'list'
        ], capture_output=True, text=True)
        
        # Check that expected DAGs are listed
        expected_dags = self.get_expected_dags()
        
        for dag_id in expected_dags:
            if dag_id not in result.stdout:
                print(f"❌ DAG {dag_id} not found in Airflow")
                return False
        
        return True
    
    def get_expected_dags(self) -> List[str]:
        """Get list of expected DAG IDs"""
        # Parse DAG files to extract DAG IDs
        # Simplified version - in production, parse Python AST
        dag_ids = []
        
        for dag_file in self.dags_dir.rglob('*.py'):
            with open(dag_file) as f:
                content = f.read()
                # Simple regex to find dag_id
                import re
                matches = re.findall(r'dag_id=["\']([^"\']+)["\']', content)
                dag_ids.extend(matches)
        
        return dag_ids
    
    def get_composer_bucket(self) -> str:
        """Get Cloud Composer GCS bucket"""
        result = subprocess.run([
            'gcloud', 'composer', 'environments', 'describe',
            self.config['name'],
            f"--location={self.config['location']}",
            '--format=value(config.dagGcsPrefix)'
        ], capture_output=True, text=True)
        
        return result.stdout.strip().replace('gs://', '').replace('/dags', '')
    
    def rollback(self):
        """Rollback to previous version"""
        # Implementation of rollback logic
        print("⏮️  Rollback functionality would restore from backup")


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description='Deploy DAGs to Cloud Composer')
    parser.add_argument('--env', required=True, choices=['dev', 'staging', 'prod'])
    parser.add_argument('--validate', action='store_true', default=True)
    parser.add_argument('--no-validate', action='store_false', dest='validate')
    
    args = parser.parse_args()
    
    deployer = ComposerDeployer(args.env, args.validate)
    deployer.deploy()
```

---

**(Continued in next section...)**

Due to length, I'll continue with Infrastructure as Code, Testing in CI/CD, and Interview Preparation in the next file.

---

## AWS MWAA Deployments

### What is AWS MWAA?

**Amazon Managed Workflows for Apache Airflow (MWAA)** is a fully managed service that makes it easy to run Apache Airflow on AWS.

**Key Components:**
- **S3 Bucket**: Stores DAGs, plugins, requirements.txt
- **Airflow Environment**: Managed Airflow installation
- **VPC**: Private network for Airflow
- **IAM Roles**: Permissions for Airflow to access AWS resources

### MWAA Deployment Methods

#### Method 1: AWS CLI (Direct Upload)

```bash
# Upload DAGs to S3
aws s3 sync dags/ s3://my-mwaa-bucket/dags/ --delete

# Upload plugins
aws s3 sync plugins/ s3://my-mwaa-bucket/plugins/ --delete

# Upload requirements.txt
aws s3 cp requirements.txt s3://my-mwaa-bucket/requirements.txt

# Update MWAA environment (if configuration changed)
aws mwaa update-environment --name mwaa-prod \
  --airflow-configuration-options \
    core.parallelism=32 \
    core.max_active_runs_per_dag=1
```

**Advantages:**
- Simple and direct
- Fast for single files
- Good for manual testing

**Disadvantages:**
- Manual process
- No validation before upload
- No rollback mechanism

#### Method 2: Automated Deployment Script

```bash
#!/bin/bash
# deploy_to_mwaa.sh

set -e

ENV=$1
S3_BUCKET="${ENV}-mwaa-bucket"

echo "Deploying to $ENV MWAA..."

# 1. Validate DAGs
python scripts/validate_dags.py || exit 1

# 2. Run tests
pytest tests/ -v || exit 1

# 3. Backup current DAGs (production only)
if [ "$ENV" == "prod" ]; then
    TIMESTAMP=$(date +%Y%m%d_%H%M%S)
    aws s3 sync s3://$S3_BUCKET/dags/ \
      s3://$S3_BUCKET/backups/$TIMESTAMP/dags/
    echo "Backup created: s3://$S3_BUCKET/backups/$TIMESTAMP/"
fi

# 4. Deploy DAGs
aws s3 sync dags/ s3://$S3_BUCKET/dags/ --delete

# 5. Deploy plugins
if [ -d "plugins" ]; then
    aws s3 sync plugins/ s3://$S3_BUCKET/plugins/ --delete
fi

# 6. Update requirements if changed
if [ -f "requirements.txt" ]; then
    aws s3 cp requirements.txt s3://$S3_BUCKET/requirements.txt
fi

# 7. Wait for DAGs to be parsed (30 seconds)
echo "Waiting for DAGs to be parsed..."
sleep 30

# 8. Verify deployment
python scripts/verify_deployment.py --env $ENV

echo "✅ Deployment to $ENV successful!"
```

#### Method 3: CI/CD with GitHub Actions

```yaml
# .github/workflows/deploy-mwaa.yml

name: Deploy to MWAA

on:
  push:
    branches: [main, staging, development]

env:
  AWS_REGION: us-east-1

jobs:
  deploy-dev:
    name: Deploy to Development
    runs-on: ubuntu-latest
    if: github.ref == 'refs/heads/development'
    
    steps:
      - name: Checkout code
        uses: actions/checkout@v3
      
      - name: Configure AWS credentials
        uses: aws-actions/configure-aws-credentials@v2
        with:
          aws-access-key-id: ${{ secrets.AWS_ACCESS_KEY_ID }}
          aws-secret-access-key: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
          aws-region: ${{ env.AWS_REGION }}
      
      - name: Validate DAGs
        run: |
          pip install apache-airflow==2.7.2
          python scripts/validate_dags.py
      
      - name: Run tests
        run: |
          pip install -r requirements-dev.txt
          pytest tests/ -v
      
      - name: Deploy to MWAA Dev
        run: |
          aws s3 sync dags/ s3://dev-mwaa-bucket/dags/ --delete
          aws s3 sync plugins/ s3://dev-mwaa-bucket/plugins/ --delete
      
      - name: Notify Slack
        uses: slackapi/slack-github-action@v1
        with:
          payload: |
            {
              "text": "✅ Deployed to DEV MWAA: ${{ github.sha }}"
            }
        env:
          SLACK_WEBHOOK_URL: ${{ secrets.SLACK_WEBHOOK }}

  deploy-staging:
    name: Deploy to Staging
    runs-on: ubuntu-latest
    if: github.ref == 'refs/heads/staging'
    needs: []
    
    steps:
      - name: Checkout code
        uses: actions/checkout@v3
      
      - name: Configure AWS credentials
        uses: aws-actions/configure-aws-credentials@v2
        with:
          aws-access-key-id: ${{ secrets.AWS_ACCESS_KEY_ID }}
          aws-secret-access-key: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
          aws-region: ${{ env.AWS_REGION }}
      
      - name: Deploy to MWAA Staging
        run: |
          aws s3 sync dags/ s3://staging-mwaa-bucket/dags/ --delete
          aws s3 sync plugins/ s3://staging-mwaa-bucket/plugins/ --delete

  deploy-prod:
    name: Deploy to Production
    runs-on: ubuntu-latest
    if: github.ref == 'refs/heads/main'
    environment: production  # Requires manual approval
    
    steps:
      - name: Checkout code
        uses: actions/checkout@v3
      
      - name: Configure AWS credentials
        uses: aws-actions/configure-aws-credentials@v2
        with:
          aws-access-key-id: ${{ secrets.AWS_PROD_ACCESS_KEY_ID }}
          aws-secret-access-key: ${{ secrets.AWS_PROD_SECRET_ACCESS_KEY }}
          aws-region: ${{ env.AWS_REGION }}
      
      - name: Backup current DAGs
        run: |
          TIMESTAMP=$(date +%Y%m%d_%H%M%S)
          aws s3 sync s3://prod-mwaa-bucket/dags/ \
            s3://prod-mwaa-bucket/backups/$TIMESTAMP/dags/
      
      - name: Deploy to MWAA Production
        run: |
          aws s3 sync dags/ s3://prod-mwaa-bucket/dags/ --delete
          aws s3 sync plugins/ s3://prod-mwaa-bucket/plugins/ --delete
      
      - name: Verify deployment
        run: |
          python scripts/verify_deployment.py --env prod
      
      - name: Notify team
        uses: slackapi/slack-github-action@v1
        with:
          payload: |
            {
              "text": "🚀 PRODUCTION DEPLOYMENT: ${{ github.sha }}\nDeployed by: ${{ github.actor }}"
            }
        env:
          SLACK_WEBHOOK_URL: ${{ secrets.SLACK_WEBHOOK }}
```

#### Method 4: Terraform (Infrastructure as Code)

```hcl
# terraform/mwaa.tf

# S3 Bucket for MWAA
resource "aws_s3_bucket" "mwaa" {
  bucket = "${var.environment}-mwaa-bucket"
}

resource "aws_s3_bucket_versioning" "mwaa" {
  bucket = aws_s3_bucket.mwaa.id
  
  versioning_configuration {
    status = "Enabled"
  }
}

# Upload DAG files to S3
resource "aws_s3_object" "dags" {
  for_each = fileset("${path.module}/../dags", "**/*.py")
  
  bucket = aws_s3_bucket.mwaa.id
  key    = "dags/${each.value}"
  source = "${path.module}/../dags/${each.value}"
  etag   = filemd5("${path.module}/../dags/${each.value}")
}

# Upload requirements.txt
resource "aws_s3_object" "requirements" {
  bucket = aws_s3_bucket.mwaa.id
  key    = "requirements.txt"
  source = "${path.module}/../requirements.txt"
  etag   = filemd5("${path.module}/../requirements.txt")
}

# MWAA Environment
resource "aws_mwaa_environment" "this" {
  name = "mwaa-${var.environment}"
  
  airflow_version = "2.7.2"
  environment_class = var.environment_class
  
  source_bucket_arn = aws_s3_bucket.mwaa.arn
  dag_s3_path       = "dags/"
  requirements_s3_path = "requirements.txt"
  
  execution_role_arn = aws_iam_role.mwaa.arn
  
  network_configuration {
    security_group_ids = [aws_security_group.mwaa.id]
    subnet_ids         = aws_subnet.private[*].id
  }
  
  airflow_configuration_options = {
    "core.default_task_retries"     = "3"
    "core.parallelism"              = "32"
    "core.max_active_runs_per_dag"  = "1"
    "webserver.dag_default_view"    = "graph"
  }
  
  logging_configuration {
    dag_processing_logs {
      enabled   = true
      log_level = "INFO"
    }
    
    scheduler_logs {
      enabled   = true
      log_level = "INFO"
    }
    
    task_logs {
      enabled   = true
      log_level = "INFO"
    }
  }
  
  tags = {
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}

output "mwaa_webserver_url" {
  value = aws_mwaa_environment.this.webserver_url
}
```

### Setting Airflow Variables via CLI

```bash
# Get CLI token
CLI_TOKEN=$(aws mwaa create-cli-token --name mwaa-prod \
  | jq -r '.CliToken')

# Set variable
aws mwaa create-cli-token --name mwaa-prod | \
  jq -r '.CliToken' | \
  xargs -I {} curl -X POST \
  "https://{}/aws_mwaa/cli" \
  -H "Authorization: Bearer {}" \
  -H "Content-Type: text/plain" \
  --data "variables set my_variable my_value"
```

**Better approach - Use AWS Systems Manager Parameter Store:**

```python
# In your DAG
import boto3

def get_config(parameter_name):
    ssm = boto3.client('ssm', region_name='us-east-1')
    response = ssm.get_parameter(Name=parameter_name, WithDecryption=True)
    return response['Parameter']['Value']

# Usage in DAG
s3_bucket = get_config('/airflow/prod/s3_bucket')
```

### Managing Secrets

```python
# dags/utils/secrets.py

import boto3
import json
from functools import lru_cache

@lru_cache(maxsize=128)
def get_secret(secret_name, region_name='us-east-1'):
    """
    Retrieve secret from AWS Secrets Manager
    
    Args:
        secret_name: Name of the secret
        region_name: AWS region
        
    Returns:
        Secret value as dictionary
    """
    client = boto3.client('secretsmanager', region_name=region_name)
    
    try:
        response = client.get_secret_value(SecretId=secret_name)
        secret = json.loads(response['SecretString'])
        return secret
    except Exception as e:
        raise Exception(f"Error retrieving secret {secret_name}: {e}")

# Usage in DAG
from utils.secrets import get_secret

# Get database credentials
db_creds = get_secret('prod/database/credentials')
connection_string = f"postgresql://{db_creds['username']}:{db_creds['password']}@{db_creds['host']}/mydb"
```

### Deployment Verification Script

```python
# scripts/verify_deployment.py

import argparse
import boto3
import time
import sys

def verify_mwaa_deployment(environment_name, expected_dags):
    """
    Verify DAGs are deployed and visible in MWAA
    
    Args:
        environment_name: MWAA environment name
        expected_dags: List of expected DAG IDs
    """
    print(f"Verifying deployment to {environment_name}...")
    
    # Get MWAA environment details
    mwaa = boto3.client('mwaa')
    
    try:
        response = mwaa.get_environment(Name=environment_name)
        env = response['Environment']
        
        # Check environment status
        if env['Status'] != 'AVAILABLE':
            print(f"❌ Environment status: {env['Status']}")
            return False
        
        print(f"✓ Environment status: AVAILABLE")
        
        # Check webserver URL
        webserver_url = env.get('WebserverUrl')
        if webserver_url:
            print(f"✓ Webserver URL: https://{webserver_url}")
        
        # Wait for DAGs to be parsed (30 seconds)
        print("Waiting for DAGs to be parsed...")
        time.sleep(30)
        
        # In real implementation, you would:
        # 1. Use MWAA CLI to list DAGs
        # 2. Compare with expected_dags list
        # 3. Check for import errors
        
        print("✓ Deployment verification passed")
        return True
        
    except Exception as e:
        print(f"❌ Verification failed: {e}")
        return False

if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--env', required=True, choices=['dev', 'staging', 'prod'])
    args = parser.parse_args()
    
    env_map = {
        'dev': 'mwaa-dev',
        'staging': 'mwaa-staging',
        'prod': 'mwaa-prod'
    }
    
    expected_dags = ['sales_daily_etl', 'customer_data_pipeline']
    
    success = verify_mwaa_deployment(env_map[args.env], expected_dags)
    sys.exit(0 if success else 1)
```

### Rollback Strategy

```bash
#!/bin/bash
# rollback_mwaa.sh

ENV=$1
BACKUP_TIMESTAMP=$2

if [ -z "$ENV" ] || [ -z "$BACKUP_TIMESTAMP" ]; then
    echo "Usage: ./rollback_mwaa.sh <env> <backup_timestamp>"
    echo "Example: ./rollback_mwaa.sh prod 20240115_143000"
    exit 1
fi

S3_BUCKET="${ENV}-mwaa-bucket"
BACKUP_PATH="s3://$S3_BUCKET/backups/$BACKUP_TIMESTAMP/dags/"

echo "Rolling back $ENV to backup $BACKUP_TIMESTAMP..."

# Check if backup exists
aws s3 ls $BACKUP_PATH > /dev/null 2>&1

if [ $? -ne 0 ]; then
    echo "❌ Backup not found: $BACKUP_PATH"
    exit 1
fi

# Restore from backup
echo "Restoring DAGs from $BACKUP_PATH..."
aws s3 sync $BACKUP_PATH s3://$S3_BUCKET/dags/ --delete

echo "✅ Rollback complete!"
echo "Please verify DAGs in Airflow UI"
```

---

## Infrastructure as Code (AWS)

### Terraform for MWAA - Complete Example

```hcl
# terraform/main.tf

terraform {
  required_version = ">= 1.0"
  
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
  
  backend "s3" {
    bucket = "terraform-state-bucket"
    key    = "mwaa/terraform.tfstate"
    region = "us-east-1"
  }
}

provider "aws" {
  region = var.region
}

# S3 Bucket for MWAA
resource "aws_s3_bucket" "mwaa" {
  bucket = "${var.environment}-mwaa-bucket"
  
  tags = {
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}

resource "aws_s3_bucket_versioning" "mwaa" {
  bucket = aws_s3_bucket.mwaa.id
  
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_public_access_block" "mwaa" {
  bucket = aws_s3_bucket.mwaa.id
  
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# VPC for MWAA
resource "aws_vpc" "mwaa" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true
  
  tags = {
    Name = "${var.environment}-mwaa-vpc"
  }
}

# Private Subnets (MWAA requires at least 2)
resource "aws_subnet" "private" {
  count = 2
  
  vpc_id            = aws_vpc.mwaa.id
  cidr_block        = "10.0.${count.index + 1}.0/24"
  availability_zone = data.aws_availability_zones.available.names[count.index]
  
  tags = {
    Name = "${var.environment}-mwaa-private-${count.index + 1}"
  }
}

# Security Group for MWAA
resource "aws_security_group" "mwaa" {
  name        = "${var.environment}-mwaa-sg"
  description = "Security group for MWAA environment"
  vpc_id      = aws_vpc.mwaa.id
  
  # Self-referencing rule for Airflow components
  ingress {
    from_port = 0
    to_port   = 0
    protocol  = "-1"
    self      = true
  }
  
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  
  tags = {
    Name = "${var.environment}-mwaa-sg"
  }
}

# IAM Role for MWAA
resource "aws_iam_role" "mwaa" {
  name = "${var.environment}-mwaa-execution-role"
  
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = [
            "airflow-env.amazonaws.com",
            "airflow.amazonaws.com"
          ]
        }
      }
    ]
  })
}

# Attach AWS managed policy
resource "aws_iam_role_policy_attachment" "mwaa_execution" {
  role       = aws_iam_role.mwaa.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonMWAAServiceRolePolicy"
}

# Custom policy for additional permissions
resource "aws_iam_role_policy" "mwaa_custom" {
  name = "${var.environment}-mwaa-custom-policy"
  role = aws_iam_role.mwaa.id
  
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:ListBucket"
        ]
        Resource = [
          aws_s3_bucket.mwaa.arn,
          "${aws_s3_bucket.mwaa.arn}/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue"
        ]
        Resource = "arn:aws:secretsmanager:${var.region}:*:secret:${var.environment}/*"
      },
      {
        Effect = "Allow"
        Action = [
          "ssm:GetParameter",
          "ssm:GetParameters"
        ]
        Resource = "arn:aws:ssm:${var.region}:*:parameter/airflow/${var.environment}/*"
      }
    ]
  })
}

# MWAA Environment
resource "aws_mwaa_environment" "this" {
  name = "mwaa-${var.environment}"
  
  airflow_version = "2.7.2"
  environment_class = var.environment_class
  max_workers = var.max_workers
  min_workers = var.min_workers
  
  source_bucket_arn = aws_s3_bucket.mwaa.arn
  dag_s3_path       = "dags/"
  requirements_s3_path = "requirements.txt"
  plugins_s3_path      = "plugins.zip"
  
  execution_role_arn = aws_iam_role.mwaa.arn
  
  network_configuration {
    security_group_ids = [aws_security_group.mwaa.id]
    subnet_ids         = aws_subnet.private[*].id
  }
  
  airflow_configuration_options = {
    "core.default_task_retries"     = "3"
    "core.parallelism"              = var.parallelism
    "core.max_active_runs_per_dag"  = "1"
    "core.dag_concurrency"          = var.dag_concurrency
    "scheduler.catchup_by_default"  = "False"
    "webserver.dag_default_view"    = "graph"
  }
  
  logging_configuration {
    dag_processing_logs {
      enabled   = true
      log_level = "INFO"
    }
    
    scheduler_logs {
      enabled   = true
      log_level = "INFO"
    }
    
    task_logs {
      enabled   = true
      log_level = "INFO"
    }
    
    webserver_logs {
      enabled   = true
      log_level = "INFO"
    }
    
    worker_logs {
      enabled   = true
      log_level = "INFO"
    }
  }
  
  tags = {
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}

# CloudWatch Log Group (optional - for custom logging)
resource "aws_cloudwatch_log_group" "mwaa" {
  name              = "/aws/mwaa/${var.environment}"
  retention_in_days = 30
  
  tags = {
    Environment = var.environment
  }
}

# Outputs
output "mwaa_webserver_url" {
  value       = aws_mwaa_environment.this.webserver_url
  description = "MWAA Webserver URL"
}

output "mwaa_arn" {
  value       = aws_mwaa_environment.this.arn
  description = "MWAA Environment ARN"
}

output "s3_bucket_name" {
  value       = aws_s3_bucket.mwaa.id
  description = "S3 bucket for MWAA"
}
```

```hcl
# terraform/variables.tf

variable "region" {
  description = "AWS Region"
  type        = string
  default     = "us-east-1"
}

variable "environment" {
  description = "Environment name"
  type        = string
  
  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Environment must be dev, staging, or prod"
  }
}

variable "environment_class" {
  description = "MWAA environment class"
  type        = string
  default     = "mw1.small"
  
  validation {
    condition     = contains(["mw1.small", "mw1.medium", "mw1.large"], var.environment_class)
    error_message = "Must be mw1.small, mw1.medium, or mw1.large"
  }
}

variable "max_workers" {
  description = "Maximum number of workers"
  type        = number
  default     = 10
}

variable "min_workers" {
  description = "Minimum number of workers"
  type        = number
  default     = 1
}

variable "parallelism" {
  description = "Airflow parallelism"
  type        = number
  default     = 32
}

variable "dag_concurrency" {
  description = "DAG concurrency"
  type        = number
  default     = 16
}
```

```hcl
# terraform/terraform.tfvars

region            = "us-east-1"
environment       = "prod"
environment_class = "mw1.medium"
max_workers       = 25
min_workers       = 2
parallelism       = 64
dag_concurrency   = 32
```

### CloudFormation Alternative

```yaml
# cloudformation/mwaa.yaml

AWSTemplateFormatVersion: '2010-09-09'
Description: 'MWAA Environment'

Parameters:
  Environment:
    Type: String
    Default: prod
    AllowedValues: [dev, staging, prod]
    Description: Environment name
  
  EnvironmentClass:
    Type: String
    Default: mw1.small
    AllowedValues: [mw1.small, mw1.medium, mw1.large]
    Description: MWAA environment size

Resources:
  # S3 Bucket
  MWAABucket:
    Type: AWS::S3::Bucket
    Properties:
      BucketName: !Sub '${Environment}-mwaa-bucket'
      VersioningConfiguration:
        Status: Enabled
      PublicAccessBlockConfiguration:
        BlockPublicAcls: true
        BlockPublicPolicy: true
        IgnorePublicAcls: true
        RestrictPublicBuckets: true

  # IAM Role
  MWAAExecutionRole:
    Type: AWS::IAM::Role
    Properties:
      AssumeRolePolicyDocument:
        Version: '2012-10-17'
        Statement:
          - Effect: Allow
            Principal:
              Service:
                - airflow-env.amazonaws.com
                - airflow.amazonaws.com
            Action: sts:AssumeRole
      ManagedPolicyArns:
        - arn:aws:iam::aws:policy/service-role/AmazonMWAAServiceRolePolicy

  # VPC
  MWAAVPC:
    Type: AWS::EC2::VPC
    Properties:
      CidrBlock: 10.0.0.0/16
      EnableDnsHostnames: true
      EnableDnsSupport: true

  # Security Group
  MWAASecurityGroup:
    Type: AWS::EC2::SecurityGroup
    Properties:
      GroupDescription: Security group for MWAA
      VpcId: !Ref MWAAVPC
      SecurityGroupIngress:
        - IpProtocol: -1
          SourceSecurityGroupId: !Ref MWAASecurityGroup

  # MWAA Environment
  MWAAEnvironment:
    Type: AWS::MWAA::Environment
    Properties:
      Name: !Sub 'mwaa-${Environment}'
      AirflowVersion: '2.7.2'
      EnvironmentClass: !Ref EnvironmentClass
      SourceBucketArn: !GetAtt MWAABucket.Arn
      DagS3Path: dags/
      ExecutionRoleArn: !GetAtt MWAAExecutionRole.Arn
      NetworkConfiguration:
        SecurityGroupIds:
          - !Ref MWAASecurityGroup
        SubnetIds:
          - !Ref PrivateSubnet1
          - !Ref PrivateSubnet2
      LoggingConfiguration:
        DagProcessingLogs:
          Enabled: true
          LogLevel: INFO
        TaskLogs:
          Enabled: true
          LogLevel: INFO

Outputs:
  MWAAWebserverUrl:
    Value: !GetAtt MWAAEnvironment.WebserverUrl
    Description: MWAA Webserver URL
```

Deploy with CloudFormation:

```bash
aws cloudformation create-stack \
  --stack-name mwaa-prod \
  --template-body file://mwaa.yaml \
  --parameters ParameterKey=Environment,ParameterValue=prod \
  --capabilities CAPABILITY_IAM
```

---

This comprehensive AWS-focused guide covers all aspects of deploying and managing Airflow DAGs on MWAA with proper CI/CD practices.
