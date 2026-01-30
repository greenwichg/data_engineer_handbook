# CI/CD for Data Engineering - Interview Quick Reference

**Print this and review 30 minutes before your interview!**

---

## 1-Minute Explanation

"CI/CD for data pipelines ensures code quality through automated testing, enables safe deployments through environment promotion (dev→staging→prod), and uses Infrastructure as Code for reproducible infrastructure. I use Git with feature branches, automated tests in GitHub Actions/GitLab CI, deploy DAGs to Cloud Composer via gsutil, and manage infrastructure with Terraform. This prevents production incidents and enables rapid, safe iterations."

---

## Core Concepts (Memorize!)

### Git Branching Strategies

```bash
# Environment Branches (Recommended for Data)
development → staging → production

# Feature Branch Workflow
git checkout development
git checkout -b feature/ETL-123
# Make changes
git push origin feature/ETL-123
# Create PR → development
# After merge, auto-deploy to dev environment
```

### CI/CD Pipeline Stages

```
Code Push →  Lint → Test → Build → Deploy → Validate
```

### Infrastructure as Code

```hcl
# Terraform - Declarative
resource "google_composer_environment" "prod" {
  name = "composer-prod"
  # Configuration...
}

# Apply changes
terraform apply
```

---

## Interview Questions & Answers

### Q1: "Explain your CI/CD process for data pipelines"

**Answer:**
"My CI/CD process has 5 stages:

**1. Code & Review:**
- Feature branch from develop
- Make changes to DAG/SQL
- Create Pull Request
- Automated checks run (lint, tests, security scan)
- Code review by 2+ engineers
- Merge after approval

**2. Continuous Integration:**
```yaml
# GitHub Actions runs on every PR/push
- Lint (black, flake8)
- Unit tests (pytest)
- DAG validation (import test, cycles check)
- Security scan (git-secrets, detect-secrets)
```

**3. Build:**
- Package DAGs and dependencies
- Build Docker image for custom operators (if using)
- Push to ECR (Elastic Container Registry)

**4. Deploy (Environment Promotion):**
```
develop → DEV MWAA (auto via aws s3 sync)
staging → STAGING MWAA (auto via aws s3 sync)
main → PROD MWAA (manual approval)
```

**5. Validate:**
- Smoke tests (DAG visible in UI)
- Integration tests (run sample DAG)
- Data quality checks

**Example from my retail sales pipeline:**
- Merge to develop triggers deploy to dev MWAA
- `aws s3 sync dags/ s3://dev-mwaa-bucket/dags/`
- DAGs auto-parsed by Airflow
- Slack notification on success/failure"

---

### Q2: "What branching strategy do you use and why?"

**Answer:**
"I use **environment-based branching** for data pipelines:

```
production (prod Airflow)
  ↑
staging (staging Airflow)
  ↑
development (dev Airflow)
  ↑
feature branches
```

**Why this works for data:**
1. **Clear mapping:** Each branch = one environment
2. **Controlled promotion:** Test in dev, validate in staging, deploy to prod
3. **Simple deployment:** Merge to branch = deploy to environment
4. **Rollback friendly:** Revert commit = rollback

**Workflow example:**
```bash
# 1. Develop in feature branch
git checkout -b feature/customer-pipeline

# 2. Merge to development → auto-deploy to DEV
git checkout development
git merge feature/customer-pipeline

# 3. Test in dev, then promote to staging
git checkout staging
git merge development  # Auto-deploy to STAGING

# 4. Validate, then promote to prod
git checkout production
git merge staging  # Deploy to PROD (manual approval)
```

**Alternative considered:** GitFlow with release branches, but too complex for data pipelines where we want continuous deployment."

---

### Q3: "How do you deploy DAGs to MWAA (Amazon Managed Airflow)?"

**Answer:**
"I use **automated deployments via CI/CD**:

**Method 1: AWS CLI (in CI/CD)**
```bash
# In GitHub Actions/GitLab CI
aws s3 sync dags/ s3://my-mwaa-bucket/dags/ \
  --delete \
  --exclude ".git/*"
```

