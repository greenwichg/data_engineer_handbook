# Data Testing & Quality - Practical Examples

Hands-on examples you can run immediately to practice data validation, testing, and quality frameworks.

---

## Setup

```bash
# Install required packages
pip install great-expectations pandas faker pytest

# Create test directory
mkdir -p tests/data_quality
touch tests/__init__.py
touch tests/data_quality/__init__.py
```

---

## Example 1: Simple Data Validation

### Create the Validator

Create `src/validators.py`:

```python
"""
Simple data quality validator

Run: python src/validators.py
"""

import pandas as pd
from typing import Dict, List, Any
import logging

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

class SalesDataValidator:
    """Validate sales data against quality rules"""
    
    def __init__(self):
        self.results = []
    
    def validate(self, df: pd.DataFrame) -> Dict[str, Any]:
        """
        Run all validations
        
        Args:
            df: Sales DataFrame
            
        Returns:
            Validation results
        """
        self.results = []
        
        print("Running data quality checks...")
        print("=" * 60)
        
        # Run checks
        self._check_required_columns(df)
        self._check_no_nulls(df)
        self._check_uniqueness(df)
        self._check_value_ranges(df)
        self._check_valid_regions(df)
        
        # Summary
        passed = sum(1 for r in self.results if r['passed'])
        failed = len(self.results) - passed
        
        print("=" * 60)
        print(f"\nResults: {passed} passed, {failed} failed")
        
        return {
            'passed': failed == 0,
            'total_checks': len(self.results),
            'passed_checks': passed,
            'failed_checks': failed,
            'results': self.results
        }
    
    def _log_result(self, check_name: str, passed: bool, message: str):
        """Log and store check result"""
        status = "✓" if passed else "✗"
        print(f"{status} {check_name}: {message}")
        
        self.results.append({
            'check': check_name,
            'passed': passed,
            'message': message
        })
    
    def _check_required_columns(self, df: pd.DataFrame):
        """Check required columns exist"""
        required = ['sale_id', 'customer_id', 'amount', 'quantity', 'region']
        missing = set(required) - set(df.columns)
        
        passed = len(missing) == 0
        message = "All required columns present" if passed else f"Missing: {missing}"
        
        self._log_result("Required Columns", passed, message)
    
    def _check_no_nulls(self, df: pd.DataFrame):
        """Check critical columns have no NULLs"""
        critical = ['sale_id', 'customer_id', 'amount']
        
        for col in critical:
            if col in df.columns:
                null_count = df[col].isnull().sum()
                passed = null_count == 0
                message = "No NULLs" if passed else f"{null_count} NULLs found"
                
                self._log_result(f"No NULLs: {col}", passed, message)
    
    def _check_uniqueness(self, df: pd.DataFrame):
        """Check sale_id is unique"""
        if 'sale_id' in df.columns:
            duplicates = df['sale_id'].duplicated().sum()
            passed = duplicates == 0
            message = "All unique" if passed else f"{duplicates} duplicates found"
            
            self._log_result("Unique sale_id", passed, message)
    
    def _check_value_ranges(self, df: pd.DataFrame):
        """Check value ranges"""
        checks = [
            ('amount', 0, 1000000),
            ('quantity', 1, 10000)
        ]
        
        for col, min_val, max_val in checks:
            if col in df.columns:
                out_of_range = ((df[col] < min_val) | (df[col] > max_val)).sum()
                passed = out_of_range == 0
                message = f"All in [{min_val}, {max_val}]" if passed else f"{out_of_range} out of range"
                
                self._log_result(f"Range: {col}", passed, message)
    
    def _check_valid_regions(self, df: pd.DataFrame):
        """Check region values are valid"""
        if 'region' in df.columns:
            valid = ['US-EAST', 'US-WEST', 'EUROPE', 'ASIA-PACIFIC']
            invalid = ~df['region'].isin(valid)
            invalid_count = invalid.sum()
            
            passed = invalid_count == 0
            message = "All valid regions" if passed else f"{invalid_count} invalid regions"
            
            self._log_result("Valid Regions", passed, message)


if __name__ == '__main__':
    # Create test data
    test_data = pd.DataFrame({
        'sale_id': [1, 2, 3, 4, 5],
        'customer_id': ['C001', 'C002', 'C003', 'C004', 'C005'],
        'amount': [100.0, 200.0, 150.0, 300.0, 175.0],
        'quantity': [1, 2, 1, 3, 2],
        'region': ['US-EAST', 'US-WEST', 'EUROPE', 'US-EAST', 'ASIA-PACIFIC']
    })
    
    # Validate
    validator = SalesDataValidator()
    results = validator.validate(test_data)
    
    if results['passed']:
        print("\n✓ All validation checks passed!")
    else:
        print(f"\n✗ {results['failed_checks']} checks failed")
```

