# PySpark Implementation: Unit Testing PySpark Pipelines

## Problem Statement

Testing data transformation pipelines is essential for ensuring correctness, catching regressions, and enabling safe refactoring. Given a function that cleans and enriches customer orders (e.g., filtering invalid rows, adding computed columns, handling nulls), write unit tests using pytest. Demonstrate how to create reusable SparkSession fixtures, test DataFrame transformations, handle edge cases (nulls, empty DataFrames, schema mismatches), and use assertion libraries purpose-built for PySpark. This is a frequently asked topic in data engineering interviews because untested pipelines are the leading cause of silent data corruption in production.

### Sample Data

**Input: Raw Customer Orders**

```
order_id | customer_id | product    | quantity | unit_price | order_date  | status
1001     | C01         | Laptop     | 1        | 999.99     | 2024-01-15  | completed
1002     | C02         | Mouse      | -3       | 25.00      | 2024-01-16  | completed
1003     | C01         | NULL       | 2        | 50.00      | 2024-01-17  | pending
1004     | NULL        | Keyboard   | 1        | 75.00      | 2024-01-18  | completed
1005     | C03         | Monitor    | 1        | 300.00     | 2024-01-19  | cancelled
1006     | C02         | Headphones | 0        | 60.00      | 2024-01-20  | completed
```

**Expected Output: Cleaned and Enriched Orders**

```
order_id | customer_id | product    | quantity | unit_price | order_date  | status    | total_amount
1001     | C01         | Laptop     | 1        | 999.99     | 2024-01-15  | completed | 999.99
```

Only `completed` orders with non-null `customer_id`, non-null `product`, and `quantity > 0` are kept. A `total_amount` column is added as `quantity * unit_price`.

---

## The Transformation Function Under Test

```python
# transformations.py
from pyspark.sql import DataFrame
from pyspark.sql.functions import col


def clean_and_enrich_orders(df: DataFrame) -> DataFrame:
    """
    Clean raw customer orders and add computed columns.

    Rules:
    - Keep only 'completed' orders
    - Remove rows where customer_id or product is null
    - Remove rows where quantity <= 0
    - Add total_amount = quantity * unit_price
    """
    cleaned = (
        df
        .filter(col("status") == "completed")
        .filter(col("customer_id").isNotNull())
        .filter(col("product").isNotNull())
        .filter(col("quantity") > 0)
        .withColumn("total_amount", col("quantity") * col("unit_price"))
    )
    return cleaned
```

---

## Method 1: pytest with `pyspark.testing` (assertEqual for DataFrames)