**Method 2: AWS S3 API (programmatic)**
```python
import boto3

s3 = boto3.client('s3')
s3.upload_file('dags/sales_etl.py', 
               'my-mwaa-bucket', 
               'dags/sales_etl.py')
```

**Method 3: Terraform (Infrastructure as Code)**
```hcl
resource "aws_s3_object" "dag" {
  bucket = aws_s3_bucket.mwaa_bucket.id
  key    = "dags/sales_etl.py"
  source = "dags/sales_etl.py"
  etag   = filemd5("dags/sales_etl.py")
}
```

**My deployment pipeline:**
```
1. Developer pushes code to feature branch
2. Creates PR → runs automated tests
3. After approval, merges to develop
4. CI/CD (GitHub Actions) triggers:
   - Validates DAGs
   - Runs tests
   - Deploys to dev MWAA via aws s3 sync
   - Runs smoke tests
5. For prod: Manual approval gate before deploy
```

**Safety measures:**
- Backup current DAGs before deploy (production only)
- Smoke test after deploy (check DAG appears)
- Rollback script ready
- Deploy during low-traffic window"

---

### Q4: "What is Infrastructure as Code? Why use it?"

**Answer:**
"Infrastructure as Code (IaC) = Define infrastructure in code files (not manual clicking).

**Tools:**
- **Terraform**: Cloud-agnostic, HCL language
- **CloudFormation**: AWS-native, YAML/JSON
- **CDK**: Use Python/TypeScript for AWS infrastructure

**Example - MWAA with Terraform:**
```hcl
resource "aws_mwaa_environment" "prod" {
  name = "mwaa-prod"
  
  airflow_configuration_options = {
    "core.default_task_retries" = "3"
    "core.parallelism"          = "32"
  }
  
  dag_s3_path = "dags/"
  source_bucket_arn = aws_s3_bucket.mwaa.arn
  execution_role_arn = aws_iam_role.mwaa.arn
  
  network_configuration {
    security_group_ids = [aws_security_group.mwaa.id]
    subnet_ids         = aws_subnet.private[*].id
  }
  
  logging_configuration {
    dag_processing_logs {
      enabled   = true
      log_level = "INFO"
    }
    task_logs {
      enabled   = true
      log_level = "INFO"
    }
  }
}
```

**CloudFormation Alternative:**
```yaml
Resources:
  MWAAEnvironment:
    Type: AWS::MWAA::Environment
    Properties:
      Name: mwaa-prod
      SourceBucketArn: !GetAtt MWAABucket.Arn
      DagS3Path: dags/
      ExecutionRoleArn: !GetAtt MWAAExecutionRole.Arn
```

**Benefits:**
1. **Version Control**: Track infrastructure changes in Git
2. **Reproducible**: Spin up identical environment any time
3. **Documentation**: Code is documentation
4. **Disaster Recovery**: Rebuild entire infrastructure from code
5. **Consistency**: Same infrastructure across dev/staging/prod

**My experience:**
- Managed 3 MWAA environments (dev/staging/prod) with Terraform
- Defined: VPCs, S3 buckets, IAM roles, MWAA config
- Destroy/recreate environments for testing
- No manual configuration drift"

---

### Q5: "How do you handle secrets in CI/CD?"

**Answer:**
"Never commit secrets to Git. Use secret management:

**1. GitHub/GitLab Secrets:**
```yaml
# GitHub Actions
env:
  DB_PASSWORD: ${{ secrets.DB_PASSWORD }}
```

**2. AWS Secrets Manager:**
```python
# In Airflow DAG
import boto3
import json

def get_secret(secret_name):
    client = boto3.client('secretsmanager', region_name='us-east-1')
    response = client.get_secret_value(SecretId=secret_name)
    secret = json.loads(response['SecretString'])
    return secret

# Usage
db_creds = get_secret("prod/database/credentials")
db_password = db_creds['password']
```

