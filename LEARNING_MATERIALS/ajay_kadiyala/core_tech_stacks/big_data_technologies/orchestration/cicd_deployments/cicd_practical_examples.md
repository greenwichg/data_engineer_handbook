# CI/CD for Data Engineering - Practical Examples (AWS)

Hands-on examples you can implement immediately for your data pipelines with AWS MWAA.

---

## Setup

```bash
# Install required tools
pip install apache-airflow black flake8 pytest
brew install terraform  # Mac
# or
choco install terraform  # Windows

# Install gcloud CLI
curl https://sdk.cloud.google.com | bash
gcloud init
```

---

## Example 1: Basic GitHub Actions Workflow

### Project Structure

```
data-pipeline/
├── .github/
│   └── workflows/
│       └── ci.yml
├── dags/
│   └── sales_etl.py
├── tests/
│   └── test_sales_etl.py
├── requirements.txt
└── README.md
```

### Create the Workflow

`.github/workflows/ci.yml`:

```yaml
name: CI Pipeline

on:
  push:
    branches: [main, development]
  pull_request:
    branches: [main, development]

jobs:
  test:
    runs-on: ubuntu-latest
    
    steps:
      - uses: actions/checkout@v3
      
      - name: Set up Python
        uses: actions/setup-python@v4
        with:
          python-version: '3.9'
      
      - name: Install dependencies
        run: |
          pip install -r requirements.txt
          pip install pytest black flake8
      
      - name: Lint with flake8
        run: flake8 dags/ tests/ --max-line-length=100
      
      - name: Format check with black
        run: black --check dags/ tests/
      
      - name: Run tests
        run: pytest tests/ -v
```

### Sample DAG

`dags/sales_etl.py`:

```python
from airflow import DAG
from airflow.operators.python import PythonOperator
from datetime import datetime, timedelta

default_args = {
    'owner': 'data-team',
    'depends_on_past': False,
    'email_on_failure': True,
    'email_on_retry': False,
    'retries': 2,
    'retry_delay': timedelta(minutes=5),
}

def extract_sales():
    print("Extracting sales data...")
    return {'status': 'success', 'records': 1000}

def transform_sales(**context):
    print("Transforming sales data...")
    return {'status': 'success'}

def load_sales(**context):
    print("Loading sales data...")
    return {'status': 'success'}

with DAG(
    dag_id='sales_daily_etl',
    default_args=default_args,
    description='Daily sales ETL',
    schedule_interval='0 6 * * *',
    start_date=datetime(2024, 1, 1),
    catchup=False,
    tags=['sales', 'etl'],
) as dag:
    
    extract = PythonOperator(
        task_id='extract_sales',
        python_callable=extract_sales
    )
    
    transform = PythonOperator(
        task_id='transform_sales',
        python_callable=transform_sales
    )
    
    load = PythonOperator(
        task_id='load_sales',
        python_callable=load_sales
    )
    
    extract >> transform >> load
```

---

## Example 2: Deployment Script

`scripts/deploy.sh`:

```bash
#!/bin/bash
# Deploy to AWS MWAA

set -e

ENV=$1

if [[ ! "$ENV" =~ ^(dev|staging|prod)$ ]]; then
    echo "Usage: ./deploy.sh dev|staging|prod"
    exit 1
fi

case $ENV in
    dev)
        S3_BUCKET="dev-mwaa-bucket"
        MWAA_ENV="mwaa-dev"
        ;;
    staging)
        S3_BUCKET="staging-mwaa-bucket"
        MWAA_ENV="mwaa-staging"
        ;;
    prod)
        S3_BUCKET="prod-mwaa-bucket"
        MWAA_ENV="mwaa-prod"
        ;;
esac

echo "Deploying to $ENV..."

# Validate
python scripts/validate_dags.py || exit 1

# Test
pytest tests/ -v || exit 1

# Deploy DAGs
echo "Deploying DAGs to s3://$S3_BUCKET/dags/"
aws s3 sync dags/ s3://$S3_BUCKET/dags/ --delete

# Deploy plugins
if [ -d "plugins" ]; then
    echo "Deploying plugins to s3://$S3_BUCKET/plugins/"
    aws s3 sync plugins/ s3://$S3_BUCKET/plugins/ --delete
fi

# Update requirements if changed
if [ -f "requirements.txt" ]; then
    echo "Uploading requirements.txt"
    aws s3 cp requirements.txt s3://$S3_BUCKET/requirements.txt
fi

echo "✅ Deployed to $ENV"
```

---

## Example 3: DAG Validation

`scripts/validate_dags.py`:

```python
#!/usr/bin/env python3

import sys
from pathlib import Path
import importlib.util

def validate_dags():
    """Validate all DAGs"""
    dags_folder = Path('dags/')
    errors = []
    
    print("Validating DAGs...")
    
    for dag_file in dags_folder.rglob('*.py'):
        try:
            # Import test
            spec = importlib.util.spec_from_file_location(
                "dag", dag_file
            )
            module = importlib.util.module_from_spec(spec)
            spec.loader.exec_module(module)
            
            print(f"✓ {dag_file}")
            
        except Exception as e:
            errors.append(f"✗ {dag_file}: {e}")
    
    if errors:
        print("\nErrors:")
        for error in errors:
            print(f"  {error}")
        return False
    
    print("\n✅ All DAGs valid")
    return True

if __name__ == '__main__':
    success = validate_dags()
    sys.exit(0 if success else 1)
```