```python
# test_transformations_v1.py
import pytest
from pyspark.sql import SparkSession
from pyspark.sql.types import (
    StructType, StructField, StringType, IntegerType, DoubleType, DateType
)
from pyspark.testing.utils import assertDataFrameEqual
from transformations import clean_and_enrich_orders


# --- conftest.py SparkSession fixture (session-scoped) ---
# In practice, put this in conftest.py so all test files share one SparkSession.

@pytest.fixture(scope="session")
def spark():
    """
    Session-scoped SparkSession fixture.
    Created once, shared across all tests in the session, stopped at teardown.
    """
    spark = (
        SparkSession.builder
        .master("local[2]")
        .appName("unit-tests")
        .config("spark.sql.shuffle.partitions", "2")   # small for tests
        .config("spark.default.parallelism", "2")
        .config("spark.ui.enabled", "false")            # disable UI overhead
        .config("spark.driver.bindAddress", "127.0.0.1")
        .getOrCreate()
    )
    yield spark
    spark.stop()


# --- Schema fixture for reuse ---
@pytest.fixture
def orders_schema():
    return StructType([
        StructField("order_id", IntegerType(), False),
        StructField("customer_id", StringType(), True),
        StructField("product", StringType(), True),
        StructField("quantity", IntegerType(), True),
        StructField("unit_price", DoubleType(), True),
        StructField("order_date", StringType(), True),
        StructField("status", StringType(), True),
    ])


# --- Test: basic happy path ---
def test_clean_and_enrich_happy_path(spark, orders_schema):
    input_data = [
        (1001, "C01", "Laptop", 1, 999.99, "2024-01-15", "completed"),
        (1002, "C02", "Mouse", -3, 25.00, "2024-01-16", "completed"),
        (1003, "C01", None, 2, 50.00, "2024-01-17", "pending"),
        (1004, None, "Keyboard", 1, 75.00, "2024-01-18", "completed"),
        (1005, "C03", "Monitor", 1, 300.00, "2024-01-19", "cancelled"),
        (1006, "C02", "Headphones", 0, 60.00, "2024-01-20", "completed"),
    ]
    input_df = spark.createDataFrame(input_data, schema=orders_schema)

    result = clean_and_enrich_orders(input_df)

    expected_data = [
        (1001, "C01", "Laptop", 1, 999.99, "2024-01-15", "completed", 999.99),
    ]
    expected_schema = StructType(
        orders_schema.fields + [StructField("total_amount", DoubleType(), True)]
    )
    expected_df = spark.createDataFrame(expected_data, schema=expected_schema)

    # pyspark.testing.utils.assertDataFrameEqual (PySpark 3.3+)
    assertDataFrameEqual(result, expected_df)


# --- Test: empty input DataFrame ---
def test_empty_dataframe(spark, orders_schema):
    empty_df = spark.createDataFrame([], schema=orders_schema)
    result = clean_and_enrich_orders(empty_df)
    assert result.count() == 0


# --- Test: all rows filtered out ---
def test_all_rows_filtered(spark, orders_schema):
    data = [
        (1, None, "Laptop", 1, 100.0, "2024-01-01", "completed"),
        (2, "C01", "Mouse", 1, 50.0, "2024-01-02", "cancelled"),
    ]
    df = spark.createDataFrame(data, schema=orders_schema)
    result = clean_and_enrich_orders(df)
    assert result.count() == 0


# --- Test: schema of output ---
def test_output_schema(spark, orders_schema):
    data = [(1, "C01", "Laptop", 1, 100.0, "2024-01-01", "completed")]
    df = spark.createDataFrame(data, schema=orders_schema)
    result = clean_and_enrich_orders(df)

    assert "total_amount" in result.columns
    assert result.schema["total_amount"].dataType == DoubleType()
```

### Step-by-Step Explanation

#### Step 1: Session-Scoped SparkSession
- **Why session-scoped?** Starting a SparkSession is expensive (several seconds). By scoping it to the entire test session, we start it once and reuse it across all tests. This is the single most important optimization for PySpark test suites.
- **Config tuning:** `shuffle.partitions=2` and `parallelism=2` keep tests fast. Disabling the Spark UI avoids port-binding issues in CI.

#### Step 2: Small Deterministic Data
- Tests use hardcoded tuples, not files or databases. This makes tests reproducible, fast, and environment-independent.

#### Step 3: assertDataFrameEqual
- `pyspark.testing.utils.assertDataFrameEqual` compares two DataFrames element-by-element, ignoring row order by default. Available since PySpark 3.3.

---

## Method 2: Using the `chispa` Library