### Run It

```bash
python src/validators.py

# Expected output:
# Running data quality checks...
# ============================================================
# ✓ Required Columns: All required columns present
# ✓ No NULLs: sale_id: No NULLs
# ✓ No NULLs: customer_id: No NULLs
# ✓ No NULLs: amount: No NULLs
# ✓ Unique sale_id: All unique
# ✓ Range: amount: All in [0, 1000000]
# ✓ Range: quantity: All in [1, 10000]
# ✓ Valid Regions: All valid regions
# ============================================================
# 
# Results: 8 passed, 0 failed
# 
# ✓ All validation checks passed!
```

---

## Example 2: Synthetic Test Data Generation

Create `src/test_data_generator.py`:

```python
"""
Generate synthetic test data

Run: python src/test_data_generator.py
"""

import pandas as pd
import random
from datetime import datetime, timedelta
from faker import Faker

fake = Faker()

class SalesDataGenerator:
    """Generate realistic synthetic sales data"""
    
    def __init__(self, seed=42):
        random.seed(seed)
        Faker.seed(seed)
        
        self.regions = ['US-EAST', 'US-WEST', 'EUROPE', 'ASIA-PACIFIC']
        self.categories = ['Electronics', 'Clothing', 'Food', 'Home', 'Sports']
        self.statuses = ['completed', 'pending', 'cancelled']
    
    def generate(self, n_records=1000, start_date=None):
        """
        Generate synthetic sales data
        
        Args:
            n_records: Number of records to generate
            start_date: Start date for sales (default: 30 days ago)
            
        Returns:
            DataFrame with synthetic data
        """
        if start_date is None:
            start_date = datetime.now() - timedelta(days=30)
        
        print(f"Generating {n_records} records...")
        
        data = []
        
        for i in range(n_records):
            quantity = random.randint(1, 10)
            unit_price = round(random.uniform(10, 500), 2)
            subtotal = quantity * unit_price
            discount_rate = random.choice([0, 0.1, 0.2, 0.3]) if random.random() > 0.7 else 0
            discount_amount = round(subtotal * discount_rate, 2)
            total = round(subtotal - discount_amount, 2)
            
            record = {
                'sale_id': i + 1,
                'customer_id': fake.uuid4(),
                'customer_name': fake.name(),
                'email': fake.email(),
                'product_id': f"P{random.randint(100000, 999999)}",
                'product_name': fake.catch_phrase(),
                'category': random.choice(self.categories),
                'quantity': quantity,
                'unit_price': unit_price,
                'subtotal': subtotal,
                'discount_rate': discount_rate,
                'discount_amount': discount_amount,
                'total_amount': total,
                'region': random.choice(self.regions),
                'status': random.choice(self.statuses),
                'sale_date': start_date + timedelta(days=random.randint(0, 30)),
                'created_at': datetime.now()
            }
            
            data.append(record)
        
        df = pd.DataFrame(data)
        print(f"✓ Generated {len(df)} records")
        print(f"  Date range: {df['sale_date'].min()} to {df['sale_date'].max()}")
        print(f"  Total sales: ${df['total_amount'].sum():,.2f}")
        
        return df
    
    def generate_edge_cases(self):
        """Generate edge case data for testing"""
        print("Generating edge case data...")
        
        data = [
            # NULL values
            {
                'sale_id': 1,
                'customer_id': None,
                'amount': 100.0,
                'quantity': 1,
                'region': 'US-EAST',
                'comment': 'NULL customer_id'
            },
            # Zero values
            {
                'sale_id': 2,
                'customer_id': 'C002',
                'amount': 0.0,
                'quantity': 0,
                'region': 'US-WEST',
                'comment': 'Zero amount and quantity'
            },
            # Negative values
            {
                'sale_id': 3,
                'customer_id': 'C003',
                'amount': -50.0,
                'quantity': -1,
                'region': 'EUROPE',
                'comment': 'Negative values (refund?)'
            },
            # Maximum values
            {
                'sale_id': 4,
                'customer_id': 'C004',
                'amount': 999999.99,
                'quantity': 9999,
                'region': 'ASIA-PACIFIC',
                'comment': 'Maximum valid values'
            },
            # Duplicate sale_id
            {
                'sale_id': 1,  # Duplicate!
                'customer_id': 'C005',
                'amount': 200.0,
                'quantity': 2,
                'region': 'US-EAST',
                'comment': 'Duplicate sale_id'
            },
            # Invalid region
            {
                'sale_id': 6,
                'customer_id': 'C006',
                'amount': 150.0,
                'quantity': 1,
                'region': 'INVALID',
                'comment': 'Invalid region'
            }
        ]
        
        df = pd.DataFrame(data)
        print(f"✓ Generated {len(df)} edge case records")
        
        return df
    
    def save_to_csv(self, df, filename):
        """Save DataFrame to CSV"""
        df.to_csv(filename, index=False)
        print(f"✓ Saved to {filename}")


if __name__ == '__main__':
    generator = SalesDataGenerator()
    
    # Generate normal data
    df_normal = generator.generate(n_records=100)
    generator.save_to_csv(df_normal, 'data/sales_normal.csv')
    
    print()
    
    # Generate edge cases
    df_edge = generator.generate_edge_cases()
    generator.save_to_csv(df_edge, 'data/sales_edge_cases.csv')
    
    print("\nSample normal data:")
    print(df_normal.head())
    
    print("\nEdge case data:")
    print(df_edge[['sale_id', 'amount', 'quantity', 'region', 'comment']])
```