---

## Example 4: Terraform for MWAA

`terraform/main.tf`:

```hcl
terraform {
  required_version = ">= 1.0"
  
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.region
}

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

# MWAA Environment
resource "aws_mwaa_environment" "mwaa" {
  name = "mwaa-${var.environment}"
  
  airflow_version = "2.7.2"
  environment_class = var.environment_class
  
  source_bucket_arn = aws_s3_bucket.mwaa.arn
  dag_s3_path       = "dags/"
  
  execution_role_arn = aws_iam_role.mwaa.arn
  
  network_configuration {
    security_group_ids = [aws_security_group.mwaa.id]
    subnet_ids         = aws_subnet.private[*].id
  }
  
  airflow_configuration_options = {
    "core.default_task_retries"     = "3"
    "core.parallelism"              = "32"
    "core.max_active_runs_per_dag"  = "1"
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
}

# IAM Role for MWAA
resource "aws_iam_role" "mwaa" {
  name = "mwaa-${var.environment}-execution-role"
  
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

resource "aws_iam_role_policy_attachment" "mwaa_execution" {
  role       = aws_iam_role.mwaa.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonMWAAServiceRolePolicy"
}

output "mwaa_webserver_url" {
  value = aws_mwaa_environment.mwaa.webserver_url
}

output "mwaa_arn" {
  value = aws_mwaa_environment.mwaa.arn
}
```

`terraform/variables.tf`:

```hcl
variable "region" {
  description = "AWS Region"
  type        = string
  default     = "us-east-1"
}

variable "environment" {
  description = "Environment"
  type        = string
  
  validation {
    condition = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Must be dev, staging, or prod"
  }
}

variable "environment_class" {
  description = "MWAA environment size"
  type        = string
  default     = "mw1.small"
}
```

### Deploy Terraform

```bash
cd terraform/
terraform init
terraform plan
terraform apply
```

---

## Example 5: Pre-commit Hooks

`.pre-commit-config.yaml`:

```yaml
repos:
  - repo: https://github.com/psf/black
    rev: 23.3.0
    hooks:
      - id: black
  
  - repo: https://github.com/PyCQA/flake8
    rev: 6.0.0
    hooks:
      - id: flake8
        args: [--max-line-length=100]
  
  - repo: local
    hooks:
      - id: validate-dags
        name: Validate DAGs
        entry: python scripts/validate_dags.py
        language: system
        pass_filenames: false
```

### Install

```bash
pip install pre-commit
pre-commit install

# Run manually
pre-commit run --all-files
```

---

## Example 6: Complete pytest Tests

`tests/test_sales_etl.py`:

```python
import pytest
from airflow.models import DagBag

class TestSalesDAG:
    
    @pytest.fixture(scope="class")
    def dagbag(self):
        return DagBag(dag_folder='dags/', include_examples=False)
    
    def test_dag_loaded(self, dagbag):
        assert len(dagbag.import_errors) == 0
        assert 'sales_daily_etl' in dagbag.dags
    
    def test_dag_structure(self, dagbag):
        dag = dagbag.get_dag('sales_daily_etl')
        
        assert dag.schedule_interval == '0 6 * * *'
        assert dag.catchup is False
        
        task_ids = [t.task_id for t in dag.tasks]
        assert 'extract_sales' in task_ids
        assert 'transform_sales' in task_ids
        assert 'load_sales' in task_ids
    
    def test_dependencies(self, dagbag):
        dag = dagbag.get_dag('sales_daily_etl')
        
        extract = dag.get_task('extract_sales')
        transform = dag.get_task('transform_sales')
        
        assert 'transform_sales' in extract.downstream_task_ids
        assert 'extract_sales' in transform.upstream_task_ids
```

### Run Tests

```bash
pytest tests/ -v
pytest --cov=dags --cov-report=html
```

---

## Quick Commands

```bash
# Git
git checkout -b feature/pipeline    # New branch
git add .                           # Stage
git commit -m "feat: Add pipeline"  # Commit
git push origin feature/pipeline    # Push

# AWS MWAA Deployment
aws s3 sync dags/ s3://my-mwaa-bucket/dags/ --delete
aws s3 sync plugins/ s3://my-mwaa-bucket/plugins/ --delete
aws s3 cp requirements.txt s3://my-mwaa-bucket/

# Update MWAA environment configuration
aws mwaa update-environment --name mwaa-prod \
  --airflow-configuration-options core.parallelism=32

# Terraform
terraform init
terraform plan
terraform apply

# Testing
pytest tests/ -v
pytest --cov=dags

# Pre-commit
pre-commit install
pre-commit run --all-files
```

---

**You now have complete CI/CD examples ready to use! 🚀**