```python
# test_transformations_chispa.py
import pytest
from pyspark.sql import SparkSession
from pyspark.sql.types import (
    StructType, StructField, StringType, IntegerType, DoubleType
)
from chispa.dataframe_comparer import assert_df_equality
from chispa.column_comparer import assert_column_equality
from transformations import clean_and_enrich_orders


@pytest.fixture(scope="session")
def spark():
    spark = (
        SparkSession.builder
        .master("local[2]")
        .appName("chispa-tests")
        .config("spark.sql.shuffle.partitions", "2")
        .config("spark.ui.enabled", "false")
        .getOrCreate()
    )
    yield spark
    spark.stop()


# --- Test: full DataFrame comparison with chispa ---
def test_clean_and_enrich_with_chispa(spark):
    input_data = [
        (1, "C01", "Laptop", 2, 500.0, "2024-01-01", "completed"),
        (2, "C02", "Mouse", 5, 20.0, "2024-01-02", "completed"),
        (3, "C03", "Cable", 1, 10.0, "2024-01-03", "cancelled"),
    ]
    schema = StructType([
        StructField("order_id", IntegerType()),
        StructField("customer_id", StringType()),
        StructField("product", StringType()),
        StructField("quantity", IntegerType()),
        StructField("unit_price", DoubleType()),
        StructField("order_date", StringType()),
        StructField("status", StringType()),
    ])
    input_df = spark.createDataFrame(input_data, schema=schema)

    result = clean_and_enrich_orders(input_df)

    expected_data = [
        (1, "C01", "Laptop", 2, 500.0, "2024-01-01", "completed", 1000.0),
        (2, "C02", "Mouse", 5, 20.0, "2024-01-02", "completed", 100.0),
    ]
    expected_schema = StructType(
        schema.fields + [StructField("total_amount", DoubleType())]
    )
    expected_df = spark.createDataFrame(expected_data, schema=expected_schema)

    # chispa: ignore row order, compare schemas strictly
    assert_df_equality(result, expected_df, ignore_row_order=True)


# --- Test: column-level assertion with chispa ---
def test_total_amount_column(spark):
    """Verify total_amount is computed correctly using column equality."""
    data = [
        (1, "C01", "Widget", 3, 10.0, "2024-01-01", "completed"),
        (2, "C02", "Gadget", 2, 25.0, "2024-01-02", "completed"),
    ]
    schema = StructType([
        StructField("order_id", IntegerType()),
        StructField("customer_id", StringType()),
        StructField("product", StringType()),
        StructField("quantity", IntegerType()),
        StructField("unit_price", DoubleType()),
        StructField("order_date", StringType()),
        StructField("status", StringType()),
    ])
    df = spark.createDataFrame(data, schema=schema)

    result = clean_and_enrich_orders(df)

    # Add an independently computed expected column to compare against
    from pyspark.sql.functions import col, lit
    result_with_expected = result.withColumn(
        "expected_total", col("quantity") * col("unit_price")
    )

    # chispa: assert two columns in the same DataFrame are equal
    assert_column_equality(result_with_expected, "total_amount", "expected_total")


# --- Test: approximate equality for floating point ---
def test_floating_point_tolerance(spark):
    """chispa supports precision tolerance for float comparisons."""
    data = [(1, "C01", "Item", 3, 33.33, "2024-01-01", "completed")]
    schema = StructType([
        StructField("order_id", IntegerType()),
        StructField("customer_id", StringType()),
        StructField("product", StringType()),
        StructField("quantity", IntegerType()),
        StructField("unit_price", DoubleType()),
        StructField("order_date", StringType()),
        StructField("status", StringType()),
    ])
    df = spark.createDataFrame(data, schema=schema)
    result = clean_and_enrich_orders(df)

    expected_data = [(1, "C01", "Item", 3, 33.33, "2024-01-01", "completed", 99.99)]
    expected_schema = StructType(
        schema.fields + [StructField("total_amount", DoubleType())]
    )
    expected_df = spark.createDataFrame(expected_data, schema=expected_schema)

    # Allow small floating-point differences
    assert_df_equality(result, expected_df, ignore_row_order=True, precision=0.01)
```

### Why `chispa`?

| Feature | `pyspark.testing` | `chispa` |
|---------|-------------------|----------|
| DataFrame equality | Yes (3.3+) | Yes |
| Column-level comparison | No | Yes (`assert_column_equality`) |
| Float precision tolerance | Limited | Built-in `precision` param |
| Readable diff output | Basic | Color-coded, row-by-row diff |
| Schema mismatch reporting | Basic | Detailed field-by-field diff |
| Works with older PySpark | 3.3+ only | Any version |