### Run It

```bash
# Create data directory
mkdir -p data

# Generate test data
python src/test_data_generator.py
```

---

## Example 3: Pytest Tests for Data Quality

Create `tests/test_data_quality.py`:

```python
"""
Pytest tests for data quality

Run: pytest tests/test_data_quality.py -v
"""

import pytest
import pandas as pd
from src.validators import SalesDataValidator

class TestDataQuality:
    """Test data quality validation"""
    
    @pytest.fixture
    def validator(self):
        """Create validator instance"""
        return SalesDataValidator()
    
    @pytest.fixture
    def valid_data(self):
        """Valid sales data"""
        return pd.DataFrame({
            'sale_id': [1, 2, 3],
            'customer_id': ['C001', 'C002', 'C003'],
            'amount': [100.0, 200.0, 150.0],
            'quantity': [1, 2, 1],
            'region': ['US-EAST', 'US-WEST', 'EUROPE']
        })
    
    @pytest.fixture
    def data_with_nulls(self):
        """Data with NULL values"""
        return pd.DataFrame({
            'sale_id': [1, None, 3],
            'customer_id': ['C001', 'C002', None],
            'amount': [100.0, 200.0, 150.0],
            'quantity': [1, 2, 1],
            'region': ['US-EAST', 'US-WEST', 'EUROPE']
        })
    
    @pytest.fixture
    def data_with_duplicates(self):
        """Data with duplicate sale_ids"""
        return pd.DataFrame({
            'sale_id': [1, 2, 2],
            'customer_id': ['C001', 'C002', 'C003'],
            'amount': [100.0, 200.0, 150.0],
            'quantity': [1, 2, 1],
            'region': ['US-EAST', 'US-WEST', 'EUROPE']
        })
    
    def test_valid_data_passes(self, validator, valid_data):
        """Test that valid data passes all checks"""
        results = validator.validate(valid_data)
        assert results['passed'] is True
        assert results['failed_checks'] == 0
    
    def test_detects_null_values(self, validator, data_with_nulls):
        """Test that NULL values are detected"""
        results = validator.validate(data_with_nulls)
        assert results['passed'] is False
        assert results['failed_checks'] > 0
    
    def test_detects_duplicates(self, validator, data_with_duplicates):
        """Test that duplicates are detected"""
        results = validator.validate(data_with_duplicates)
        assert results['passed'] is False
        
        # Check that duplicate check specifically failed
        failed_checks = [r for r in results['results'] if not r['passed']]
        assert any('unique' in r['check'].lower() for r in failed_checks)
    
    def test_detects_invalid_region(self, validator):
        """Test that invalid regions are detected"""
        data = pd.DataFrame({
            'sale_id': [1],
            'customer_id': ['C001'],
            'amount': [100.0],
            'quantity': [1],
            'region': ['INVALID-REGION']
        })
        
        results = validator.validate(data)
        assert results['passed'] is False
    
    @pytest.mark.parametrize("amount,should_pass", [
        (100.0, True),      # Valid
        (0.0, True),        # Minimum valid
        (-0.01, False),     # Below minimum
        (1000000, True),    # Maximum valid
        (1000001, False),   # Above maximum
    ])
    def test_amount_ranges(self, validator, amount, should_pass):
        """Test amount range validation"""
        data = pd.DataFrame({
            'sale_id': [1],
            'customer_id': ['C001'],
            'amount': [amount],
            'quantity': [1],
            'region': ['US-EAST']
        })
        
        results = validator.validate(data)
        assert results['passed'] == should_pass


class TestBoundaryConditions:
    """Test boundary conditions"""
    
    @pytest.fixture
    def validator(self):
        return SalesDataValidator()
    
    def test_empty_dataframe(self, validator):
        """Test with empty DataFrame"""
        df = pd.DataFrame(columns=['sale_id', 'customer_id', 'amount', 'quantity', 'region'])
        results = validator.validate(df)
        # Should handle empty DataFrame gracefully
        assert isinstance(results, dict)
    
    def test_single_row(self, validator):
        """Test with single row"""
        df = pd.DataFrame({
            'sale_id': [1],
            'customer_id': ['C001'],
            'amount': [100.0],
            'quantity': [1],
            'region': ['US-EAST']
        })
        
        results = validator.validate(df)
        assert results['passed'] is True
    
    def test_minimum_valid_values(self, validator):
        """Test minimum valid values"""
        df = pd.DataFrame({
            'sale_id': [1],
            'customer_id': ['C001'],
            'amount': [0.0],  # Minimum
            'quantity': [1],  # Minimum
            'region': ['US-EAST']
        })
        
        results = validator.validate(df)
        assert results['passed'] is True
    
    def test_maximum_valid_values(self, validator):
        """Test maximum valid values"""
        df = pd.DataFrame({
            'sale_id': [1],
            'customer_id': ['C001'],
            'amount': [1000000.0],  # Maximum
            'quantity': [10000],     # Maximum
            'region': ['US-EAST']
        })
        
        results = validator.validate(df)
        assert results['passed'] is True


if __name__ == '__main__':
    pytest.main([__file__, '-v'])
```