**3. Airflow Connections (for DAGs):**
```bash
# Set via AWS CLI (in CI/CD)
aws mwaa create-cli-token --name mwaa-prod | \
  jq -r '.CliToken' | \
  airflow connections add snowflake_conn \
    --conn-type snowflake \
    --conn-host account.snowflakecomputing.com \
    --conn-login $SNOWFLAKE_USER \
    --conn-password $SNOWFLAKE_PASS
```

**4. Environment Variables (MWAA):**
```bash
# In MWAA, set via Terraform
environment_variables = {
  S3_BUCKET = "my-data-bucket"
  # NOT for secrets!
}
```

**5. AWS Systems Manager Parameter Store:**
```python
# For non-sensitive config
import boto3

ssm = boto3.client('ssm')
parameter = ssm.get_parameter(Name='/app/config/region')
region = parameter['Parameter']['Value']
```

**Security checklist:**
- [ ] Secrets in Secrets Manager (not code)
- [ ] .gitignore includes .env, credentials/
- [ ] Pre-commit hook detects secrets
- [ ] Security scan in CI/CD (trufflehog, git-secrets)
- [ ] Rotate secrets regularly
- [ ] Principle of least privilege (IAM roles)
- [ ] Enable secrets encryption (KMS)"

---

### Q6: "Describe a production incident from CI/CD and how you resolved it"

**Answer:**
"**Incident:** Deployed DAG change to production that caused cascading failures.

**What happened:**
- Changed schedule from daily to hourly
- Forgot to update `max_active_runs` setting
- 24 DAG runs queued immediately
- Overwhelmed database connections
- All DAGs in environment failed

**Root cause:**
- Insufficient testing in lower environments
- No validation of `max_active_runs` in CI/CD
- No gradual rollout strategy

**Resolution:**
1. **Immediate (5 min):**
   - Paused problematic DAG in UI
   - Cleared queued DAG runs
   - Restored normal operations

2. **Short-term (30 min):**
   - Reverted deployment: `git revert <commit>`
   - Re-deployed previous version
   - Investigated in dev environment

3. **Long-term (next sprint):**
   - Added DAG config validation in CI/CD:
     ```python
     if dag.schedule_interval == hourly:
         assert dag.max_active_runs <= 3
     ```
   - Added canary deployment for schedule changes
   - Improved testing in staging with production-like load
   - Added pre-deployment checklist
   - Set up better monitoring/alerts

**Lessons learned:**
- Test schedule changes with realistic data volume
- Validate configuration in CI/CD, not just code
- Use feature flags for risky changes
- Have rollback plan before every deployment"

---

### Q7: "What's in your code review checklist for data pipelines?"

**Answer:**
"I have a 7-category checklist:

**1. Functionality:**
- [ ] Solves business requirement
- [ ] Handles edge cases (NULL, duplicates, late data)
- [ ] Idempotent (safe to retry)

**2. Data Quality:**
- [ ] NULL checks on critical columns
- [ ] Duplicate detection
- [ ] Value range validation
- [ ] Schema validation

**3. Performance:**
- [ ] Partitioned appropriately
- [ ] No SELECT *
- [ ] Incremental processing (not full reload)
- [ ] Appropriate batch size

**4. Configuration:**
- [ ] No hardcoded credentials
- [ ] Environment-specific values externalized
- [ ] Correct schedule interval
- [ ] SLAs defined
- [ ] Alerts configured

**5. Testing:**
- [ ] Unit tests (>80% coverage)
- [ ] Integration tests
- [ ] Edge cases tested
- [ ] DAG structure tested

**6. Observability:**
- [ ] Comprehensive logging
- [ ] Metrics emitted (records processed, duration)
- [ ] Errors alerting to right channel

**7. Documentation:**
- [ ] Docstring explains purpose
- [ ] Complex logic commented
- [ ] Data lineage clear
- [ ] Runbook updated