Install: `pip install chispa`

---

## Method 3: Testing with `assertDataFrameEqual` (PySpark 3.5+)

```python
# test_transformations_spark35.py
import pytest
from pyspark.sql import SparkSession
from pyspark.sql.types import (
    StructType, StructField, StringType, IntegerType, DoubleType
)
from pyspark.sql.functions import col
from pyspark.testing import assertDataFrameEqual, assertSchemaEqual
from transformations import clean_and_enrich_orders


@pytest.fixture(scope="session")
def spark():
    spark = (
        SparkSession.builder
        .master("local[2]")
        .appName("spark35-tests")
        .config("spark.sql.shuffle.partitions", "2")
        .config("spark.ui.enabled", "false")
        .getOrCreate()
    )
    yield spark
    spark.stop()


# --- Test: assertDataFrameEqual with Row objects ---
def test_with_row_objects(spark):
    """PySpark 3.5+ allows comparing against a list of Row objects directly."""
    from pyspark.sql import Row

    data = [(1, "C01", "Laptop", 2, 500.0, "2024-01-01", "completed")]
    schema = StructType([
        StructField("order_id", IntegerType()),
        StructField("customer_id", StringType()),
        StructField("product", StringType()),
        StructField("quantity", IntegerType()),
        StructField("unit_price", DoubleType()),
        StructField("order_date", StringType()),
        StructField("status", StringType()),
    ])
    df = spark.createDataFrame(data, schema=schema)
    result = clean_and_enrich_orders(df)

    # Compare against a list of Row objects (no need to create expected DataFrame)
    expected_rows = [
        Row(
            order_id=1, customer_id="C01", product="Laptop",
            quantity=2, unit_price=500.0, order_date="2024-01-01",
            status="completed", total_amount=1000.0
        )
    ]

    assertDataFrameEqual(result, expected_rows)


# --- Test: schema assertion (PySpark 3.5+) ---
def test_output_schema_strict(spark):
    """assertSchemaEqual validates full schema structure."""
    data = [(1, "C01", "Laptop", 1, 100.0, "2024-01-01", "completed")]
    schema = StructType([
        StructField("order_id", IntegerType()),
        StructField("customer_id", StringType()),
        StructField("product", StringType()),
        StructField("quantity", IntegerType()),
        StructField("unit_price", DoubleType()),
        StructField("order_date", StringType()),
        StructField("status", StringType()),
    ])
    df = spark.createDataFrame(data, schema=schema)
    result = clean_and_enrich_orders(df)

    expected_schema = StructType(
        schema.fields + [StructField("total_amount", DoubleType(), True)]
    )

    assertSchemaEqual(result.schema, expected_schema)


# --- Test: null handling edge cases ---
def test_null_handling(spark):
    """Verify that rows with null customer_id, product, or quantity are dropped."""
    data = [
        (1, None, "Laptop", 1, 100.0, "2024-01-01", "completed"),
        (2, "C01", None, 1, 100.0, "2024-01-02", "completed"),
        (3, "C01", "Laptop", None, 100.0, "2024-01-03", "completed"),
        (4, "C01", "Laptop", 1, 100.0, "2024-01-04", "completed"),
    ]
    schema = StructType([
        StructField("order_id", IntegerType()),
        StructField("customer_id", StringType()),
        StructField("product", StringType()),
        StructField("quantity", IntegerType()),
        StructField("unit_price", DoubleType()),
        StructField("order_date", StringType()),
        StructField("status", StringType()),
    ])
    df = spark.createDataFrame(data, schema=schema)
    result = clean_and_enrich_orders(df)

    # Only row 4 should survive
    assert result.count() == 1
    assert result.first()["order_id"] == 4


# --- Test: assertDataFrameEqual with tolerance ---
def test_float_tolerance_spark35(spark):
    """PySpark 3.5 assertDataFrameEqual supports rtol and atol."""
    from pyspark.sql import Row

    data = [(1, "C01", "Item", 3, 33.333, "2024-01-01", "completed")]
    schema = StructType([
        StructField("order_id", IntegerType()),
        StructField("customer_id", StringType()),
        StructField("product", StringType()),
        StructField("quantity", IntegerType()),
        StructField("unit_price", DoubleType()),
        StructField("order_date", StringType()),
        StructField("status", StringType()),
    ])
    df = spark.createDataFrame(data, schema=schema)
    result = clean_and_enrich_orders(df)

    expected = [
        Row(
            order_id=1, customer_id="C01", product="Item",
            quantity=3, unit_price=33.333, order_date="2024-01-01",
            status="completed", total_amount=99.999
        )
    ]

    # atol = absolute tolerance, rtol = relative tolerance
    assertDataFrameEqual(result, expected, atol=0.01)
```