### Run Tests

```bash
# Run all tests
pytest tests/test_data_quality.py -v

# Run specific test class
pytest tests/test_data_quality.py::TestDataQuality -v

# Run with coverage
pytest tests/test_data_quality.py --cov=src --cov-report=html
```

---

## Example 4: Great Expectations Quick Start

Create `examples/great_expectations_demo.py`:

```python
"""
Great Expectations quick demo

Run: python examples/great_expectations_demo.py
"""

import great_expectations as ge
import pandas as pd
from datetime import datetime, timedelta

def create_test_data():
    """Create test sales data"""
    return pd.DataFrame({
        'sale_id': range(1, 101),
        'customer_id': [f'C{i:03d}' for i in range(1, 101)],
        'amount': [100.0 + i * 10 for i in range(100)],
        'quantity': [i % 10 + 1 for i in range(100)],
        'region': ['US-EAST', 'US-WEST', 'EUROPE', 'ASIA-PACIFIC'] * 25,
        'sale_date': [datetime.now() - timedelta(days=i%30) for i in range(100)]
    })

def demo_basic_expectations():
    """Demo basic Great Expectations usage"""
    print("=" * 70)
    print("GREAT EXPECTATIONS DEMO")
    print("=" * 70)
    
    # Create data
    df = create_test_data()
    print(f"\nCreated test data: {len(df)} records")
    
    # Convert to GE DataFrame
    ge_df = ge.from_pandas(df)
    print("✓ Converted to Great Expectations DataFrame")
    
    # Set expectations
    print("\nSetting expectations...")
    
    # 1. Column existence
    result = ge_df.expect_table_columns_to_match_ordered_list([
        'sale_id', 'customer_id', 'amount', 'quantity', 'region', 'sale_date'
    ])
    print(f"  Column list: {'✓ PASS' if result['success'] else '✗ FAIL'}")
    
    # 2. No NULLs
    result = ge_df.expect_column_values_to_not_be_null('sale_id')
    print(f"  No NULLs in sale_id: {'✓ PASS' if result['success'] else '✗ FAIL'}")
    
    # 3. Uniqueness
    result = ge_df.expect_column_values_to_be_unique('sale_id')
    print(f"  Unique sale_id: {'✓ PASS' if result['success'] else '✗ FAIL'}")
    
    # 4. Value range
    result = ge_df.expect_column_values_to_be_between(
        'amount', min_value=0, max_value=10000
    )
    print(f"  Amount range [0, 10000]: {'✓ PASS' if result['success'] else '✗ FAIL'}")
    
    # 5. Set membership
    result = ge_df.expect_column_values_to_be_in_set(
        'region', ['US-EAST', 'US-WEST', 'EUROPE', 'ASIA-PACIFIC']
    )
    print(f"  Valid regions: {'✓ PASS' if result['success'] else '✗ FAIL'}")
    
    # 6. Statistical
    result = ge_df.expect_column_mean_to_be_between('amount', min_value=0, max_value=2000)
    print(f"  Mean amount in range: {'✓ PASS' if result['success'] else '✗ FAIL'}")
    
    # Get full validation results
    print("\nRunning full validation...")
    validation_results = ge_df.validate()
    
    print(f"\n{'=' * 70}")
    print(f"RESULTS SUMMARY")
    print(f"{'=' * 70}")
    print(f"Success: {validation_results['success']}")
    print(f"Evaluated: {validation_results['statistics']['evaluated_expectations']}")
    print(f"Successful: {validation_results['statistics']['successful_expectations']}")
    print(f"Failed: {validation_results['statistics']['unsuccessful_expectations']}")
    
    return validation_results

def demo_with_bad_data():
    """Demo with data that fails validation"""
    print("\n" + "=" * 70)
    print("TESTING WITH BAD DATA")
    print("=" * 70)
    
    # Create data with issues
    bad_df = pd.DataFrame({
        'sale_id': [1, 2, 2, 4],  # Duplicate!
        'customer_id': ['C001', None, 'C003', 'C004'],  # NULL!
        'amount': [100.0, 200.0, -50.0, 1500000],  # Negative and too large!
        'quantity': [1, 2, 0, 5],  # Zero!
        'region': ['US-EAST', 'INVALID', 'EUROPE', 'US-WEST'],  # Invalid!
        'sale_date': [datetime.now()] * 4
    })
    
    print(f"\nCreated bad data: {len(bad_df)} records")
    print("Issues: duplicates, NULLs, invalid values")
    
    # Convert and validate
    ge_df = ge.from_pandas(bad_df)
    
    # Set expectations
    ge_df.expect_column_values_to_be_unique('sale_id')
    ge_df.expect_column_values_to_not_be_null('customer_id')
    ge_df.expect_column_values_to_be_between('amount', min_value=0, max_value=1000000)
    ge_df.expect_column_values_to_be_between('quantity', min_value=1, max_value=10000)
    ge_df.expect_column_values_to_be_in_set(
        'region', ['US-EAST', 'US-WEST', 'EUROPE', 'ASIA-PACIFIC']
    )
    
    # Validate
    results = ge_df.validate()
    
    print(f"\nValidation: {'✓ PASS' if results['success'] else '✗ FAIL'}")
    print(f"Failed checks: {results['statistics']['unsuccessful_expectations']}")
    
    # Show failed expectations
    print("\nFailed expectations:")
    for result in results['results']:
        if not result['success']:
            expectation_type = result['expectation_config']['expectation_type']
            column = result['expectation_config'].get('kwargs', {}).get('column', 'N/A')
            print(f"  ✗ {expectation_type} on column '{column}'")
    
    return results

if __name__ == '__main__':
    # Demo 1: Valid data
    demo_basic_expectations()
    
    # Demo 2: Invalid data
    demo_with_bad_data()
    
    print("\n" + "=" * 70)
    print("DEMO COMPLETE")
    print("=" * 70)
```