**Example review comment:**
```
"SQL query selects all columns (*) which is inefficient.
Suggest selecting only needed columns:
SELECT sale_id, amount, customer_id FROM sales

Also, consider partitioning by date for better performance."
```"

---

## Branching Comparison Table

| Strategy | Best For | Pros | Cons |
|----------|----------|------|------|
| **GitFlow** | Scheduled releases | Stable main, clear releases | Complex, slower |
| **Trunk-based** | Continuous deployment | Fast integration, simple | Requires discipline |
| **Environment branches** | Data pipelines | Maps to environments | Can diverge if not careful |

---

## CI/CD Tools Comparison

| Tool | Pros | Cons | Best For |
|------|------|------|----------|
| **GitHub Actions** | Easy setup, free, YAML config | Limited to GitHub | GitHub repos |
| **GitLab CI** | Built-in, powerful, free tier | Learning curve | GitLab repos |
| **Jenkins** | Very flexible, plugins | Self-hosted, maintenance | On-prem |
| **CircleCI** | Fast, good caching | Paid | Any repo |

---

## Infrastructure as Code Tools

| Tool | Language | Cloud | Pros | Cons |
|------|----------|-------|------|------|
| **Terraform** | HCL | All clouds | Cloud-agnostic, mature | State management |
| **CloudFormation** | YAML/JSON | AWS | Native AWS, no state file | AWS-only |
| **Pulumi** | Python/TS | All clouds | Use real programming language | Newer |

---

## Deployment Commands Cheat Sheet

```bash
# Git
git checkout -b feature/pipeline      # Create branch
git commit -m "feat: add pipeline"    # Commit
git push origin feature/pipeline      # Push
git merge develop                     # Merge

# MWAA Deployment (S3)
aws s3 sync dags/ s3://my-mwaa-bucket/dags/ --delete

# Or upload single file
aws s3 cp dags/sales_etl.py s3://my-mwaa-bucket/dags/

# Upload plugins
aws s3 sync plugins/ s3://my-mwaa-bucket/plugins/ --delete

# Upload requirements.txt
aws s3 cp requirements.txt s3://my-mwaa-bucket/

# Update MWAA environment (if config changed)
aws mwaa update-environment --name mwaa-prod \
  --airflow-configuration-options \
    core.parallelism=32 \
    core.max_active_runs_per_dag=1

# Terraform
terraform init                        # Initialize
terraform plan                        # Preview
terraform apply                       # Apply
terraform destroy                     # Destroy

# CloudFormation (Alternative)
aws cloudformation create-stack \
  --stack-name mwaa-prod \
  --template-body file://mwaa.yaml

# DAG Validation
python scripts/validate_dags.py       # Validate syntax
airflow dags list                     # List DAGs (local)
airflow dags test <dag_id> <date>     # Test DAG (local)

# Secrets Management
aws secretsmanager create-secret \
  --name prod/db/password \
  --secret-string "my-password"

# View MWAA logs
aws mwaa get-environment --name mwaa-prod
```

---

## Your Project Example

"In my retail sales ETL pipeline:

**Git Workflow:**
```
feature/sales-pipeline → development → staging → production
```

**CI/CD Pipeline (GitHub Actions):**
```
1. PR created → Automated checks run
   - black --check dags/
   - flake8 dags/
   - pytest tests/ --cov=src
   - python validate_dags.py

2. After approval → Merge to develop
   - Triggers deployment to dev MWAA
   - aws s3 sync dags/ s3://dev-mwaa-bucket/dags/
   - Smoke test (check DAG visible)
   - Slack notification

3. Promote to staging → Merge develop to staging
   - Deploy to staging MWAA
   - Run integration tests
   - Data quality validation

4. Promote to prod → Merge staging to main
   - Manual approval required
   - Deploy during maintenance window
   - Health checks
   - Slack notification to team
```

**Infrastructure as Code (Terraform):**
- Defined 3 MWAA environments (dev/staging/prod)
- Managed IAM roles, S3 buckets
- VPC configuration, security groups
- All in Git, peer-reviewed