---

## Method 4: Testing Streaming Pipelines with `processingTime` Trigger

```python
# test_streaming_pipeline.py
import pytest
import os
import json
import shutil
from pyspark.sql import SparkSession
from pyspark.sql.types import (
    StructType, StructField, StringType, IntegerType, DoubleType
)
from pyspark.sql.functions import col


@pytest.fixture(scope="session")
def spark():
    spark = (
        SparkSession.builder
        .master("local[2]")
        .appName("streaming-tests")
        .config("spark.sql.shuffle.partitions", "2")
        .config("spark.ui.enabled", "false")
        .getOrCreate()
    )
    yield spark
    spark.stop()


@pytest.fixture
def tmp_dirs(tmp_path):
    """Create temporary input/output/checkpoint directories."""
    input_dir = tmp_path / "input"
    output_dir = tmp_path / "output"
    checkpoint_dir = tmp_path / "checkpoint"
    input_dir.mkdir()
    output_dir.mkdir()
    checkpoint_dir.mkdir()
    return str(input_dir), str(output_dir), str(checkpoint_dir)


def streaming_clean_orders(input_df):
    """Streaming transformation: same logic as batch."""
    return (
        input_df
        .filter(col("status") == "completed")
        .filter(col("customer_id").isNotNull())
        .filter(col("product").isNotNull())
        .filter(col("quantity") > 0)
        .withColumn("total_amount", col("quantity") * col("unit_price"))
    )


def test_streaming_pipeline(spark, tmp_dirs):
    """
    Test a structured streaming pipeline end-to-end using
    file source, processingTime trigger, and reading the output.
    """
    input_dir, output_dir, checkpoint_dir = tmp_dirs

    schema = StructType([
        StructField("order_id", IntegerType()),
        StructField("customer_id", StringType()),
        StructField("product", StringType()),
        StructField("quantity", IntegerType()),
        StructField("unit_price", DoubleType()),
        StructField("order_date", StringType()),
        StructField("status", StringType()),
    ])

    # Write test JSON files to input directory
    test_records = [
        {"order_id": 1, "customer_id": "C01", "product": "Laptop",
         "quantity": 1, "unit_price": 999.99, "order_date": "2024-01-15",
         "status": "completed"},
        {"order_id": 2, "customer_id": "C02", "product": "Mouse",
         "quantity": -1, "unit_price": 25.0, "order_date": "2024-01-16",
         "status": "completed"},
        {"order_id": 3, "customer_id": "C03", "product": "Monitor",
         "quantity": 2, "unit_price": 300.0, "order_date": "2024-01-17",
         "status": "cancelled"},
    ]
    for i, record in enumerate(test_records):
        filepath = os.path.join(input_dir, f"batch_{i}.json")
        with open(filepath, "w") as f:
            json.dump(record, f)

    # Read streaming source
    stream_df = (
        spark.readStream
        .schema(schema)
        .json(input_dir)
    )

    # Apply the transformation
    result_stream = streaming_clean_orders(stream_df)

    # Write with processingTime trigger — process all available data, then stop
    query = (
        result_stream.writeStream
        .format("json")
        .outputMode("append")
        .option("checkpointLocation", checkpoint_dir)
        .option("path", output_dir)
        .trigger(availableNow=True)        # PySpark 3.3+: process all, then stop
        .start()
    )

    query.awaitTermination()

    # Read the output and verify
    output_df = spark.read.schema(
        StructType(schema.fields + [StructField("total_amount", DoubleType())])
    ).json(output_dir)

    assert output_df.count() == 1
    row = output_df.first()
    assert row["order_id"] == 1
    assert row["total_amount"] == 999.99


def test_streaming_with_processing_time(spark, tmp_dirs):
    """
    Alternative: use processingTime trigger for micro-batch control.
    Useful when testing watermark and late-data behavior.
    """
    input_dir, output_dir, checkpoint_dir = tmp_dirs

    schema = StructType([
        StructField("order_id", IntegerType()),
        StructField("customer_id", StringType()),
        StructField("product", StringType()),
        StructField("quantity", IntegerType()),
        StructField("unit_price", DoubleType()),
        StructField("order_date", StringType()),
        StructField("status", StringType()),
    ])

    record = {"order_id": 1, "customer_id": "C01", "product": "Laptop",
              "quantity": 1, "unit_price": 500.0, "order_date": "2024-01-15",
              "status": "completed"}
    with open(os.path.join(input_dir, "data.json"), "w") as f:
        json.dump(record, f)

    stream_df = spark.readStream.schema(schema).json(input_dir)
    result_stream = streaming_clean_orders(stream_df)

    # processingTime trigger: run one micro-batch every 0 seconds (immediate)
    query = (
        result_stream.writeStream
        .format("json")
        .outputMode("append")
        .option("checkpointLocation", checkpoint_dir)
        .option("path", output_dir)
        .trigger(processingTime="0 seconds")
        .start()
    )

    # Let one micro-batch complete, then stop
    import time
    time.sleep(10)
    query.stop()

    output_df = spark.read.json(output_dir)
    assert output_df.count() >= 1
```