### Run Great Expectations Demo

```bash
python examples/great_expectations_demo.py
```

---

## Example 5: Integration Test with Airflow

Create `tests/test_integration.py`:

```python
"""
Integration tests for data pipeline

Run: pytest tests/test_integration.py -v -m integration
"""

import pytest
import pandas as pd
from unittest.mock import Mock, patch
from src.validators import SalesDataValidator
from src.test_data_generator import SalesDataGenerator

@pytest.mark.integration
class TestPipelineIntegration:
    """Integration tests for complete pipeline"""
    
    @pytest.fixture
    def test_data(self):
        """Generate test data"""
        generator = SalesDataGenerator()
        return generator.generate(n_records=100)
    
    def test_end_to_end_validation(self, test_data):
        """Test complete pipeline with validation"""
        
        # Step 1: Extract (simulated)
        extracted_df = test_data.copy()
        assert len(extracted_df) == 100
        
        # Step 2: Validate
        validator = SalesDataValidator()
        validation_results = validator.validate(extracted_df)
        
        assert validation_results['passed'], \
            f"{validation_results['failed_checks']} validation checks failed"
        
        # Step 3: Transform (simple example)
        transformed_df = extracted_df.copy()
        transformed_df['net_amount'] = (
            transformed_df['total_amount'] - 
            transformed_df['discount_amount']
        )
        
        # Step 4: Validate transformed data
        assert 'net_amount' in transformed_df.columns
        assert (transformed_df['net_amount'] >= 0).all()
        
        print(f"✓ End-to-end test passed with {len(transformed_df)} records")
    
    @patch('src.validators.SalesDataValidator')
    def test_validation_in_pipeline(self, mock_validator, test_data):
        """Test that validation is called in pipeline"""
        
        # Setup mock
        mock_instance = Mock()
        mock_instance.validate.return_value = {'passed': True}
        mock_validator.return_value = mock_instance
        
        # Run pipeline (simplified)
        def run_pipeline(df):
            validator = mock_validator()
            results = validator.validate(df)
            return results['passed']
        
        passed = run_pipeline(test_data)
        
        # Verify validation was called
        assert mock_instance.validate.called
        assert passed is True
    
    def test_handles_edge_cases(self):
        """Test pipeline handles edge cases"""
        generator = SalesDataGenerator()
        edge_cases = generator.generate_edge_cases()
        
        validator = SalesDataValidator()
        results = validator.validate(edge_cases)
        
        # Edge cases should fail validation
        assert not results['passed']
        assert results['failed_checks'] > 0
        
        print(f"✓ Edge cases correctly detected: {results['failed_checks']} issues")


if __name__ == '__main__':
    pytest.main([__file__, '-v', '-m', 'integration'])
```

