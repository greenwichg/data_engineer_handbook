# Data Testing & Quality - Complete Interview Guide

A comprehensive guide to data validation, testing frameworks, synthetic data generation, and quality assurance for data engineering interviews.

---

## Table of Contents

1. [Data Validation Frameworks](#data-validation-frameworks)
2. [Great Expectations](#great-expectations)
3. [Custom Validation Patterns](#custom-validation-patterns)
4. [Synthetic Test Data](#synthetic-test-data)
5. [Boundary Testing](#boundary-testing)
6. [Regression Testing](#regression-testing)
7. [Integration Testing](#integration-testing)
8. [Interview Preparation](#interview-preparation)

---

## Data Validation Frameworks

### What is Data Quality Testing?

**Data Quality Testing** = Verifying data meets expectations for:
- **Completeness**: No missing required values
- **Accuracy**: Values are correct and precise
- **Consistency**: Same data across systems
- **Validity**: Conforms to rules and constraints
- **Timeliness**: Data is up-to-date
- **Uniqueness**: No unexpected duplicates

### Why Data Validation Frameworks?

```python
# Without framework (manual checks)
assert df['age'].between(0, 120).all()
assert df['email'].str.contains('@').all()
assert df['date'].notnull().all()
# Hard to maintain, no documentation, no history

# With framework (Great Expectations)
validator.expect_column_values_to_be_between('age', 0, 120)
validator.expect_column_values_to_match_regex('email', r'.*@.*\..*')
validator.expect_column_values_to_not_be_null('date')
# Self-documenting, tracked, reportable
```

### Framework Comparison

| Framework | Pros | Cons | Best For |
|-----------|------|------|----------|
| **Great Expectations** | Rich expectations, data docs, integrations | Learning curve, setup overhead | Production pipelines |
| **Deequ** (AWS) | Scala/Spark native, fast | JVM only, less Python-friendly | Big data on Spark |
| **Pandera** | Pythonic, lightweight | Pandas-only | Simple validation |
| **Custom** | Full control, simple | Maintenance burden | Specific use cases |

---

## Great Expectations

### What is Great Expectations?

**Great Expectations (GE)** = Open-source data validation framework that helps you:
- Define expectations about your data
- Validate data against those expectations
- Generate documentation automatically
- Track validation results over time

### Core Concepts

```python
# 1. Data Context - Configuration and storage
context = ge.data_context.DataContext()

# 2. Batch - Data to validate
batch = context.get_batch(batch_kwargs, expectation_suite_name)

# 3. Expectation Suite - Set of expectations
suite = context.create_expectation_suite("sales_expectations")

# 4. Validator - Validates data against suite
validator = context.get_validator(batch, expectation_suite_name)

# 5. Checkpoint - Automated validation workflow
checkpoint = context.get_checkpoint("sales_checkpoint")
```

### Basic Great Expectations Setup

```bash
# Install
pip install great_expectations

# Initialize project
great_expectations init

# Creates structure:
great_expectations/
├── expectations/          # Expectation suites
├── checkpoints/          # Validation workflows
├── plugins/              # Custom expectations
├── uncommitted/          # Local data, not in git
└── great_expectations.yml  # Configuration
```

### Creating Expectations

```python
import great_expectations as ge
import pandas as pd

# Load data as GE DataFrame
df = ge.read_csv('sales_data.csv')

# Or convert existing DataFrame
df = ge.from_pandas(df)

# ============================================================================
# Column Existence
# ============================================================================
df.expect_table_columns_to_match_ordered_list([
    'sale_id', 'customer_id', 'product_id', 'amount', 'date'
])

# ============================================================================
# Completeness (No NULLs)
# ============================================================================
df.expect_column_values_to_not_be_null('sale_id')
df.expect_column_values_to_not_be_null('customer_id')
df.expect_column_values_to_not_be_null('amount')

# ============================================================================
# Uniqueness
# ============================================================================
df.expect_column_values_to_be_unique('sale_id')

# ============================================================================
# Value Ranges
# ============================================================================
df.expect_column_values_to_be_between(
    column='amount',
    min_value=0,
    max_value=1000000
)

df.expect_column_values_to_be_between(
    column='quantity',
    min_value=1,
    max_value=10000
)

# ============================================================================
# Data Types
# ============================================================================
df.expect_column_values_to_be_of_type('sale_id', 'int64')
df.expect_column_values_to_be_of_type('amount', 'float64')
df.expect_column_values_to_be_of_type('date', 'datetime64')

# ============================================================================
# String Patterns
# ============================================================================
df.expect_column_values_to_match_regex(
    column='email',
    regex=r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$'
)

df.expect_column_values_to_match_regex(
    column='product_id',
    regex=r'^P\d{6}$'  # Format: P123456
)

# ============================================================================
# Set Membership
# ============================================================================
df.expect_column_values_to_be_in_set(
    column='region',
    value_set=['US-EAST', 'US-WEST', 'EUROPE', 'ASIA-PACIFIC']
)

df.expect_column_values_to_be_in_set(
    column='status',
    value_set=['pending', 'completed', 'cancelled']
)

# ============================================================================
# Statistical Properties
# ============================================================================
df.expect_column_mean_to_be_between(
    column='amount',
    min_value=50,
    max_value=500
)

df.expect_column_stdev_to_be_between(
    column='amount',
    min_value=10,
    max_value=200
)

# ============================================================================
# Row Count
# ============================================================================
df.expect_table_row_count_to_be_between(min_value=100, max_value=1000000)

# ============================================================================
# Custom Business Logic
# ============================================================================
df.expect_column_pair_values_to_be_equal(
    column_A='total_amount',
    column_B='unit_price',  # Actually checking A >= B
    or_equal=True,
    ignore_row_if='either_value_is_missing'
)

# Save expectations to suite
expectation_suite = df.get_expectation_suite(discard_failed_expectations=False)
df.save_expectation_suite(expectation_suite, 'sales_expectations.json')
```

### Running Validations

```python
import great_expectations as ge
from great_expectations.checkpoint import SimpleCheckpoint

# 1. Set up context
context = ge.data_context.DataContext()

# 2. Create checkpoint configuration
checkpoint_config = {
    "name": "sales_checkpoint",
    "config_version": 1.0,
    "class_name": "SimpleCheckpoint",
    "validations": [
        {
            "batch_request": {
                "datasource_name": "my_datasource",
                "data_connector_name": "default_inferred_data_connector_name",
                "data_asset_name": "sales_data.csv",
            },
            "expectation_suite_name": "sales_expectations"
        }
    ]
}

# 3. Add checkpoint
context.add_checkpoint(**checkpoint_config)

# 4. Run checkpoint
results = context.run_checkpoint(
    checkpoint_name="sales_checkpoint",
    batch_request={
        "path": "/path/to/sales_data.csv",
        "data_connector_query": {"index": -1}  # Latest file
    }
)

# 5. Check results
if results["success"]:
    print("✓ All expectations passed!")
else:
    print("✗ Some expectations failed")
    
# 6. View details
for validation_result in results.run_results.values():
    print(f"Validation success: {validation_result['success']}")
    print(f"Statistics: {validation_result['statistics']}")
```

### Great Expectations in Airflow

```python
# dags/sales_validation_dag.py

from airflow import DAG
from airflow.operators.python import PythonOperator
from datetime import datetime
import great_expectations as ge

def validate_sales_data(**context):
    """Validate sales data using Great Expectations"""
    
    # Get data path from XCom
    ti = context['task_instance']
    data_path = ti.xcom_pull(task_ids='extract_sales')
    
    # Set up GE context
    ge_context = ge.data_context.DataContext()
    
    # Run validation checkpoint
    results = ge_context.run_checkpoint(
        checkpoint_name="sales_checkpoint",
        batch_request={
            "path": data_path,
            "data_connector_query": {"index": -1}
        }
    )
    
    # Check results
    if not results["success"]:
        # Get failed expectations
        failed = []
        for result in results.run_results.values():
            for expectation_result in result['results']:
                if not expectation_result['success']:
                    failed.append({
                        'expectation': expectation_result['expectation_config']['expectation_type'],
                        'column': expectation_result['expectation_config'].get('kwargs', {}).get('column'),
                        'details': expectation_result['result']
                    })
        
        # Log failures
        error_msg = f"Data validation failed: {len(failed)} expectations failed"
        context['task_instance'].log.error(error_msg)
        
        # Store in XCom for monitoring
        ti.xcom_push(key='validation_failures', value=failed)
        
        raise ValueError(error_msg)
    
    # Store success metrics
    ti.xcom_push(key='validation_status', value='passed')
    ti.xcom_push(key='validated_records', value=results['statistics']['evaluated_expectations'])
    
    return {'status': 'success', 'results': results}

with DAG(
    dag_id='sales_etl_with_validation',
    start_date=datetime(2024, 1, 1),
    schedule_interval='@daily',
    catchup=False
) as dag:
    
    extract = PythonOperator(
        task_id='extract_sales',
        python_callable=extract_sales_data
    )
    
    validate = PythonOperator(
        task_id='validate_sales',
        python_callable=validate_sales_data
    )
    
    load = PythonOperator(
        task_id='load_to_warehouse',
        python_callable=load_to_snowflake
    )
    
    extract >> validate >> load
```

---

## Custom Validation Patterns

### Simple Custom Validator

```python
# src/data_quality/validators.py

from typing import Dict, List, Any
import pandas as pd
import logging

logger = logging.getLogger(__name__)

class DataQualityValidator:
    """Custom data quality validation"""
    
    def __init__(self):
        self.results = []
    
    def validate_dataframe(
        self, 
        df: pd.DataFrame, 
        rules: Dict[str, Any]
    ) -> Dict[str, Any]:
        """
        Validate DataFrame against rules
        
        Args:
            df: DataFrame to validate
            rules: Dictionary of validation rules
            
        Returns:
            Validation results
        """
        self.results = []
        
        # Check required columns
        if 'required_columns' in rules:
            self._check_required_columns(df, rules['required_columns'])
        
        # Check no nulls
        if 'no_null_columns' in rules:
            self._check_no_nulls(df, rules['no_null_columns'])
        
        # Check unique columns
        if 'unique_columns' in rules:
            self._check_uniqueness(df, rules['unique_columns'])
        
        # Check value ranges
        if 'value_ranges' in rules:
            self._check_value_ranges(df, rules['value_ranges'])
        
        # Check set membership
        if 'valid_values' in rules:
            self._check_valid_values(df, rules['valid_values'])
        
        # Check row count
        if 'row_count' in rules:
            self._check_row_count(df, rules['row_count'])
        
        # Check data freshness
        if 'freshness' in rules:
            self._check_freshness(df, rules['freshness'])
        
        # Summarize results
        passed = sum(1 for r in self.results if r['passed'])
        failed = len(self.results) - passed
        
        return {
            'passed': failed == 0,
            'total_checks': len(self.results),
            'passed_checks': passed,
            'failed_checks': failed,
            'results': self.results
        }
    
    def _check_required_columns(self, df: pd.DataFrame, columns: List[str]):
        """Check that required columns exist"""
        missing = set(columns) - set(df.columns)
        
        if missing:
            self.results.append({
                'check': 'required_columns',
                'passed': False,
                'message': f"Missing columns: {missing}"
            })
            logger.error(f"Missing columns: {missing}")
        else:
            self.results.append({
                'check': 'required_columns',
                'passed': True,
                'message': "All required columns present"
            })
    
    def _check_no_nulls(self, df: pd.DataFrame, columns: List[str]):
        """Check that specified columns have no nulls"""
        for col in columns:
            null_count = df[col].isnull().sum()
            
            if null_count > 0:
                null_pct = (null_count / len(df)) * 100
                self.results.append({
                    'check': f'no_nulls_{col}',
                    'passed': False,
                    'message': f"Column {col} has {null_count} nulls ({null_pct:.2f}%)"
                })
                logger.error(f"Column {col} has {null_count} nulls")
            else:
                self.results.append({
                    'check': f'no_nulls_{col}',
                    'passed': True,
                    'message': f"Column {col} has no nulls"
                })
    
    def _check_uniqueness(self, df: pd.DataFrame, columns: List[str]):
        """Check that specified columns have unique values"""
        for col in columns:
            duplicates = df[col].duplicated().sum()
            
            if duplicates > 0:
                self.results.append({
                    'check': f'unique_{col}',
                    'passed': False,
                    'message': f"Column {col} has {duplicates} duplicates"
                })
                logger.error(f"Column {col} has {duplicates} duplicates")
            else:
                self.results.append({
                    'check': f'unique_{col}',
                    'passed': True,
                    'message': f"Column {col} values are unique"
                })
    
    def _check_value_ranges(self, df: pd.DataFrame, ranges: Dict[str, Dict]):
        """Check that values are within specified ranges"""
        for col, bounds in ranges.items():
            min_val = bounds.get('min')
            max_val = bounds.get('max')
            
            out_of_range = 0
            
            if min_val is not None:
                out_of_range += (df[col] < min_val).sum()
            
            if max_val is not None:
                out_of_range += (df[col] > max_val).sum()
            
            if out_of_range > 0:
                self.results.append({
                    'check': f'range_{col}',
                    'passed': False,
                    'message': f"Column {col} has {out_of_range} values out of range [{min_val}, {max_val}]"
                })
                logger.error(f"Column {col} has {out_of_range} values out of range")
            else:
                self.results.append({
                    'check': f'range_{col}',
                    'passed': True,
                    'message': f"Column {col} values in range [{min_val}, {max_val}]"
                })
    
    def _check_valid_values(self, df: pd.DataFrame, valid_sets: Dict[str, List]):
        """Check that values are in valid sets"""
        for col, valid_values in valid_sets.items():
            invalid = ~df[col].isin(valid_values)
            invalid_count = invalid.sum()
            
            if invalid_count > 0:
                invalid_values = df[col][invalid].unique()[:5]  # Show first 5
                self.results.append({
                    'check': f'valid_values_{col}',
                    'passed': False,
                    'message': f"Column {col} has {invalid_count} invalid values. Examples: {invalid_values}"
                })
                logger.error(f"Column {col} has invalid values: {invalid_values}")
            else:
                self.results.append({
                    'check': f'valid_values_{col}',
                    'passed': True,
                    'message': f"Column {col} all values valid"
                })
    
    def _check_row_count(self, df: pd.DataFrame, count_rules: Dict):
        """Check row count is within expected range"""
        row_count = len(df)
        min_count = count_rules.get('min', 0)
        max_count = count_rules.get('max', float('inf'))
        
        if row_count < min_count or row_count > max_count:
            self.results.append({
                'check': 'row_count',
                'passed': False,
                'message': f"Row count {row_count} not in range [{min_count}, {max_count}]"
            })
            logger.error(f"Row count {row_count} out of range")
        else:
            self.results.append({
                'check': 'row_count',
                'passed': True,
                'message': f"Row count {row_count} in valid range"
            })
    
    def _check_freshness(self, df: pd.DataFrame, freshness_rules: Dict):
        """Check data freshness"""
        from datetime import datetime, timedelta
        
        date_col = freshness_rules['column']
        max_age_hours = freshness_rules['max_age_hours']
        
        max_date = df[date_col].max()
        age_hours = (datetime.now() - max_date).total_seconds() / 3600
        
        if age_hours > max_age_hours:
            self.results.append({
                'check': 'freshness',
                'passed': False,
                'message': f"Data is {age_hours:.1f} hours old (max: {max_age_hours})"
            })
            logger.error(f"Data is stale: {age_hours:.1f} hours old")
        else:
            self.results.append({
                'check': 'freshness',
                'passed': True,
                'message': f"Data is fresh ({age_hours:.1f} hours old)"
            })

# Usage
validator = DataQualityValidator()

rules = {
    'required_columns': ['sale_id', 'customer_id', 'amount', 'date'],
    'no_null_columns': ['sale_id', 'customer_id', 'amount'],
    'unique_columns': ['sale_id'],
    'value_ranges': {
        'amount': {'min': 0, 'max': 1000000},
        'quantity': {'min': 1, 'max': 10000}
    },
    'valid_values': {
        'region': ['US-EAST', 'US-WEST', 'EUROPE', 'ASIA-PACIFIC'],
        'status': ['pending', 'completed', 'cancelled']
    },
    'row_count': {'min': 100, 'max': 1000000},
    'freshness': {'column': 'date', 'max_age_hours': 24}
}

results = validator.validate_dataframe(df, rules)

if not results['passed']:
    raise ValueError(f"Data quality checks failed: {results['failed_checks']} failures")
```

### Pandera - Lightweight Alternative

```python
import pandera as pa
from pandera import Column, Check

# Define schema
sales_schema = pa.DataFrameSchema({
    "sale_id": Column(pa.Int, checks=[
        Check.greater_than(0),
        Check(lambda s: s.is_unique, error="sale_id must be unique")
    ]),
    "customer_id": Column(pa.String, nullable=False),
    "amount": Column(pa.Float, checks=[
        Check.in_range(min_value=0, max_value=1000000)
    ]),
    "quantity": Column(pa.Int, checks=[
        Check.in_range(min_value=1, max_value=10000)
    ]),
    "region": Column(pa.String, checks=[
        Check.isin(['US-EAST', 'US-WEST', 'EUROPE', 'ASIA-PACIFIC'])
    ]),
    "date": Column(pa.DateTime, nullable=False)
})

# Validate
try:
    validated_df = sales_schema.validate(df)
    print("✓ Data validation passed")
except pa.errors.SchemaError as e:
    print(f"✗ Data validation failed: {e}")
    # Can still get validated data with failures filtered
    validated_df = sales_schema.validate(df, lazy=True)
```

---

## Synthetic Test Data

### Why Synthetic Test Data?

**Synthetic Data** = Artificially generated data that mimics real data patterns.

**Benefits:**
- Test edge cases without finding real examples
- No PII/privacy concerns
- Generate large volumes quickly
- Reproducible tests
- Test rare scenarios

### Faker - Generate Realistic Data

```python
from faker import Faker
import pandas as pd
import random

fake = Faker()

def generate_sales_data(n_records: int = 1000) -> pd.DataFrame:
    """
    Generate synthetic sales data
    
    Args:
        n_records: Number of records to generate
        
    Returns:
        DataFrame with synthetic sales data
    """
    data = []
    
    regions = ['US-EAST', 'US-WEST', 'EUROPE', 'ASIA-PACIFIC']
    statuses = ['completed', 'pending', 'cancelled']
    payment_methods = ['credit_card', 'debit_card', 'paypal', 'bank_transfer']
    
    for i in range(n_records):
        quantity = random.randint(1, 10)
        unit_price = round(random.uniform(10, 500), 2)
        total_amount = round(quantity * unit_price, 2)
        discount = round(random.uniform(0, total_amount * 0.2), 2)
        
        record = {
            'sale_id': i + 1,
            'customer_id': fake.uuid4(),
            'customer_name': fake.name(),
            'email': fake.email(),
            'product_id': f"P{random.randint(100000, 999999)}",
            'product_name': fake.catch_phrase(),
            'quantity': quantity,
            'unit_price': unit_price,
            'total_amount': total_amount,
            'discount_amount': discount if random.random() > 0.7 else 0,
            'net_amount': total_amount - discount,
            'region': random.choice(regions),
            'status': random.choice(statuses),
            'payment_method': random.choice(payment_methods),
            'sale_date': fake.date_time_between(start_date='-30d', end_date='now'),
            'created_at': fake.date_time_between(start_date='-30d', end_date='now')
        }
        
        data.append(record)
    
    return pd.DataFrame(data)

# Generate data
df_synthetic = generate_sales_data(1000)
print(df_synthetic.head())
```

### Generate Edge Cases

```python
def generate_edge_case_data() -> pd.DataFrame:
    """Generate data with edge cases for testing"""
    
    data = []
    
    # Edge case 1: NULL values
    data.append({
        'sale_id': 1,
        'customer_id': None,  # NULL customer_id
        'amount': 100.0,
        'quantity': 1,
        'date': pd.Timestamp('2024-01-15')
    })
    
    # Edge case 2: Zero amount
    data.append({
        'sale_id': 2,
        'customer_id': 'C002',
        'amount': 0.0,  # Zero amount
        'quantity': 0,  # Zero quantity
        'date': pd.Timestamp('2024-01-15')
    })
    
    # Edge case 3: Negative values
    data.append({
        'sale_id': 3,
        'customer_id': 'C003',
        'amount': -50.0,  # Negative amount (refund?)
        'quantity': -1,
        'date': pd.Timestamp('2024-01-15')
    })
    
    # Edge case 4: Extreme values
    data.append({
        'sale_id': 4,
        'customer_id': 'C004',
        'amount': 99999999.99,  # Very large amount
        'quantity': 100000,
        'date': pd.Timestamp('2024-01-15')
    })
    
    # Edge case 5: Invalid date
    data.append({
        'sale_id': 5,
        'customer_id': 'C005',
        'amount': 100.0,
        'quantity': 1,
        'date': pd.Timestamp('2050-01-01')  # Future date
    })
    
    # Edge case 6: Duplicate ID
    data.append({
        'sale_id': 1,  # Duplicate!
        'customer_id': 'C006',
        'amount': 200.0,
        'quantity': 2,
        'date': pd.Timestamp('2024-01-15')
    })
    
    # Edge case 7: Invalid region
    data.append({
        'sale_id': 7,
        'customer_id': 'C007',
        'amount': 150.0,
        'quantity': 1,
        'region': 'INVALID-REGION',  # Not in valid set
        'date': pd.Timestamp('2024-01-15')
    })
    
    return pd.DataFrame(data)

# Use in tests
edge_cases_df = generate_edge_case_data()

# Test that validator catches these issues
validator = DataQualityValidator()
results = validator.validate_dataframe(edge_cases_df, rules)

assert not results['passed'], "Validator should catch edge cases"
assert results['failed_checks'] >= 5, "Should catch multiple issues"
```

### Data Factories with Pytest

```python
# tests/conftest.py

import pytest
import pandas as pd
from faker import Faker
import random

@pytest.fixture
def fake():
    """Faker instance"""
    return Faker()

@pytest.fixture
def sample_sales_df():
    """Generate small sample sales DataFrame"""
    return pd.DataFrame({
        'sale_id': [1, 2, 3, 4, 5],
        'amount': [100.0, 200.0, 150.0, 300.0, 175.0],
        'quantity': [1, 2, 1, 3, 2],
        'region': ['US-EAST', 'US-WEST', 'EUROPE', 'US-EAST', 'ASIA-PACIFIC']
    })

@pytest.fixture
def large_sales_df():
    """Generate large sales DataFrame for performance testing"""
    n_records = 100000
    return pd.DataFrame({
        'sale_id': range(1, n_records + 1),
        'amount': [random.uniform(10, 1000) for _ in range(n_records)],
        'quantity': [random.randint(1, 10) for _ in range(n_records)],
        'region': [random.choice(['US-EAST', 'US-WEST', 'EUROPE', 'ASIA-PACIFIC']) 
                   for _ in range(n_records)]
    })

@pytest.fixture
def sales_with_nulls():
    """DataFrame with NULL values"""
    df = pd.DataFrame({
        'sale_id': [1, 2, None, 4, 5],
        'customer_id': ['C1', None, 'C3', 'C4', 'C5'],
        'amount': [100.0, 200.0, 150.0, None, 175.0]
    })
    return df

@pytest.fixture
def sales_with_duplicates():
    """DataFrame with duplicate sale_ids"""
    return pd.DataFrame({
        'sale_id': [1, 2, 2, 3, 3],  # Duplicates: 2, 3
        'amount': [100.0, 200.0, 250.0, 150.0, 175.0]
    })

# Usage in tests
def test_validator_rejects_nulls(validator, sales_with_nulls):
    """Test that validator catches NULL values"""
    rules = {'no_null_columns': ['sale_id', 'customer_id']}
    results = validator.validate_dataframe(sales_with_nulls, rules)
    assert not results['passed']
    assert results['failed_checks'] >= 1

def test_validator_rejects_duplicates(validator, sales_with_duplicates):
    """Test that validator catches duplicates"""
    rules = {'unique_columns': ['sale_id']}
    results = validator.validate_dataframe(sales_with_duplicates, rules)
    assert not results['passed']
```

---

## Boundary Testing

### What is Boundary Testing?

**Boundary Testing** = Testing at the edges of valid input ranges.

**Why?** Bugs often occur at boundaries:
- Min/max values
- NULL/empty values
- Zero values
- Type boundaries

### Boundary Test Cases

```python
# tests/test_boundary_cases.py

import pytest
import pandas as pd
from src.data_quality.validators import DataQualityValidator

class TestBoundaryConditions:
    """Test boundary cases for data validation"""
    
    @pytest.fixture
    def validator(self):
        return DataQualityValidator()
    
    @pytest.fixture
    def validation_rules(self):
        return {
            'required_columns': ['sale_id', 'amount'],
            'no_null_columns': ['sale_id'],
            'unique_columns': ['sale_id'],
            'value_ranges': {
                'amount': {'min': 0, 'max': 1000000},
                'quantity': {'min': 1, 'max': 10000}
            }
        }
    
    def test_empty_dataframe(self, validator, validation_rules):
        """Test with empty DataFrame"""
        df = pd.DataFrame(columns=['sale_id', 'amount', 'quantity'])
        
        # Should fail row count check if min_rows specified
        rules_with_count = {**validation_rules, 'row_count': {'min': 1}}
        results = validator.validate_dataframe(df, rules_with_count)
        
        assert not results['passed']
    
    def test_single_row(self, validator, validation_rules):
        """Test with single row"""
        df = pd.DataFrame({
            'sale_id': [1],
            'amount': [100.0],
            'quantity': [1]
        })
        
        results = validator.validate_dataframe(df, validation_rules)
        assert results['passed']
    
    def test_minimum_valid_amount(self, validator, validation_rules):
        """Test amount at minimum boundary (0)"""
        df = pd.DataFrame({
            'sale_id': [1],
            'amount': [0.0],  # Minimum valid
            'quantity': [1]
        })
        
        results = validator.validate_dataframe(df, validation_rules)
        assert results['passed']
    
    def test_below_minimum_amount(self, validator, validation_rules):
        """Test amount below minimum (negative)"""
        df = pd.DataFrame({
            'sale_id': [1],
            'amount': [-0.01],  # Below minimum
            'quantity': [1]
        })
        
        results = validator.validate_dataframe(df, validation_rules)
        assert not results['passed']
    
    def test_maximum_valid_amount(self, validator, validation_rules):
        """Test amount at maximum boundary"""
        df = pd.DataFrame({
            'sale_id': [1],
            'amount': [1000000.0],  # Maximum valid
            'quantity': [1]
        })
        
        results = validator.validate_dataframe(df, validation_rules)
        assert results['passed']
    
    def test_above_maximum_amount(self, validator, validation_rules):
        """Test amount above maximum"""
        df = pd.DataFrame({
            'sale_id': [1],
            'amount': [1000000.01],  # Above maximum
            'quantity': [1]
        })
        
        results = validator.validate_dataframe(df, validation_rules)
        assert not results['passed']
    
    def test_null_in_required_column(self, validator, validation_rules):
        """Test NULL in required column"""
        df = pd.DataFrame({
            'sale_id': [None],
            'amount': [100.0],
            'quantity': [1]
        })
        
        results = validator.validate_dataframe(df, validation_rules)
        assert not results['passed']
    
    def test_all_nulls(self, validator, validation_rules):
        """Test DataFrame with all NULL values"""
        df = pd.DataFrame({
            'sale_id': [None, None, None],
            'amount': [None, None, None],
            'quantity': [None, None, None]
        })
        
        results = validator.validate_dataframe(df, validation_rules)
        assert not results['passed']
    
    def test_very_large_dataset(self, validator, validation_rules):
        """Test with large dataset (performance)"""
        import time
        
        # Generate 1 million rows
        df = pd.DataFrame({
            'sale_id': range(1, 1000001),
            'amount': [100.0] * 1000000,
            'quantity': [1] * 1000000
        })
        
        start = time.time()
        results = validator.validate_dataframe(df, validation_rules)
        duration = time.time() - start
        
        assert results['passed']
        assert duration < 10, f"Validation took {duration}s, should be < 10s"
    
    def test_special_characters_in_strings(self, validator):
        """Test special characters in string columns"""
        df = pd.DataFrame({
            'sale_id': [1, 2, 3],
            'customer_name': [
                "O'Brien",  # Apostrophe
                "Smith & Co",  # Ampersand
                "Müller"  # Umla ut
            ]
        })
        
        # Should handle special characters gracefully
        rules = {'required_columns': ['sale_id', 'customer_name']}
        results = validator.validate_dataframe(df, rules)
        assert results['passed']
    
    @pytest.mark.parametrize("amount,expected_valid", [
        (-1, False),      # Below minimum
        (0, True),        # Minimum boundary
        (0.01, True),     # Just above minimum
        (500000, True),   # Mid-range
        (999999.99, True), # Just below maximum
        (1000000, True),  # Maximum boundary
        (1000000.01, False), # Above maximum
    ])
    def test_amount_boundaries(self, validator, validation_rules, amount, expected_valid):
        """Test various amount boundaries"""
        df = pd.DataFrame({
            'sale_id': [1],
            'amount': [amount],
            'quantity': [1]
        })
        
        results = validator.validate_dataframe(df, validation_rules)
        assert results['passed'] == expected_valid
```

---

## Regression Testing

### What is Regression Testing?

**Regression Testing** = Ensuring changes don't break existing functionality.

**For Data Pipelines:**
- Output schema hasn't changed
- Row counts are stable
- Statistical properties are consistent
- Business logic produces same results

### Snapshot Testing

```python
# tests/test_regression.py

import pytest
import pandas as pd
import json
import os

class TestDataRegression:
    """Regression tests for data pipeline"""
    
    SNAPSHOT_DIR = 'tests/snapshots'
    
    @pytest.fixture(autouse=True)
    def setup(self):
        """Create snapshot directory"""
        os.makedirs(self.SNAPSHOT_DIR, exist_ok=True)
    
    def save_snapshot(self, name: str, data: dict):
        """Save data snapshot"""
        path = os.path.join(self.SNAPSHOT_DIR, f'{name}.json')
        with open(path, 'w') as f:
            json.dump(data, f, indent=2, default=str)
    
    def load_snapshot(self, name: str) -> dict:
        """Load data snapshot"""
        path = os.path.join(self.SNAPSHOT_DIR, f'{name}.json')
        if not os.path.exists(path):
            return None
        with open(path, 'r') as f:
            return json.load(f)
    
    def test_schema_regression(self, sample_sales_df):
        """Test that schema hasn't changed"""
        current_schema = {
            'columns': list(sample_sales_df.columns),
            'dtypes': {col: str(dtype) for col, dtype in sample_sales_df.dtypes.items()}
        }
        
        snapshot = self.load_snapshot('sales_schema')
        
        if snapshot is None:
            # First run - save snapshot
            self.save_snapshot('sales_schema', current_schema)
            pytest.skip("First run - snapshot saved")
        
        # Compare with snapshot
        assert current_schema['columns'] == snapshot['columns'], \
            "Column names have changed!"
        assert current_schema['dtypes'] == snapshot['dtypes'], \
            "Data types have changed!"
    
    def test_row_count_regression(self, sample_sales_df):
        """Test that row count is stable"""
        current_count = len(sample_sales_df)
        
        snapshot = self.load_snapshot('sales_row_count')
        
        if snapshot is None:
            self.save_snapshot('sales_row_count', {'count': current_count})
            pytest.skip("First run - snapshot saved")
        
        expected_count = snapshot['count']
        
        # Allow 10% variance
        variance = abs(current_count - expected_count) / expected_count
        assert variance < 0.1, \
            f"Row count changed by {variance*100:.1f}%: {expected_count} → {current_count}"
    
    def test_statistical_regression(self, sample_sales_df):
        """Test that statistical properties are stable"""
        current_stats = {
            'amount_mean': float(sample_sales_df['amount'].mean()),
            'amount_std': float(sample_sales_df['amount'].std()),
            'amount_min': float(sample_sales_df['amount'].min()),
            'amount_max': float(sample_sales_df['amount'].max())
        }
        
        snapshot = self.load_snapshot('sales_statistics')
        
        if snapshot is None:
            self.save_snapshot('sales_statistics', current_stats)
            pytest.skip("First run - snapshot saved")
        
        # Compare with tolerance
        for key, current_val in current_stats.items():
            expected_val = snapshot[key]
            variance = abs(current_val - expected_val) / expected_val if expected_val != 0 else 0
            
            assert variance < 0.2, \
                f"{key} changed by {variance*100:.1f}%: {expected_val:.2f} → {current_val:.2f}"
    
    def test_transformation_regression(self):
        """Test that transformation logic produces same results"""
        from src.transformations import transform_data
        
        # Known input
        input_df = pd.DataFrame({
            'sale_id': [1, 2, 3],
            'amount': [100, 200, 150],
            'discount': [10, 20, 15]
        })
        
        # Transform
        result = transform_data(input_df)
        
        # Expected output (from previous runs)
        expected = pd.DataFrame({
            'sale_id': [1, 2, 3],
            'amount': [100, 200, 150],
            'discount': [10, 20, 15],
            'net_amount': [90, 180, 135]  # amount - discount
        })
        
        pd.testing.assert_frame_equal(result, expected)
```

### Comparing Production vs Test Data

```python
def compare_production_snapshot():
    """Compare test results with production snapshot"""
    
    # Load production snapshot (from last known good run)
    prod_snapshot = pd.read_parquet('snapshots/prod_2024-01-15.parquet')
    
    # Run current pipeline
    current_results = run_pipeline()
    
    # Compare schemas
    assert list(current_results.columns) == list(prod_snapshot.columns)
    
    # Compare row counts (allow 5% variance)
    count_variance = abs(len(current_results) - len(prod_snapshot)) / len(prod_snapshot)
    assert count_variance < 0.05
    
    # Compare distributions
    for col in ['amount', 'quantity']:
        prod_mean = prod_snapshot[col].mean()
        current_mean = current_results[col].mean()
        
        variance = abs(current_mean - prod_mean) / prod_mean
        assert variance < 0.1, f"{col} distribution changed significantly"
    
    print("✓ Current results match production baseline")
```

---

**(Continued in next section due to length...)**

**Next: Integration Testing, Interview Q&A, and more...**