---

## Recommended conftest.py for a Real Project

```python
# conftest.py — place at the root of your tests/ directory
import pytest
from pyspark.sql import SparkSession


@pytest.fixture(scope="session")
def spark():
    """
    Session-scoped SparkSession.
    - local[2]: use 2 cores (enough to catch parallelism bugs)
    - Small shuffle partitions to keep tests fast
    - Disable UI and event logging for CI speed
    - Use in-memory Derby metastore to avoid filesystem state
    """
    spark = (
        SparkSession.builder
        .master("local[2]")
        .appName("pytest-pyspark")
        .config("spark.sql.shuffle.partitions", "2")
        .config("spark.default.parallelism", "2")
        .config("spark.ui.enabled", "false")
        .config("spark.driver.bindAddress", "127.0.0.1")
        .config("spark.sql.warehouse.dir", "/tmp/spark-warehouse-test")
        .config(
            "spark.driver.extraJavaOptions",
            "-Dderby.system.home=/tmp/derby-test"
        )
        .getOrCreate()
    )
    yield spark
    spark.stop()


@pytest.fixture(autouse=True)
def cleanup_temp_views(spark):
    """Drop all temp views between tests to avoid state leakage."""
    yield
    for table in spark.catalog.listTables():
        if table.isTemporary:
            spark.catalog.dropTempView(table.name)
```

---

## Mocking External Sources