### Run Integration Tests

```bash
# Run integration tests
pytest tests/test_integration.py -v -m integration

# Run all tests including integration
pytest tests/ -v
```

---

## Example 6: Regression Test with Snapshots

Create `tests/test_regression.py`:

```python
"""
Regression tests for data pipeline

Run: pytest tests/test_regression.py -v
"""

import pytest
import pandas as pd
import json
import os
from pathlib import Path

class TestDataRegression:
    """Regression tests to catch unexpected changes"""
    
    SNAPSHOT_DIR = Path('tests/snapshots')
    
    @pytest.fixture(autouse=True)
    def setup(self):
        """Create snapshot directory"""
        self.SNAPSHOT_DIR.mkdir(parents=True, exist_ok=True)
    
    def save_snapshot(self, name: str, data: dict):
        """Save snapshot"""
        path = self.SNAPSHOT_DIR / f'{name}.json'
        with open(path, 'w') as f:
            json.dump(data, f, indent=2, default=str)
    
    def load_snapshot(self, name: str):
        """Load snapshot"""
        path = self.SNAPSHOT_DIR / f'{name}.json'
        if not path.exists():
            return None
        with open(path, 'r') as f:
            return json.load(f)
    
    def test_schema_regression(self):
        """Test that data schema hasn't changed"""
        # Current schema
        df = pd.DataFrame({
            'sale_id': [1],
            'amount': [100.0],
            'quantity': [1],
            'region': ['US-EAST']
        })
        
        current_schema = {
            'columns': list(df.columns),
            'dtypes': {col: str(dtype) for col, dtype in df.dtypes.items()}
        }
        
        # Load snapshot
        snapshot = self.load_snapshot('schema')
        
        if snapshot is None:
            # First run - save snapshot
            self.save_snapshot('schema', current_schema)
            pytest.skip("First run - snapshot saved")
        
        # Compare
        assert current_schema['columns'] == snapshot['columns'], \
            "Schema columns have changed!"
        assert current_schema['dtypes'] == snapshot['dtypes'], \
            "Data types have changed!"
    
    def test_transformation_regression(self):
        """Test that transformation produces same results"""
        # Input data
        input_df = pd.DataFrame({
            'sale_id': [1, 2, 3],
            'amount': [100, 200, 150],
            'discount': [10, 20, 15]
        })
        
        # Transform (simple example)
        result = input_df.copy()
        result['net_amount'] = result['amount'] - result['discount']
        
        # Expected (from known good run)
        expected = {
            'net_amounts': [90, 180, 135],
            'total': 405
        }
        
        actual = {
            'net_amounts': result['net_amount'].tolist(),
            'total': int(result['net_amount'].sum())
        }
        
        # Load snapshot
        snapshot = self.load_snapshot('transformation')
        
        if snapshot is None:
            self.save_snapshot('transformation', expected)
            pytest.skip("First run - snapshot saved")
        
        # Compare
        assert actual == snapshot, "Transformation results have changed!"


if __name__ == '__main__':
    pytest.main([__file__, '-v'])
```