**AWS Services Used:**
- MWAA (Managed Workflows for Apache Airflow)
- S3 (DAGs, logs, artifacts storage)
- Secrets Manager (database credentials)
- ECR (Docker images for custom operators)
- CloudWatch (monitoring, alerting)
- IAM (roles and permissions)

**Results:**
- Zero manual deployments
- 5-min deploy time (down from 30 min)
- 99.9% deployment success rate
- Full audit trail in Git"

---

## Common Mistakes to Avoid

❌ Committing secrets to Git
✅ Use secret managers

❌ Deploying directly to prod
✅ Test in dev/staging first

❌ No rollback plan
✅ Have revert strategy ready

❌ Manual infrastructure setup
✅ Use Terraform/IaC

❌ Skipping code reviews
✅ Require 2+ approvals

❌ No automated tests
✅ Test in CI/CD pipeline

❌ Ignoring failed tests
✅ Block merge if tests fail

---

## Things That Impress Interviewers

✅ "I use environment-based branching with automated promotion"

✅ "CI/CD validates DAGs, runs tests, deploys via GitHub Actions"

✅ "I manage infrastructure with Terraform in version control"

✅ "Deployments are automated with smoke tests and rollback plans"

✅ "Code reviews check data quality, performance, and testing"

✅ "I use secret managers, never commit credentials"

✅ "Zero manual deployments, full audit trail"

---

## Things to Avoid Saying

❌ "I manually copy DAGs to production"

❌ "We don't have automated testing"

❌ "I deploy on Friday afternoons"

❌ "Code reviews are optional"

❌ "Infrastructure is click-ops in console"

❌ "We don't use version control for infrastructure"

---

## 30-Second Prep Check

Before interview, can you:

- [ ] Explain your branching strategy
- [ ] Describe CI/CD pipeline stages
- [ ] Explain how you deploy to Airflow
- [ ] Describe Infrastructure as Code
- [ ] Give example of code review checklist
- [ ] Explain secret management
- [ ] Describe a production incident
- [ ] Show examples from your project

---

## Sample Interview Exchange

**Interviewer:** "Walk me through your CI/CD process"

**You:** "My CI/CD has 5 stages:

**1. Development & Review:**
- Create feature branch from develop
- Make changes to DAG
- Push → Automated checks run (lint, test, security)
- Code review by 2 engineers
- Merge after approval

**2. Continuous Integration (GitHub Actions):**
```yaml
lint:
  - black --check
  - flake8
validate:
  - python validate_dags.py
test:
  - pytest --cov=80%
security:
  - detect-secrets
  - git-secrets
```

**3. Build:**
- Package DAGs and dependencies
- Build Docker image for custom operators (if using)
- Push to ECR (Elastic Container Registry)

**4. Deploy (Environment Promotion):**
```
develop → DEV MWAA (automatic)
staging → STAGING MWAA (automatic)
main → PROD MWAA (manual approval)
```

**5. Validate:**
- Smoke tests (DAG imported successfully)
- Integration tests (sample DAG run)
- Data quality checks

**Example:** When I merged customer pipeline to develop:
1. GitHub Actions ran all checks (passed)
2. Deployed to dev MWAA via `aws s3 sync`
3. Smoke test verified DAG visible in Airflow UI
4. Slack notification sent
5. Total time: 3 minutes

Then I tested in dev, promoted to staging, validated with production data sample, and finally deployed to prod with manual approval.

**Safety:** Every production deploy has:
- Backup of current DAGs in versioned S3 prefix
- Rollback script ready (`aws s3 sync` previous version)
- Deploy during low-traffic window (Sunday 2 AM)
- CloudWatch alarms for failures
- Automated health checks post-deploy"

---

**You're ready! 🚀**

Remember: Focus on automation, safety, and reproducibility. Interviewers want to see you prevent incidents through good CI/CD practices, not just fix them after they happen.

**Good luck with your interview!**