```python
# test_with_mocking.py
import pytest
from unittest.mock import patch, MagicMock
from pyspark.sql import SparkSession
from pyspark.sql.types import StructType, StructField, StringType, IntegerType


@pytest.fixture(scope="session")
def spark():
    spark = (
        SparkSession.builder
        .master("local[2]")
        .appName("mock-tests")
        .config("spark.sql.shuffle.partitions", "2")
        .config("spark.ui.enabled", "false")
        .getOrCreate()
    )
    yield spark
    spark.stop()


# Example: a pipeline function that reads from an external JDBC source
def load_and_transform(spark, jdbc_url, table_name):
    """Production code that reads from a database."""
    df = spark.read.jdbc(url=jdbc_url, table=table_name)
    return df.filter("age > 18")


def test_load_and_transform_mocked(spark):
    """
    Mock the JDBC read so the test does not need a real database.
    Replace spark.read.jdbc with a function returning a test DataFrame.
    """
    test_data = [(1, "Alice", 25), (2, "Bob", 16), (3, "Charlie", 30)]
    test_df = spark.createDataFrame(
        test_data,
        StructType([
            StructField("id", IntegerType()),
            StructField("name", StringType()),
            StructField("age", IntegerType()),
        ])
    )

    with patch.object(spark.read, "jdbc", return_value=test_df) as mock_jdbc:
        result = load_and_transform(spark, "jdbc:fake://localhost", "users")

        # Verify the mock was called with expected params
        mock_jdbc.assert_called_once_with(
            url="jdbc:fake://localhost", table="users"
        )

        # Verify transformation logic
        assert result.count() == 2
        names = [row["name"] for row in result.collect()]
        assert "Alice" in names
        assert "Charlie" in names
        assert "Bob" not in names  # age 16, filtered out
```

---

## Key Interview Talking Points

1. **"How do you test PySpark code?"**
   - Use pytest with a session-scoped SparkSession fixture. Write small deterministic input data as Python tuples, run the transformation, and compare output using `assertDataFrameEqual` or `chispa`. Never depend on external files, databases, or cluster state in unit tests.

2. **"How do you handle SparkSession in tests?"**
   - Create a single `session`-scoped fixture in `conftest.py`. Set `master("local[2]")`, reduce `shuffle.partitions` to 2, and disable the Spark UI. This cuts test startup from ~10s to ~3s and prevents port conflicts in CI. Use `yield` so the session stops after all tests complete.

3. **"How do you test streaming jobs?"**
   - Use file-based sources with `availableNow=True` (PySpark 3.3+) or `processingTime("0 seconds")` triggers. Write test JSON/Parquet to a temp directory, run the streaming query to completion, then read the output directory as a batch DataFrame and assert.

4. **"What assertion libraries do you use?"**
   - `pyspark.testing.assertDataFrameEqual` (built-in, PySpark 3.3+) for basic comparisons. `chispa` for richer features: column-level assertions, float tolerance, and color-coded diffs. For PySpark 3.5+, `assertSchemaEqual` is useful for strict schema validation.

5. **"How do you test edge cases?"**
   - Always test: empty DataFrames, all-null columns, negative/zero values, schema mismatches (extra or missing columns), single-row DataFrames, and duplicate rows. Each edge case should be its own test function with a descriptive name.

6. **"How do you mock external data sources?"**
   - Use `unittest.mock.patch` to replace `spark.read.jdbc`, `spark.read.parquet`, or any I/O call with a locally constructed test DataFrame. This isolates the transformation logic from infrastructure dependencies.

7. **"How do you handle test performance?"**
   - Session-scoped SparkSession (start once). Small shuffle partitions (2 instead of 200). Disable Spark UI. Use `local[2]` (not `local[*]`). Keep test data small (5-20 rows). Avoid `.count()` when `.first()` suffices.

8. **Common pitfalls to mention in interviews:**
   - Forgetting that DataFrames are unordered — always use `ignore_row_order=True` or sort before comparing.
   - Not testing the schema — a transformation might return correct values but wrong types (e.g., `IntegerType` vs `LongType`).
   - Creating a new SparkSession per test (extremely slow).
   - Hardcoding file paths instead of using `tmp_path` fixtures.
   - Not cleaning up temp views between tests, causing state leakage.