---

## Running All Examples

```bash
# 1. Setup
pip install great-expectations pandas faker pytest
mkdir -p data examples tests/snapshots

# 2. Run simple validator
python src/validators.py

# 3. Generate test data
python src/test_data_generator.py

# 4. Run Great Expectations demo
python examples/great_expectations_demo.py

# 5. Run all tests
pytest tests/ -v

# 6. Run with coverage
pytest tests/ --cov=src --cov-report=html

# 7. View coverage report
open htmlcov/index.html  # Mac
# or
start htmlcov/index.html  # Windows
```

---

## Common Commands

```bash
# Testing
pytest tests/test_data_quality.py -v              # Specific file
pytest tests/test_data_quality.py::TestDataQuality -v  # Specific class
pytest -k "test_null" -v                          # Pattern match
pytest -m integration -v                          # Integration tests only
pytest --cov=src --cov-report=html                # With coverage

# Great Expectations
great_expectations init                           # Initialize GE project
great_expectations suite new                      # Create expectation suite
great_expectations checkpoint run my_checkpoint   # Run validation

# Data Generation
python src/test_data_generator.py                 # Generate test data
```

---

## Troubleshooting

### Problem: "ModuleNotFoundError"
```bash
# Solution: Install in development mode
pip install -e .
# Or add to PYTHONPATH
export PYTHONPATH="${PYTHONPATH}:$(pwd)"
```

### Problem: Tests pass but coverage is 0%
```bash
# Solution: Install package first
pip install -e .
pytest --cov=src --cov-report=term
```

### Problem: Great Expectations import error
```bash
# Solution: Ensure correct installation
pip uninstall great-expectations
pip install great-expectations
python -c "import great_expectations; print(great_expectations.__version__)"
```

---

**You now have complete working examples to practice data testing and quality! 🚀**

Next: Interview Quick Reference Card...
