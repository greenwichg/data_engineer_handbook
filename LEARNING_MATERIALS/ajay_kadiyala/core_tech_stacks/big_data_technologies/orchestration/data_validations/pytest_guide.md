# Pytest for Data Engineering - Complete Interview Guide

A comprehensive guide to using pytest for data validation and testing data pipelines, with real-world examples and interview preparation.

---

## Table of Contents

1. [Pytest Basics](#pytest-basics)
2. [Data Validation Testing](#data-validation-testing)
3. [Testing Airflow DAGs](#testing-airflow-dags)
4. [Testing Data Transformations](#testing-data-transformations)
5. [Testing Database Operations](#testing-database-operations)
6. [Fixtures & Mocking](#fixtures-and-mocking)
7. [Integration Testing](#integration-testing)
8. [Interview Preparation](#interview-preparation)

---

## Pytest Basics

### What is Pytest?

**Pytest** is Python's most popular testing framework. It's simple, powerful, and widely used in data engineering for:
- Testing data transformations
- Validating data quality
- Testing Airflow DAGs
- Integration testing with databases
- Mocking external dependencies

### Installation

```bash
# Install pytest and common plugins
pip install pytest pytest-cov pytest-mock pytest-xdist

# Verify installation
pytest --version
```

### Your First Test

```python
# test_basic.py

def add_numbers(a, b):
    """Simple function to test"""
    return a + b

def test_add_numbers():
    """Test function - must start with 'test_'"""
    result = add_numbers(2, 3)
    assert result == 5
    
def test_add_negative():
    """Another test"""
    result = add_numbers(-1, 1)
    assert result == 0

# Run: pytest test_basic.py
# Output: 2 passed in 0.01s
```

### Pytest Conventions

```python
# File naming
test_*.py      # test_transformations.py ✓
*_test.py      # transformations_test.py ✓

# Function naming
def test_*():  # test_extract_data() ✓
def *_test():  # extract_data_test() ✗ (won't run)

# Class naming (optional grouping)
class TestExtraction:  # ✓
    def test_extract_from_postgres(self): ...
    def test_extract_handles_empty_data(self): ...
```

### Running Tests

```bash
# Run all tests in current directory
pytest

# Run specific file
pytest test_transformations.py

# Run specific test
pytest test_transformations.py::test_remove_duplicates

# Run tests matching pattern
pytest -k "transform"  # Runs all tests with "transform" in name

# Show print statements
pytest -s

# Verbose output
pytest -v

# Stop on first failure
pytest -x

# Run in parallel (requires pytest-xdist)
pytest -n 4  # Use 4 CPUs

# Show coverage
pytest --cov=src --cov-report=html
```

### Basic Assertions

```python
def test_assertions():
    # Equality
    assert 1 + 1 == 2
    assert "hello" == "hello"
    
    # Inequality
    assert 5 != 3
    
    # Boolean
    assert True
    assert not False
    
    # Membership
    assert 'a' in ['a', 'b', 'c']
    assert 'x' not in ['a', 'b', 'c']
    
    # Comparison
    assert 10 > 5
    assert 3 <= 3
    
    # Type checking
    assert isinstance([], list)
    assert isinstance({}, dict)
    
    # None checks
    assert None is None
    assert "something" is not None
    
    # Exception testing
    with pytest.raises(ValueError):
        int("not a number")
    
    with pytest.raises(ZeroDivisionError):
        1 / 0
```

---

## Data Validation Testing

### Testing Data Quality Rules

```python
# src/data_quality.py

import pandas as pd
from typing import Dict, List

class DataQualityChecker:
    """Data quality validation for sales data"""
    
    def check_no_nulls(self, df: pd.DataFrame, columns: List[str]) -> Dict:
        """Check that specified columns have no NULL values"""
        null_counts = df[columns].isnull().sum()
        
        return {
            'passed': all(null_counts == 0),
            'null_counts': null_counts.to_dict(),
            'message': 'All columns have no NULLs' if all(null_counts == 0) else 'NULLs found'
        }
    
    def check_min_rows(self, df: pd.DataFrame, min_rows: int) -> Dict:
        """Check minimum row count"""
        row_count = len(df)
        
        return {
            'passed': row_count >= min_rows,
            'row_count': row_count,
            'min_rows': min_rows,
            'message': f'Row count {row_count} >= {min_rows}' if row_count >= min_rows else f'Too few rows: {row_count}'
        }
    
    def check_unique_key(self, df: pd.DataFrame, key_column: str) -> Dict:
        """Check that key column has unique values"""
        duplicates = df[key_column].duplicated().sum()
        
        return {
            'passed': duplicates == 0,
            'duplicate_count': int(duplicates),
            'message': 'All keys unique' if duplicates == 0 else f'{duplicates} duplicates found'
        }
    
    def check_value_range(self, df: pd.DataFrame, column: str, min_val: float, max_val: float) -> Dict:
        """Check that column values are within range"""
        out_of_range = ((df[column] < min_val) | (df[column] > max_val)).sum()
        
        return {
            'passed': out_of_range == 0,
            'out_of_range_count': int(out_of_range),
            'message': f'All values in range [{min_val}, {max_val}]' if out_of_range == 0 else f'{out_of_range} values out of range'
        }
```

```python
# tests/test_data_quality.py

import pytest
import pandas as pd
from src.data_quality import DataQualityChecker

class TestDataQualityChecker:
    """Test suite for data quality checks"""
    
    @pytest.fixture
    def sample_sales_data(self):
        """Fixture providing sample sales data"""
        return pd.DataFrame({
            'sale_id': [1, 2, 3, 4, 5],
            'customer_id': ['C001', 'C002', 'C003', 'C004', 'C005'],
            'amount': [100.0, 200.0, 150.0, 300.0, 175.0],
            'quantity': [2, 1, 3, 5, 2]
        })
    
    @pytest.fixture
    def checker(self):
        """Fixture providing checker instance"""
        return DataQualityChecker()
    
    def test_check_no_nulls_passes(self, checker, sample_sales_data):
        """Test NULL check passes with clean data"""
        result = checker.check_no_nulls(sample_sales_data, ['sale_id', 'customer_id'])
        
        assert result['passed'] is True
        assert result['null_counts']['sale_id'] == 0
        assert result['null_counts']['customer_id'] == 0
    
    def test_check_no_nulls_fails(self, checker):
        """Test NULL check fails when NULLs present"""
        data_with_nulls = pd.DataFrame({
            'sale_id': [1, 2, None, 4],
            'customer_id': ['C001', None, 'C003', 'C004']
        })
        
        result = checker.check_no_nulls(data_with_nulls, ['sale_id', 'customer_id'])
        
        assert result['passed'] is False
        assert result['null_counts']['sale_id'] == 1
        assert result['null_counts']['customer_id'] == 1
    
    def test_check_min_rows_passes(self, checker, sample_sales_data):
        """Test minimum row count check passes"""
        result = checker.check_min_rows(sample_sales_data, min_rows=5)
        
        assert result['passed'] is True
        assert result['row_count'] == 5
    
    def test_check_min_rows_fails(self, checker, sample_sales_data):
        """Test minimum row count check fails"""
        result = checker.check_min_rows(sample_sales_data, min_rows=10)
        
        assert result['passed'] is False
        assert result['row_count'] == 5
        assert 'Too few rows' in result['message']
    
    def test_check_unique_key_passes(self, checker, sample_sales_data):
        """Test unique key check passes"""
        result = checker.check_unique_key(sample_sales_data, 'sale_id')
        
        assert result['passed'] is True
        assert result['duplicate_count'] == 0
    
    def test_check_unique_key_fails(self, checker):
        """Test unique key check fails with duplicates"""
        data_with_dupes = pd.DataFrame({
            'sale_id': [1, 2, 2, 3],  # Duplicate sale_id=2
            'amount': [100, 200, 200, 300]
        })
        
        result = checker.check_unique_key(data_with_dupes, 'sale_id')
        
        assert result['passed'] is False
        assert result['duplicate_count'] == 1
    
    def test_check_value_range_passes(self, checker, sample_sales_data):
        """Test value range check passes"""
        result = checker.check_value_range(
            sample_sales_data, 
            column='amount',
            min_val=0,
            max_val=500
        )
        
        assert result['passed'] is True
        assert result['out_of_range_count'] == 0
    
    def test_check_value_range_fails(self, checker):
        """Test value range check fails"""
        data = pd.DataFrame({
            'amount': [100, -50, 200, 600]  # -50 and 600 out of range
        })
        
        result = checker.check_value_range(data, 'amount', min_val=0, max_val=500)
        
        assert result['passed'] is False
        assert result['out_of_range_count'] == 2
    
    @pytest.mark.parametrize("column,min_val,max_val,expected_pass", [
        ('amount', 0, 500, True),
        ('amount', 150, 300, False),  # Some values out of range
        ('quantity', 0, 10, True),
        ('quantity', 3, 10, False),  # quantity=1,2 out of range
    ])
    def test_value_range_parametrized(self, checker, sample_sales_data, 
                                     column, min_val, max_val, expected_pass):
        """Test value range with multiple parameter sets"""
        result = checker.check_value_range(sample_sales_data, column, min_val, max_val)
        assert result['passed'] == expected_pass

# Run: pytest tests/test_data_quality.py -v
```

### Testing Data Transformations

```python
# src/transformations.py

import pandas as pd
from datetime import datetime

class SalesDataTransformer:
    """Transform sales data to unified format"""
    
    def remove_duplicates(self, df: pd.DataFrame, key_column: str = 'sale_id') -> pd.DataFrame:
        """Remove duplicate records based on key column"""
        return df.drop_duplicates(subset=[key_column], keep='first')
    
    def standardize_types(self, df: pd.DataFrame) -> pd.DataFrame:
        """Standardize data types"""
        df = df.copy()
        
        if 'sale_date' in df.columns:
            df['sale_date'] = pd.to_datetime(df['sale_date'])
        
        for col in ['quantity', 'sale_year', 'sale_month']:
            if col in df.columns:
                df[col] = df[col].astype(int)
        
        for col in ['unit_price', 'total_amount', 'discount_amount']:
            if col in df.columns:
                df[col] = df[col].astype(float)
        
        return df
    
    def add_derived_columns(self, df: pd.DataFrame) -> pd.DataFrame:
        """Add calculated columns"""
        df = df.copy()
        
        # Fill NULLs
        df['discount_amount'] = df['discount_amount'].fillna(0)
        df['tax_amount'] = df['tax_amount'].fillna(0)
        
        # Calculate derived fields
        df['net_amount'] = df['total_amount'] - df['discount_amount']
        df['gross_profit'] = df['net_amount'] - df['tax_amount']
        
        return df
    
    def add_partition_columns(self, df: pd.DataFrame) -> pd.DataFrame:
        """Add partition columns for efficient querying"""
        df = df.copy()
        
        df['sale_year'] = df['sale_date'].dt.year
        df['sale_month'] = df['sale_date'].dt.month
        df['sale_day'] = df['sale_date'].dt.day
        
        return df
    
    def normalize_region(self, df: pd.DataFrame) -> pd.DataFrame:
        """Normalize region codes"""
        df = df.copy()
        
        region_mapping = {
            'us_east': 'US-EAST',
            'us_west': 'US-WEST',
            'europe': 'EUROPE',
            'asia_pacific': 'ASIA-PACIFIC'
        }
        
        df['region'] = df['region'].map(region_mapping)
        
        return df
    
    def filter_invalid_records(self, df: pd.DataFrame) -> pd.DataFrame:
        """Remove invalid records based on business rules"""
        df = df.copy()
        
        # Filter out invalid data
        df = df[df['quantity'] > 0]
        df = df[df['unit_price'] > 0]
        df = df[df['total_amount'] > 0]
        
        # Sanity check: total_amount should be reasonable
        df = df[df['total_amount'] >= (df['quantity'] * df['unit_price'] * 0.5)]
        df = df[df['total_amount'] <= (df['quantity'] * df['unit_price'] * 2.0)]
        
        return df
```

```python
# tests/test_transformations.py

import pytest
import pandas as pd
import numpy as np
from datetime import datetime
from src.transformations import SalesDataTransformer

class TestSalesDataTransformer:
    """Test suite for sales data transformations"""
    
    @pytest.fixture
    def transformer(self):
        """Fixture providing transformer instance"""
        return SalesDataTransformer()
    
    @pytest.fixture
    def sample_data(self):
        """Fixture providing sample sales data with various issues"""
        return pd.DataFrame({
            'sale_id': [1, 2, 3, 2, 4],  # Has duplicate (2)
            'customer_id': ['C001', 'C002', 'C003', 'C002', 'C004'],
            'sale_date': ['2024-01-15', '2024-01-15', '2024-01-16', '2024-01-15', '2024-01-16'],
            'quantity': [2, 1, 3, 1, 5],
            'unit_price': [10.0, 20.0, 15.0, 20.0, 8.0],
            'total_amount': [20.0, 20.0, 45.0, 20.0, 40.0],
            'discount_amount': [0.0, 2.0, 5.0, 2.0, None],  # Has NULL
            'tax_amount': [2.0, 1.8, 4.5, 1.8, 4.0],
            'region': ['us_east', 'us_west', 'europe', 'us_west', 'asia_pacific']
        })
    
    def test_remove_duplicates(self, transformer, sample_data):
        """Test duplicate removal"""
        result = transformer.remove_duplicates(sample_data)
        
        # Should have 4 records (5 - 1 duplicate)
        assert len(result) == 4
        
        # sale_id should be unique
        assert result['sale_id'].is_unique
        
        # First occurrence of duplicate should be kept
        duplicate_rows = sample_data[sample_data['sale_id'] == 2]
        result_row = result[result['sale_id'] == 2].iloc[0]
        assert result_row['customer_id'] == duplicate_rows.iloc[0]['customer_id']
    
    def test_standardize_types(self, transformer, sample_data):
        """Test data type standardization"""
        result = transformer.standardize_types(sample_data)
        
        # Check date conversion
        assert pd.api.types.is_datetime64_any_dtype(result['sale_date'])
        
        # Check numeric types
        assert result['quantity'].dtype == int
        assert result['unit_price'].dtype == float
        assert result['total_amount'].dtype == float
    
    def test_add_derived_columns(self, transformer, sample_data):
        """Test derived column calculation"""
        result = transformer.add_derived_columns(sample_data)
        
        # NULL filling
        assert result['discount_amount'].isnull().sum() == 0
        
        # Derived calculations
        assert 'net_amount' in result.columns
        assert 'gross_profit' in result.columns
        
        # Verify calculation
        first_row = result.iloc[0]
        expected_net = first_row['total_amount'] - first_row['discount_amount']
        assert first_row['net_amount'] == expected_net
        
        expected_profit = first_row['net_amount'] - first_row['tax_amount']
        assert first_row['gross_profit'] == expected_profit
    
    def test_add_partition_columns(self, transformer, sample_data):
        """Test partition column generation"""
        # First standardize types
        data = transformer.standardize_types(sample_data)
        result = transformer.add_partition_columns(data)
        
        # Check columns exist
        assert 'sale_year' in result.columns
        assert 'sale_month' in result.columns
        assert 'sale_day' in result.columns
        
        # Verify values
        first_date = pd.to_datetime('2024-01-15')
        first_row = result[result['sale_date'] == first_date].iloc[0]
        
        assert first_row['sale_year'] == 2024
        assert first_row['sale_month'] == 1
        assert first_row['sale_day'] == 15
    
    def test_normalize_region(self, transformer, sample_data):
        """Test region normalization"""
        result = transformer.normalize_region(sample_data)
        
        # Check normalized values
        expected_regions = {'US-EAST', 'US-WEST', 'EUROPE', 'ASIA-PACIFIC'}
        assert set(result['region'].unique()) == expected_regions
        
        # Verify specific mapping
        us_east_rows = result[result['region'] == 'US-EAST']
        assert len(us_east_rows) == 1  # Only one us_east in original data
    
    def test_filter_invalid_records(self, transformer):
        """Test invalid record filtering"""
        data = pd.DataFrame({
            'sale_id': [1, 2, 3, 4, 5],
            'quantity': [2, 0, -1, 3, 5],  # 0 and negative invalid
            'unit_price': [10.0, 20.0, 15.0, -5.0, 8.0],  # Negative invalid
            'total_amount': [20.0, 20.0, 45.0, 15.0, 5.0],  # Last one too low (5 vs 5*8)
        })
        
        result = transformer.filter_invalid_records(data)
        
        # Only first record should pass all checks
        assert len(result) == 1
        assert result.iloc[0]['sale_id'] == 1
    
    def test_full_transformation_pipeline(self, transformer, sample_data):
        """Test complete transformation pipeline"""
        # Execute full pipeline
        result = sample_data.copy()
        result = transformer.remove_duplicates(result)
        result = transformer.standardize_types(result)
        result = transformer.add_derived_columns(result)
        result = transformer.add_partition_columns(result)
        result = transformer.normalize_region(result)
        result = transformer.filter_invalid_records(result)
        
        # Verify end-to-end
        assert len(result) == 4  # 5 original - 1 duplicate
        assert result['sale_id'].is_unique
        assert 'net_amount' in result.columns
        assert 'sale_year' in result.columns
        assert 'US-EAST' in result['region'].values
        
    @pytest.mark.parametrize("quantity,unit_price,total_amount,should_pass", [
        (2, 10.0, 20.0, True),   # Valid
        (0, 10.0, 0.0, False),   # Zero quantity
        (2, 0.0, 0.0, False),    # Zero price
        (2, 10.0, 5.0, False),   # Total too low (< 0.5x)
        (2, 10.0, 50.0, False),  # Total too high (> 2x)
        (2, 10.0, 15.0, True),   # Within range (0.5x to 2x)
    ])
    def test_filter_invalid_parametrized(self, transformer, 
                                        quantity, unit_price, total_amount, should_pass):
        """Test filtering with multiple parameter sets"""
        data = pd.DataFrame({
            'sale_id': [1],
            'quantity': [quantity],
            'unit_price': [unit_price],
            'total_amount': [total_amount]
        })
        
        result = transformer.filter_invalid_records(data)
        
        if should_pass:
            assert len(result) == 1
        else:
            assert len(result) == 0

# Run: pytest tests/test_transformations.py -v
```

---

## Testing Airflow DAGs

### Testing DAG Structure

```python
# tests/test_dag_structure.py

import pytest
from datetime import datetime, timedelta
from airflow.models import DagBag

class TestRetailSalesDAGStructure:
    """Test DAG structure and configuration"""
    
    @pytest.fixture(scope="class")
    def dagbag(self):
        """Load DAGs"""
        return DagBag(dag_folder='dags/', include_examples=False)
    
    def test_dag_loaded(self, dagbag):
        """Test that DAG loads without errors"""
        dag_id = 'retail_sales_etl_pipeline'
        
        # Check no import errors
        assert len(dagbag.import_errors) == 0, f"DAG import errors: {dagbag.import_errors}"
        
        # Check DAG exists
        assert dag_id in dagbag.dags, f"DAG {dag_id} not found"
        
        dag = dagbag.get_dag(dag_id)
        assert dag is not None
    
    def test_dag_configuration(self, dagbag):
        """Test DAG-level configuration"""
        dag = dagbag.get_dag('retail_sales_etl_pipeline')
        
        # Schedule
        assert dag.schedule_interval == '0 6 * * *'
        
        # Catchup
        assert dag.catchup is False, "catchup should be False to prevent backfill"
        
        # Max active runs
        assert dag.max_active_runs == 1, "Should only allow one run at a time"
        
        # Tags
        assert 'sales' in dag.tags
        assert 'etl' in dag.tags
        assert 'production' in dag.tags
    
    def test_default_args(self, dagbag):
        """Test default arguments"""
        dag = dagbag.get_dag('retail_sales_etl_pipeline')
        
        assert dag.default_args['owner'] == 'data-engineering'
        assert dag.default_args['retries'] == 2
        assert dag.default_args['retry_delay'] == timedelta(minutes=5)
        assert dag.default_args['email_on_failure'] is True
    
    def test_task_count(self, dagbag):
        """Test expected number of tasks"""
        dag = dagbag.get_dag('retail_sales_etl_pipeline')
        
        # Should have minimum expected tasks
        assert len(dag.tasks) >= 10
        
        # Check specific tasks exist
        task_ids = [task.task_id for task in dag.tasks]
        assert 'start' in task_ids
        assert 'transform_sales_data' in task_ids
        assert 'validate_data_quality' in task_ids
    
    def test_task_dependencies(self, dagbag):
        """Test critical task dependencies"""
        dag = dagbag.get_dag('retail_sales_etl_pipeline')
        
        # Get tasks
        start_task = dag.get_task('start')
        transform_task = dag.get_task('transform_sales_data')
        validate_task = dag.get_task('validate_data_quality')
        
        # Check dependencies
        assert len(start_task.downstream_task_ids) > 0
        
        # Transform should depend on extract tasks
        transform_upstream = transform_task.upstream_task_ids
        assert any('extract' in task_id for task_id in transform_upstream)
        
        # Validate should depend on transform
        assert 'transform_sales_data' in validate_task.upstream_task_ids
    
    def test_no_cycles(self, dagbag):
        """Test that DAG has no cycles"""
        dag = dagbag.get_dag('retail_sales_etl_pipeline')
        
        # This will raise exception if cycles exist
        try:
            dag.test_cycle()
        except Exception as e:
            pytest.fail(f"DAG has cycles: {e}")
    
    def test_task_timeouts(self, dagbag):
        """Test that tasks have appropriate timeouts"""
        dag = dagbag.get_dag('retail_sales_etl_pipeline')
        
        # Extract tasks should have execution timeout
        for task in dag.tasks:
            if 'extract' in task.task_id:
                assert hasattr(task, 'execution_timeout')
                assert task.execution_timeout is not None

# Run: pytest tests/test_dag_structure.py -v
```

### Testing DAG Task Logic

```python
# tests/test_dag_tasks.py

import pytest
from unittest.mock import Mock, patch, MagicMock
from datetime import datetime
import pandas as pd

# Import your DAG functions
from dags.retail_sales_etl_dag import (
    extract_sales_data_from_region,
    transform_sales_data,
    validate_data_quality
)

class TestDAGTasks:
    """Test individual DAG task functions"""
    
    @pytest.fixture
    def mock_context(self):
        """Create mock Airflow context"""
        return {
            'ds': '2024-01-15',
            'execution_date': datetime(2024, 1, 15),
            'task_instance': Mock(),
            'dag': Mock(),
        }
    
    @patch('dags.retail_sales_etl_dag.PostgresHook')
    def test_extract_sales_data_success(self, mock_pg_hook, mock_context):
        """Test successful data extraction"""
        # Setup mock
        mock_hook_instance = Mock()
        mock_pg_hook.return_value = mock_hook_instance
        
        mock_connection = Mock()
        mock_cursor = Mock()
        
        # Mock database response
        mock_cursor.fetchall.return_value = [
            (1, 'C001', 'P001', '2024-01-14', 2, 10.0, 20.0),
            (2, 'C002', 'P002', '2024-01-14', 1, 20.0, 20.0),
        ]
        
        mock_connection.cursor.return_value = mock_cursor
        mock_hook_instance.get_conn.return_value = mock_connection
        
        # Execute
        result = extract_sales_data_from_region(
            region='us_east',
            execution_date='2024-01-15',
            **mock_context
        )
        
        # Verify
        assert result['status'] == 'success'
        assert result['record_count'] == 2
        assert result['region'] == 'us_east'
        
        # Verify PostgresHook was called correctly
        mock_pg_hook.assert_called_once_with(postgres_conn_id='postgres_us_east')
    
    @patch('dags.retail_sales_etl_dag.PostgresHook')
    def test_extract_sales_data_empty(self, mock_pg_hook, mock_context):
        """Test extraction with no data"""
        mock_hook_instance = Mock()
        mock_pg_hook.return_value = mock_hook_instance
        
        mock_connection = Mock()
        mock_cursor = Mock()
        
        # Empty result
        mock_cursor.fetchall.return_value = []
        
        mock_connection.cursor.return_value = mock_cursor
        mock_hook_instance.get_conn.return_value = mock_connection
        
        result = extract_sales_data_from_region(
            region='us_east',
            execution_date='2024-01-15',
            **mock_context
        )
        
        assert result['status'] == 'success'
        assert result['record_count'] == 0
    
    @patch('dags.retail_sales_etl_dag.PostgresHook')
    def test_extract_sales_data_error(self, mock_pg_hook, mock_context):
        """Test extraction error handling"""
        # Mock connection failure
        mock_pg_hook.return_value.get_conn.side_effect = Exception("Connection failed")
        
        # Should raise exception
        with pytest.raises(Exception) as exc_info:
            extract_sales_data_from_region(
                region='us_east',
                execution_date='2024-01-15',
                **mock_context
            )
        
        assert "Connection failed" in str(exc_info.value)
    
    def test_validate_data_quality_pass(self, mock_context):
        """Test data quality validation passes"""
        # Mock XCom data
        mock_ti = mock_context['task_instance']
        mock_ti.xcom_pull.return_value = {
            'transformed_records': 1500,
            'status': 'success'
        }
        
        # Mock database check
        with patch('dags.retail_sales_etl_dag.PostgresHook') as mock_pg_hook:
            mock_hook = Mock()
            mock_pg_hook.return_value = mock_hook
            
            mock_conn = Mock()
            mock_cursor = Mock()
            
            # Mock validation queries
            mock_cursor.fetchone.side_effect = [
                (1500, 0, 0, 0, 0, 0),  # NULL check: no NULLs
                (0,)  # Business rule check: no invalid records
            ]
            
            mock_conn.cursor.return_value = mock_cursor
            mock_hook.get_conn.return_value = mock_conn
            
            result = validate_data_quality(**mock_context)
            
            assert result == 'load_to_snowflake'
    
    def test_validate_data_quality_fail_row_count(self, mock_context):
        """Test validation fails on low row count"""
        mock_ti = mock_context['task_instance']
        mock_ti.xcom_pull.return_value = {
            'transformed_records': 50,  # Below threshold of 100
            'status': 'success'
        }
        
        result = validate_data_quality(**mock_context)
        
        assert result == 'data_quality_failure'
        
        # Check that failure reason was stored
        mock_ti.xcom_push.assert_called_with(
            key='dq_failure_reason',
            value=pytest.approx("Record count below threshold: 50 < 100", rel=1)
        )

# Run: pytest tests/test_dag_tasks.py -v
```

---

## Testing Database Operations

```python
# tests/test_database_operations.py

import pytest
import pandas as pd
from unittest.mock import Mock, patch
from sqlalchemy import create_engine

class TestDatabaseOperations:
    """Test database read/write operations"""
    
    @pytest.fixture
    def sample_dataframe(self):
        """Sample data for testing"""
        return pd.DataFrame({
            'sale_id': [1, 2, 3],
            'amount': [100.0, 200.0, 150.0],
            'date': pd.to_datetime(['2024-01-15', '2024-01-15', '2024-01-16'])
        })
    
    @patch('sqlalchemy.create_engine')
    def test_write_to_database(self, mock_create_engine, sample_dataframe):
        """Test writing DataFrame to database"""
        # Mock engine and connection
        mock_engine = Mock()
        mock_create_engine.return_value = mock_engine
        
        # Write data
        sample_dataframe.to_sql(
            'sales_staging',
            mock_engine,
            if_exists='append',
            index=False
        )
        
        # Verify to_sql was called (indirectly through mock)
        # In real test, would check database directly
    
    @patch('pandas.read_sql')
    def test_read_from_database(self, mock_read_sql):
        """Test reading data from database"""
        # Mock database response
        expected_df = pd.DataFrame({
            'sale_id': [1, 2],
            'amount': [100.0, 200.0]
        })
        
        mock_read_sql.return_value = expected_df
        
        # Read data
        query = "SELECT * FROM sales WHERE date = '2024-01-15'"
        result = pd.read_sql(query, con=Mock())
        
        # Verify
        pd.testing.assert_frame_equal(result, expected_df)
    
    def test_sql_injection_prevention(self):
        """Test that SQL is parameterized to prevent injection"""
        # Good: Parameterized query
        def safe_query(date):
            # Using f-string here for example, but should use parameterized queries
            return f"SELECT * FROM sales WHERE date = '{date}'"
        
        # Test that malicious input doesn't break query
        malicious_date = "2024-01-15'; DROP TABLE sales; --"
        query = safe_query(malicious_date)
        
        # In production, use parameterized queries:
        # query = "SELECT * FROM sales WHERE date = %s"
        # params = (date,)
        
        # Verify query construction
        assert "DROP TABLE" in query  # Demonstrates the risk
        # In real code, this wouldn't happen with parameterized queries

# Run: pytest tests/test_database_operations.py -v
```

---

## Fixtures and Mocking

### Understanding Fixtures

```python
# tests/conftest.py - Shared fixtures across all tests

import pytest
import pandas as pd
from datetime import datetime

@pytest.fixture
def sample_sales_data():
    """Reusable sample sales data"""
    return pd.DataFrame({
        'sale_id': [1, 2, 3, 4, 5],
        'customer_id': ['C001', 'C002', 'C003', 'C004', 'C005'],
        'amount': [100.0, 200.0, 150.0, 300.0, 175.0],
        'quantity': [2, 1, 3, 5, 2],
        'date': pd.to_datetime(['2024-01-15'] * 5)
    })

@pytest.fixture
def empty_dataframe():
    """Empty DataFrame with correct schema"""
    return pd.DataFrame(columns=['sale_id', 'customer_id', 'amount', 'quantity', 'date'])

@pytest.fixture(scope="session")
def database_engine():
    """Database connection for integration tests (session-scoped)"""
    from sqlalchemy import create_engine
    
    # Create test database engine
    engine = create_engine('postgresql://test:test@localhost/test_db')
    
    yield engine
    
    # Cleanup after all tests
    engine.dispose()

@pytest.fixture(scope="function")
def clean_database(database_engine):
    """Clean database before each test"""
    # Truncate tables
    with database_engine.connect() as conn:
        conn.execute("TRUNCATE TABLE sales_staging")
        conn.commit()
    
    yield database_engine
    
    # Cleanup after test
    with database_engine.connect() as conn:
        conn.execute("TRUNCATE TABLE sales_staging")
        conn.commit()

@pytest.fixture
def mock_airflow_context():
    """Mock Airflow context for testing tasks"""
    from unittest.mock import Mock
    
    ti = Mock()
    ti.xcom_pull = Mock(return_value=None)
    ti.xcom_push = Mock()
    
    return {
        'ds': '2024-01-15',
        'execution_date': datetime(2024, 1, 15),
        'task_instance': ti,
        'dag': Mock(),
        'dag_run': Mock(),
        'task': Mock()
    }

# Fixture scopes:
# - function (default): Created for each test function
# - class: Created once per test class
# - module: Created once per test module
# - session: Created once per test session
```

### Using Fixtures

```python
# tests/test_with_fixtures.py

import pytest
import pandas as pd

class TestWithFixtures:
    """Examples of using fixtures"""
    
    def test_using_fixture(self, sample_sales_data):
        """Test that uses sample data fixture"""
        assert len(sample_sales_data) == 5
        assert 'sale_id' in sample_sales_data.columns
    
    def test_multiple_fixtures(self, sample_sales_data, mock_airflow_context):
        """Test using multiple fixtures"""
        assert len(sample_sales_data) > 0
        assert mock_airflow_context['ds'] == '2024-01-15'
    
    def test_fixture_modification(self, sample_sales_data):
        """Fixtures provide fresh copy for each test"""
        # Modify data
        sample_sales_data['amount'] = sample_sales_data['amount'] * 2
        
        # Verify modification
        assert sample_sales_data['amount'].iloc[0] == 200.0
        
        # Next test will get fresh, unmodified data
    
    @pytest.fixture
    def method_fixture(self):
        """Fixture defined in test class"""
        return {"test": "data"}
    
    def test_method_fixture(self, method_fixture):
        """Test using method-level fixture"""
        assert method_fixture['test'] == 'data'

# Run: pytest tests/test_with_fixtures.py -v
```

### Mocking External Dependencies

```python
# tests/test_mocking.py

import pytest
from unittest.mock import Mock, patch, MagicMock, call
import requests

class TestMocking:
    """Examples of mocking external dependencies"""
    
    @patch('requests.get')
    def test_mock_api_call(self, mock_get):
        """Mock external API call"""
        # Setup mock response
        mock_response = Mock()
        mock_response.status_code = 200
        mock_response.json.return_value = {'data': [1, 2, 3]}
        
        mock_get.return_value = mock_response
        
        # Make request
        response = requests.get('https://api.example.com/data')
        
        # Verify
        assert response.status_code == 200
        assert response.json() == {'data': [1, 2, 3]}
        
        # Verify API was called correctly
        mock_get.assert_called_once_with('https://api.example.com/data')
    
    @patch('boto3.client')
    def test_mock_s3_client(self, mock_boto_client):
        """Mock AWS S3 operations"""
        # Setup mock S3 client
        mock_s3 = Mock()
        mock_boto_client.return_value = mock_s3
        
        # Mock S3 response
        mock_s3.upload_file.return_value = None
        mock_s3.list_objects_v2.return_value = {
            'Contents': [
                {'Key': 'file1.csv'},
                {'Key': 'file2.csv'}
            ]
        }
        
        # Use S3 client
        import boto3
        s3 = boto3.client('s3')
        
        # Upload file
        s3.upload_file('/tmp/data.csv', 'my-bucket', 'data.csv')
        
        # List objects
        response = s3.list_objects_v2(Bucket='my-bucket')
        
        # Verify
        assert len(response['Contents']) == 2
        mock_s3.upload_file.assert_called_once()
    
    @patch('airflow.providers.postgres.hooks.postgres.PostgresHook')
    def test_mock_postgres_hook(self, mock_pg_hook):
        """Mock Airflow PostgresHook"""
        # Setup mock
        mock_hook_instance = Mock()
        mock_pg_hook.return_value = mock_hook_instance
        
        # Mock query result
        mock_hook_instance.get_first.return_value = (1000,)
        mock_hook_instance.get_records.return_value = [
            (1, 'A', 100),
            (2, 'B', 200)
        ]
        
        # Use hook
        from airflow.providers.postgres.hooks.postgres import PostgresHook
        hook = PostgresHook(postgres_conn_id='test')
        
        count = hook.get_first("SELECT COUNT(*) FROM sales")
        records = hook.get_records("SELECT * FROM sales LIMIT 2")
        
        # Verify
        assert count == (1000,)
        assert len(records) == 2
    
    def test_mock_with_side_effect(self):
        """Mock with different responses on multiple calls"""
        mock_func = Mock()
        
        # First call returns 100, second returns 200, third raises exception
        mock_func.side_effect = [100, 200, ValueError("Error")]
        
        assert mock_func() == 100
        assert mock_func() == 200
        
        with pytest.raises(ValueError):
            mock_func()
    
    def test_mock_assertions(self):
        """Various mock assertion methods"""
        mock = Mock()
        
        # Call mock
        mock.method(1, 2, key='value')
        mock.method(3, 4)
        
        # Assertions
        assert mock.method.called
        assert mock.method.call_count == 2
        
        # Check specific call
        mock.method.assert_any_call(1, 2, key='value')
        
        # Check all calls
        expected_calls = [
            call(1, 2, key='value'),
            call(3, 4)
        ]
        mock.method.assert_has_calls(expected_calls)

# Run: pytest tests/test_mocking.py -v
```

---

## Integration Testing

```python
# tests/integration/test_end_to_end.py

import pytest
import pandas as pd
from sqlalchemy import create_engine
import boto3
from moto import mock_s3

@pytest.mark.integration
class TestEndToEndPipeline:
    """End-to-end integration tests (requires test database)"""
    
    @pytest.fixture(scope="class")
    def test_database(self):
        """Setup test database"""
        engine = create_engine('postgresql://test:test@localhost/test_db')
        
        # Create test tables
        with engine.connect() as conn:
            conn.execute("""
                CREATE TABLE IF NOT EXISTS sales_staging (
                    sale_id INTEGER PRIMARY KEY,
                    amount DECIMAL(10,2),
                    date DATE
                )
            """)
            conn.commit()
        
        yield engine
        
        # Cleanup
        with engine.connect() as conn:
            conn.execute("DROP TABLE IF EXISTS sales_staging")
            conn.commit()
        
        engine.dispose()
    
    @mock_s3
    def test_complete_pipeline(self, test_database):
        """Test complete ETL pipeline end-to-end"""
        # Setup S3
        s3 = boto3.client('s3', region_name='us-east-1')
        s3.create_bucket(Bucket='test-bucket')
        
        # 1. Extract: Create sample data
        source_data = pd.DataFrame({
            'sale_id': [1, 2, 3],
            'amount': [100.0, 200.0, 150.0],
            'date': pd.to_datetime(['2024-01-15'] * 3)
        })
        
        # 2. Transform: Simple transformation
        transformed_data = source_data.copy()
        transformed_data['amount'] = transformed_data['amount'] * 1.1  # Add 10%
        
        # 3. Load to S3
        csv_buffer = transformed_data.to_csv(index=False)
        s3.put_object(
            Bucket='test-bucket',
            Key='data/sales.csv',
            Body=csv_buffer
        )
        
        # 4. Load to database
        transformed_data.to_sql(
            'sales_staging',
            test_database,
            if_exists='append',
            index=False
        )
        
        # 5. Verify in database
        result = pd.read_sql('SELECT * FROM sales_staging', test_database)
        
        assert len(result) == 3
        assert result['amount'].iloc[0] == 110.0  # 100 * 1.1
        
        # 6. Verify in S3
        response = s3.get_object(Bucket='test-bucket', Key='data/sales.csv')
        s3_data = pd.read_csv(response['Body'])
        
        pd.testing.assert_frame_equal(s3_data, transformed_data)
    
    @pytest.mark.slow
    def test_large_dataset_performance(self, test_database):
        """Test performance with large dataset"""
        import time
        
        # Generate large dataset
        large_data = pd.DataFrame({
            'sale_id': range(100000),
            'amount': [100.0] * 100000,
            'date': pd.to_datetime(['2024-01-15'] * 100000)
        })
        
        # Measure load time
        start_time = time.time()
        
        large_data.to_sql(
            'sales_staging',
            test_database,
            if_exists='append',
            index=False,
            method='multi',
            chunksize=1000
        )
        
        load_time = time.time() - start_time
        
        # Verify
        count = pd.read_sql('SELECT COUNT(*) FROM sales_staging', test_database).iloc[0, 0]
        assert count == 100000
        
        # Performance assertion
        assert load_time < 30, f"Load took {load_time}s, should be < 30s"

# Run integration tests only:
# pytest tests/integration/ -v -m integration

# Run excluding slow tests:
# pytest -v -m "not slow"
```

---

## Interview Preparation

### Common Pytest Interview Questions

#### Q1: "How do you test data quality in your pipeline?"

**Answer:**
"I use pytest to test data quality at multiple levels:

```python
# Unit test for quality checker
def test_check_no_nulls(checker, sample_data):
    result = checker.check_no_nulls(sample_data, ['sale_id', 'amount'])
    assert result['passed'] is True
    assert result['null_counts']['sale_id'] == 0

# Parametrized test for multiple scenarios
@pytest.mark.parametrize("column,min_val,max_val,expected", [
    ('amount', 0, 500, True),
    ('amount', 200, 500, False),
])
def test_value_ranges(checker, data, column, min_val, max_val, expected):
    result = checker.check_value_range(data, column, min_val, max_val)
    assert result['passed'] == expected
```

I also test edge cases: empty data, all NULLs, duplicate keys, and out-of-range values."

---

#### Q2: "How do you test Airflow DAGs?"

**Answer:**
"I test DAGs at three levels:

**1. Structure tests** (DAG configuration):
```python
def test_dag_loaded(dagbag):
    assert 'my_dag' in dagbag.dags
    assert dagbag.import_errors == {}

def test_dag_configuration(dagbag):
    dag = dagbag.get_dag('my_dag')
    assert dag.schedule_interval == '0 6 * * *'
    assert dag.catchup is False
```

**2. Dependency tests**:
```python
def test_task_dependencies(dagbag):
    dag = dagbag.get_dag('my_dag')
    transform = dag.get_task('transform')
    assert 'extract' in transform.upstream_task_ids
```

**3. Task logic tests** (with mocking):
```python
@patch('dags.my_dag.PostgresHook')
def test_extract_function(mock_hook, mock_context):
    mock_hook.return_value.get_records.return_value = [(1, 'A', 100)]
    result = extract_function(**mock_context)
    assert result['record_count'] == 1
```"

---

#### Q3: "What's the difference between unit tests and integration tests?"

**Answer:**
"**Unit tests** test individual functions in isolation with mocked dependencies:
```python
@patch('requests.get')  # Mock external dependency
def test_api_call(mock_get):
    mock_get.return_value.json.return_value = {'data': [1, 2, 3]}
    result = my_function()
    assert len(result) == 3
```

**Integration tests** test multiple components together with real dependencies:
```python
@pytest.mark.integration
def test_end_to_end(test_database, s3_client):
    # Use real database and S3
    load_data_to_db(test_database)
    upload_to_s3(s3_client)
    # Verify both systems
```

In my retail sales pipeline:
- **Unit tests**: Test transform logic, data validation rules (fast, run on every commit)
- **Integration tests**: Test PostgreSQL → S3 → Snowflake flow (slower, run before deploy)

I use `@pytest.mark.integration` to separate them and run appropriate tests at each stage."

---

#### Q4: "How do you use fixtures?"

**Answer:**
"Fixtures provide reusable test data and setup:

```python
@pytest.fixture
def sample_sales_data():
    return pd.DataFrame({
        'sale_id': [1, 2, 3],
        'amount': [100, 200, 150]
    })

def test_transformation(sample_sales_data):
    result = transform(sample_sales_data)
    assert len(result) == 3
```

I use **fixture scopes** strategically:
- `scope='function'` (default): Fresh data per test
- `scope='session'`: Database connection shared across all tests

**Example from my project:**
```python
@pytest.fixture(scope='session')
def database_engine():
    engine = create_engine('postgresql://...')
    yield engine
    engine.dispose()  # Cleanup once

@pytest.fixture(scope='function')
def clean_database(database_engine):
    # Truncate before each test
    truncate_tables(database_engine)
    yield database_engine
```

This pattern ensures tests don't affect each other while reusing expensive resources like database connections."

---

#### Q5: "How do you test for exceptions?"

**Answer:**
"Use `pytest.raises()`:

```python
def test_invalid_input_raises_error():
    with pytest.raises(ValueError) as exc_info:
        process_data(invalid_data)
    
    # Can also check error message
    assert "Invalid sale_id" in str(exc_info.value)

# Test specific exception types
def test_database_error():
    with pytest.raises(ConnectionError):
        connect_to_database(invalid_host)
```

**Real example from my pipeline:**
```python
def test_validation_fails_low_records():
    data = pd.DataFrame({'sale_id': [1]})  # Only 1 record
    
    with pytest.raises(ValueError) as exc:
        validate_min_records(data, min_required=100)
    
    assert "Too few records" in str(exc.value)
```"

---

### Pytest Best Practices for Data Engineering

```python
"""
Best Practices Checklist
"""

# 1. ✅ Use descriptive test names
def test_remove_duplicates_keeps_first_occurrence():  # Clear
    pass

def test_1():  # Bad - unclear purpose
    pass

# 2. ✅ One assertion per test (when possible)
def test_record_count():
    assert len(data) == 5

def test_column_exists():
    assert 'sale_id' in data.columns

# Not: def test_everything():  # Bad - multiple concerns
#     assert len(data) == 5
#     assert 'sale_id' in data.columns
#     assert data['amount'].sum() == 100

# 3. ✅ Use parametrize for similar tests
@pytest.mark.parametrize("input,expected", [
    (0, False),
    (100, True),
    (-10, False),
])
def test_valid_amount(input, expected):
    assert is_valid_amount(input) == expected

# 4. ✅ Use fixtures for common setup
@pytest.fixture
def sample_data():
    return create_test_data()

# 5. ✅ Mock external dependencies
@patch('requests.get')
def test_api_call(mock_get):
    pass  # Don't make real API calls in tests

# 6. ✅ Use markers to categorize tests
@pytest.mark.slow
@pytest.mark.integration
def test_full_pipeline():
    pass

# 7. ✅ Test both success and failure cases
def test_transform_valid_data():
    pass

def test_transform_invalid_data_raises_error():
    pass

# 8. ✅ Use assert messages for complex conditions
assert result > 0, f"Expected positive result, got {result}"

# 9. ✅ Clean up after tests
@pytest.fixture
def temp_file():
    file = create_temp_file()
    yield file
    os.remove(file)  # Cleanup

# 10. ✅ Test edge cases
def test_empty_dataframe():
    pass

def test_all_null_values():
    pass

def test_single_row():
    pass
```

---

### Quick Interview Reference

**Key Points to Memorize:**

| Concept | Quick Answer |
|---------|--------------|
| **What is pytest?** | "Python's most popular testing framework - simple, powerful, used for unit/integration tests" |
| **Fixture scope** | "function (default), class, module, session - controls how often fixture is created" |
| **Mocking** | "Replace external dependencies (APIs, databases) with controlled fake objects for testing" |
| **Parametrize** | "Run same test with multiple inputs: `@pytest.mark.parametrize('input,expected', [(1,2), (3,4)])`" |
| **Integration vs Unit** | "Unit: Test function in isolation (fast, mocked). Integration: Test components together (slow, real)" |
| **Test naming** | "test_*.py files, test_* or *_test functions, TestClass for grouping" |
| **Assertions** | "`assert condition` - pytest shows detailed failure info automatically" |
| **Exception testing** | "`with pytest.raises(ValueError):` tests that code raises expected exceptions" |

---

### Common Mistakes to Avoid

```python
# ❌ BAD: Testing implementation details
def test_uses_pandas():
    # Don't test that function uses pandas
    assert 'pandas' in str(transform.__code__)

# ✅ GOOD: Test behavior/output
def test_transform_output():
    result = transform(data)
    assert len(result) == expected_length

# ❌ BAD: Tests that depend on each other
class TestSequence:
    def test_1_setup(self):
        self.data = setup()
    
    def test_2_transform(self):
        self.data = transform(self.data)  # Depends on test_1

# ✅ GOOD: Independent tests with fixtures
@pytest.fixture
def setup_data():
    return setup()

def test_transform(setup_data):
    result = transform(setup_data)

# ❌ BAD: Not cleaning up resources
def test_with_temp_file():
    create_file('/tmp/test.csv')
    # File left behind!

# ✅ GOOD: Cleanup in fixture
@pytest.fixture
def temp_file():
    path = '/tmp/test.csv'
    create_file(path)
    yield path
    os.remove(path)

# ❌ BAD: Testing external services directly
def test_real_api():
    response = requests.get('https://api.real-service.com')
    # Slow, flaky, costs money!

# ✅ GOOD: Mock external services
@patch('requests.get')
def test_api(mock_get):
    mock_get.return_value.json.return_value = test_data
```

---

### Sample Interview Exchange

**Interviewer**: "How did you test your retail sales ETL pipeline?"

**You**: "I used pytest at multiple levels:

**1. Unit Tests for Transformations:**
```python
def test_remove_duplicates(transformer, sample_data):
    result = transformer.remove_duplicates(sample_data)
    assert result['sale_id'].is_unique
    assert len(result) == 4  # 5 - 1 duplicate
```

**2. Data Quality Tests:**
```python
@pytest.mark.parametrize('min_rows,should_pass', [
    (100, True),   # 1000 records >= 100
    (2000, False)  # 1000 records < 2000
])
def test_min_record_validation(data, min_rows, should_pass):
    result = validate_min_records(data, min_rows)
    assert result == should_pass
```

**3. Airflow DAG Tests:**
```python
def test_dag_structure(dagbag):
    dag = dagbag.get_dag('retail_sales_etl')
    assert dag.catchup is False
    assert len(dag.tasks) >= 10

@patch('PostgresHook')
def test_extract_task(mock_hook, mock_context):
    mock_hook.return_value.get_records.return_value = test_data
    result = extract_function(**mock_context)
    assert result['status'] == 'success'
```

**4. Integration Tests:**
```python
@pytest.mark.integration
def test_end_to_end(test_db, s3_client):
    # Test full pipeline with real database
    extract_to_db(test_db)
    transform_and_upload(s3_client)
    verify_in_snowflake(test_db)
```

I used fixtures for reusable test data, mocking for external dependencies, and parametrize for testing multiple scenarios. Ran unit tests on every commit (fast), integration tests before deploy (comprehensive)."

---

## Final Checklist for Interviews

**Before your interview, ensure you can:**

- [ ] Explain what pytest is and why use it
- [ ] Write a basic test with assertions
- [ ] Use fixtures for test data
- [ ] Mock external dependencies (databases, APIs)
- [ ] Test for exceptions with `pytest.raises()`
- [ ] Use `@pytest.mark.parametrize` for multiple test cases
- [ ] Differentiate unit vs integration tests
- [ ] Test Airflow DAG structure
- [ ] Test data transformations with pandas
- [ ] Explain your testing strategy for your retail sales pipeline

**Commands to know:**
```bash
pytest                    # Run all tests
pytest -v                 # Verbose
pytest -k "transform"     # Run tests matching name
pytest -m integration     # Run integration tests
pytest --cov=src          # Show coverage
pytest -x                 # Stop on first failure
```

**Good luck with your interviews! 🚀**
