I'll provide a comprehensive solution for reading and transforming mixed-format data (CSV, Parquet, and JSON) in PySpark.

## Problem Understanding

**Scenario:** You have data from multiple sources in different formats:
- **CSV**: Legacy system exports, Excel dumps
- **Parquet**: Data lake storage, optimized analytics
- **JSON**: API responses, log files, semi-structured data

**Challenges:**
- Different schemas (column names, types)
- Format-specific issues (CSV headers, JSON nesting, Parquet compression)
- Schema evolution
- Data quality varies by format
- Performance optimization per format

## Solution 1: Basic Multi-Format Reading

```python
from pyspark.sql import SparkSession
from pyspark.sql.functions import *
from pyspark.sql.types import *

spark = SparkSession.builder \
    .appName("Mixed_Format_Processing") \
    .getOrCreate()

# ==========================================
# READ CSV FILES
# ==========================================

csv_df = spark.read \
    .format("csv") \
    .option("header", "true") \
    .option("inferSchema", "true") \
    .option("delimiter", ",") \
    .option("quote", '"') \
    .option("escape", '"') \
    .option("multiLine", "true") \
    .option("dateFormat", "yyyy-MM-dd") \
    .option("timestampFormat", "yyyy-MM-dd HH:mm:ss") \
    .load("data/csv/*.csv")

print("CSV Data:")
csv_df.printSchema()
csv_df.show(5)

# ==========================================
# READ PARQUET FILES
# ==========================================

parquet_df = spark.read \
    .format("parquet") \
    .load("data/parquet/*.parquet")

print("\nParquet Data:")
parquet_df.printSchema()
parquet_df.show(5)

# ==========================================
# READ JSON FILES
# ==========================================

json_df = spark.read \
    .format("json") \
    .option("multiLine", "true") \
    .option("mode", "PERMISSIVE") \
    .option("columnNameOfCorruptRecord", "_corrupt_record") \
    .load("data/json/*.json")

print("\nJSON Data:")
json_df.printSchema()
json_df.show(5)

# ==========================================
# UNIFY SCHEMAS AND COMBINE
# ==========================================

# Assume all have common columns: id, name, value, date
from pyspark.sql.functions import lit

# Standardize column names and add source tag
csv_normalized = csv_df \
    .select("id", "name", "value", "date") \
    .withColumn("source", lit("CSV"))

parquet_normalized = parquet_df \
    .select("id", "name", "value", "date") \
    .withColumn("source", lit("PARQUET"))

json_normalized = json_df \
    .select("id", "name", "value", "date") \
    .withColumn("source", lit("JSON"))

# Union all formats
unified_df = csv_normalized \
    .union(parquet_normalized) \
    .union(json_normalized)

print("\nUnified Data:")
unified_df.show()
```

## Solution 2: Production-Ready Multi-Format Reader

```python
from pyspark.sql import SparkSession, DataFrame
from pyspark.sql.functions import *
from pyspark.sql.types import *
from typing import Dict, List, Optional
import logging

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# ==========================================
# MULTI-FORMAT DATA READER
# ==========================================

class MultiFormatReader:
    """
    Production-grade reader for mixed-format data
    """
    
    def __init__(self, spark: SparkSession):
        self.spark = spark
        self.readers = {
            'csv': self._read_csv,
            'parquet': self._read_parquet,
            'json': self._read_json
        }
    
    def _read_csv(self, path: str, options: Dict) -> DataFrame:
        """
        Read CSV with comprehensive options
        """
        logger.info(f"Reading CSV from: {path}")
        
        default_options = {
            "header": "true",
            "inferSchema": "true",
            "delimiter": ",",
            "quote": '"',
            "escape": '"',
            "multiLine": "true",
            "ignoreLeadingWhiteSpace": "true",
            "ignoreTrailingWhiteSpace": "true",
            "nullValue": "",
            "emptyValue": "",
            "dateFormat": "yyyy-MM-dd",
            "timestampFormat": "yyyy-MM-dd HH:mm:ss",
            "mode": "PERMISSIVE",
            "columnNameOfCorruptRecord": "_corrupt_record"
        }
        
        # Merge with custom options
        read_options = {**default_options, **options}
        
        # Use explicit schema if provided
        if 'schema' in options:
            df = self.spark.read \
                .schema(options['schema']) \
                .csv(path, **{k: v for k, v in read_options.items() if k != 'schema'})
        else:
            df = self.spark.read \
                .options(**read_options) \
                .csv(path)
        
        # Remove corrupt records if any
        if "_corrupt_record" in df.columns:
            corrupt_count = df.filter(col("_corrupt_record").isNotNull()).count()
            if corrupt_count > 0:
                logger.warning(f"Found {corrupt_count} corrupt CSV records")
            df = df.filter(col("_corrupt_record").isNull()).drop("_corrupt_record")
        
        record_count = df.count()
        logger.info(f"Read {record_count:,} records from CSV")
        
        return df
    
    def _read_parquet(self, path: str, options: Dict) -> DataFrame:
        """
        Read Parquet files
        """
        logger.info(f"Reading Parquet from: {path}")
        
        default_options = {
            "mergeSchema": "false"
        }
        
        read_options = {**default_options, **options}
        
        df = self.spark.read \
            .options(**read_options) \
            .parquet(path)
        
        record_count = df.count()
        logger.info(f"Read {record_count:,} records from Parquet")
        
        return df
    
    def _read_json(self, path: str, options: Dict) -> DataFrame:
        """
        Read JSON files
        """
        logger.info(f"Reading JSON from: {path}")
        
        default_options = {
            "multiLine": "true",
            "mode": "PERMISSIVE",
            "columnNameOfCorruptRecord": "_corrupt_record",
            "primitivesAsString": "false",
            "allowComments": "true",
            "allowUnquotedFieldNames": "false",
            "allowSingleQuotes": "true",
            "allowNumericLeadingZeros": "false",
            "allowBackslashEscapingAnyCharacter": "false"
        }
        
        read_options = {**default_options, **options}
        
        # Use explicit schema if provided
        if 'schema' in options:
            df = self.spark.read \
                .schema(options['schema']) \
                .json(path, **{k: v for k, v in read_options.items() if k != 'schema'})
        else:
            df = self.spark.read \
                .options(**read_options) \
                .json(path)
        
        # Handle corrupt records
        if "_corrupt_record" in df.columns:
            corrupt_count = df.filter(col("_corrupt_record").isNotNull()).count()
            if corrupt_count > 0:
                logger.warning(f"Found {corrupt_count} corrupt JSON records")
            df = df.filter(col("_corrupt_record").isNull()).drop("_corrupt_record")
        
        record_count = df.count()
        logger.info(f"Read {record_count:,} records from JSON")
        
        return df
    
    def read(
        self,
        format_type: str,
        path: str,
        options: Dict = None
    ) -> DataFrame:
        """
        Read data from specified format
        
        Args:
            format_type: 'csv', 'parquet', or 'json'
            path: File path or directory
            options: Format-specific options
        """
        if format_type not in self.readers:
            raise ValueError(f"Unsupported format: {format_type}")
        
        options = options or {}
        reader_func = self.readers[format_type]
        
        try:
            df = reader_func(path, options)
            return df
        except Exception as e:
            logger.error(f"Failed to read {format_type} from {path}: {e}")
            raise
    
    def read_multiple(
        self,
        sources: List[Dict]
    ) -> Dict[str, DataFrame]:
        """
        Read from multiple sources
        
        Args:
            sources: List of source configs
                [
                    {'name': 'sales_csv', 'format': 'csv', 'path': '...', 'options': {}},
                    {'name': 'products_parquet', 'format': 'parquet', 'path': '...'}
                ]
        
        Returns:
            Dictionary of DataFrames keyed by source name
        """
        dataframes = {}
        
        for source in sources:
            name = source['name']
            format_type = source['format']
            path = source['path']
            options = source.get('options', {})
            
            logger.info(f"Reading source: {name}")
            
            try:
                df = self.read(format_type, path, options)
                dataframes[name] = df
            except Exception as e:
                logger.error(f"Failed to read source {name}: {e}")
                # Continue with other sources or raise based on requirements
                if source.get('required', True):
                    raise
        
        return dataframes

# ==========================================
# SCHEMA UNIFIER
# ==========================================

class SchemaUnifier:
    """
    Unify schemas across different formats
    """
    
    @staticmethod
    def align_schemas(
        dataframes: Dict[str, DataFrame],
        target_schema: StructType
    ) -> Dict[str, DataFrame]:
        """
        Align all DataFrames to target schema
        
        Args:
            dataframes: Dictionary of DataFrames
            target_schema: Target schema to align to
        """
        aligned = {}
        
        for name, df in dataframes.items():
            logger.info(f"Aligning schema for: {name}")
            
            aligned_df = df
            
            # Add missing columns with null
            for field in target_schema.fields:
                if field.name not in df.columns:
                    logger.info(f"  Adding missing column: {field.name}")
                    aligned_df = aligned_df.withColumn(field.name, lit(None).cast(field.dataType))
            
            # Remove extra columns
            extra_cols = set(aligned_df.columns) - set([f.name for f in target_schema.fields])
            if extra_cols:
                logger.info(f"  Removing extra columns: {extra_cols}")
                aligned_df = aligned_df.drop(*extra_cols)
            
            # Reorder and cast columns
            select_exprs = []
            for field in target_schema.fields:
                if field.name in aligned_df.columns:
                    select_exprs.append(col(field.name).cast(field.dataType).alias(field.name))
            
            aligned_df = aligned_df.select(*select_exprs)
            
            aligned[name] = aligned_df
        
        return aligned
    
    @staticmethod
    def infer_unified_schema(dataframes: Dict[str, DataFrame]) -> StructType:
        """
        Infer unified schema from multiple DataFrames
        """
        all_fields = {}
        
        # Collect all fields
        for name, df in dataframes.items():
            for field in df.schema.fields:
                if field.name not in all_fields:
                    all_fields[field.name] = field
                else:
                    # Resolve type conflicts (prefer wider types)
                    existing_type = str(all_fields[field.name].dataType)
                    new_type = str(field.dataType)
                    
                    if existing_type != new_type:
                        logger.warning(f"Type conflict for {field.name}: {existing_type} vs {new_type}")
                        # Use StringType as fallback
                        all_fields[field.name] = StructField(field.name, StringType(), True)
        
        unified_schema = StructType(list(all_fields.values()))
        logger.info(f"Unified schema has {len(unified_schema.fields)} fields")
        
        return unified_schema

# ==========================================
# USAGE EXAMPLE
# ==========================================

# Initialize
spark = SparkSession.builder \
    .appName("MultiFormat_Production") \
    .getOrCreate()

reader = MultiFormatReader(spark)
unifier = SchemaUnifier()

# Define sources
sources = [
    {
        'name': 'sales_csv',
        'format': 'csv',
        'path': 'data/sales/*.csv',
        'options': {
            'delimiter': ',',
            'header': 'true'
        }
    },
    {
        'name': 'inventory_parquet',
        'format': 'parquet',
        'path': 'data/inventory/*.parquet',
        'options': {
            'mergeSchema': 'true'
        }
    },
    {
        'name': 'events_json',
        'format': 'json',
        'path': 'data/events/*.json',
        'options': {
            'multiLine': 'true'
        }
    }
]

# Read all sources
dataframes = reader.read_multiple(sources)

# Show what we read
for name, df in dataframes.items():
    print(f"\n{name}:")
    df.printSchema()
    print(f"Record count: {df.count():,}")

# Infer unified schema
unified_schema = unifier.infer_unified_schema(dataframes)

print("\nUnified Schema:")
unified_schema.printTreeString()

# Align all DataFrames to unified schema
aligned_dfs = unifier.align_schemas(dataframes, unified_schema)

# Combine all sources
combined_df = None
for name, df in aligned_dfs.items():
    df_with_source = df.withColumn("data_source", lit(name))
    
    if combined_df is None:
        combined_df = df_with_source
    else:
        combined_df = combined_df.union(df_with_source)

print("\nCombined Data:")
combined_df.show()

# Save unified result
combined_df.write \
    .mode("overwrite") \
    .partitionBy("data_source") \
    .parquet("output/unified_data")
```

## Solution 3: Format-Specific Error Handling

```python
from pyspark.sql import SparkSession
from pyspark.sql.functions import *
from pyspark.sql.types import *
import logging

logger = logging.getLogger(__name__)

# ==========================================
# ERROR HANDLING FOR EACH FORMAT
# ==========================================

class RobustMultiFormatReader:
    """
    Read mixed formats with robust error handling
    """
    
    def __init__(self, spark: SparkSession):
        self.spark = spark
    
    def read_csv_with_errors(self, path: str):
        """
        Read CSV and separate good/bad records
        """
        logger.info(f"Reading CSV with error handling: {path}")
        
        # Read with permissive mode
        df = self.spark.read \
            .option("header", "true") \
            .option("mode", "PERMISSIVE") \
            .option("columnNameOfCorruptRecord", "_corrupt_record") \
            .csv(path)
        
        # Separate good and bad records
        good_records = df.filter(col("_corrupt_record").isNull()).drop("_corrupt_record")
        bad_records = df.filter(col("_corrupt_record").isNotNull())
        
        bad_count = bad_records.count()
        if bad_count > 0:
            logger.warning(f"Found {bad_count} corrupt CSV records")
            
            # Save bad records for investigation
            bad_records.write \
                .mode("append") \
                .json("errors/csv_corrupt_records")
        
        logger.info(f"Successfully read {good_records.count():,} CSV records")
        
        return good_records
    
    def read_parquet_with_schema_evolution(self, paths: List[str]):
        """
        Read multiple Parquet files with schema evolution
        """
        logger.info("Reading Parquet files with schema merging")
        
        # Option 1: Let Spark merge schemas automatically
        df = self.spark.read \
            .option("mergeSchema", "true") \
            .parquet(*paths)
        
        logger.info(f"Merged schema has {len(df.columns)} columns")
        
        return df
        
        # Option 2: Manual schema merging (more control)
        # dfs = []
        # for path in paths:
        #     df = self.spark.read.parquet(path)
        #     dfs.append(df)
        # 
        # # Find all unique columns
        # all_columns = set()
        # for df in dfs:
        #     all_columns.update(df.columns)
        # 
        # # Add missing columns to each DataFrame
        # aligned_dfs = []
        # for df in dfs:
        #     for col_name in all_columns:
        #         if col_name not in df.columns:
        #             df = df.withColumn(col_name, lit(None))
        #     aligned_dfs.append(df)
        # 
        # # Union all
        # result = aligned_dfs[0]
        # for df in aligned_dfs[1:]:
        #     result = result.union(df)
        # 
        # return result
    
    def read_json_with_nested_handling(self, path: str):
        """
        Read JSON and handle nested structures
        """
        logger.info(f"Reading JSON with nested structure handling: {path}")
        
        # First pass: Read with schema inference
        df = self.spark.read \
            .option("multiLine", "true") \
            .option("mode", "PERMISSIVE") \
            .json(path)
        
        logger.info("Original JSON schema:")
        df.printSchema()
        
        # Flatten nested structures
        flattened_df = self._flatten_json(df)
        
        logger.info("Flattened JSON schema:")
        flattened_df.printSchema()
        
        return flattened_df
    
    def _flatten_json(self, df: DataFrame, prefix: str = "") -> DataFrame:
        """
        Recursively flatten nested JSON structures
        """
        flat_cols = []
        
        for field in df.schema.fields:
            col_name = field.name
            col_type = field.dataType
            
            if isinstance(col_type, StructType):
                # Flatten struct
                nested_df = df.select(f"{col_name}.*")
                for nested_field in col_type.fields:
                    flat_cols.append(
                        col(f"{col_name}.{nested_field.name}").alias(f"{prefix}{col_name}_{nested_field.name}")
                    )
            elif isinstance(col_type, ArrayType):
                # Keep arrays as-is or explode based on requirements
                flat_cols.append(col(col_name).alias(f"{prefix}{col_name}"))
            else:
                # Regular column
                flat_cols.append(col(col_name).alias(f"{prefix}{col_name}"))
        
        return df.select(*flat_cols)

# ==========================================
# USAGE
# ==========================================

spark = SparkSession.builder \
    .appName("Robust_MultiFormat") \
    .getOrCreate()

reader = RobustMultiFormatReader(spark)

# Read with error handling
csv_df = reader.read_csv_with_errors("data/sales/*.csv")
parquet_df = reader.read_parquet_with_schema_evolution([
    "data/inventory/2024/*.parquet",
    "data/inventory/2025/*.parquet"
])
json_df = reader.read_json_with_nested_handling("data/events/*.json")

print("Successfully read all formats!")
```

## Solution 4: Performance-Optimized Reading

```python
from pyspark.sql import SparkSession
from pyspark.sql.functions import *
import logging

logger = logging.getLogger(__name__)

# ==========================================
# PERFORMANCE-OPTIMIZED CONFIGURATION
# ==========================================

spark = SparkSession.builder \
    .appName("Optimized_MultiFormat") \
    .config("spark.sql.files.maxPartitionBytes", "134217728")  # 128 MB \
    .config("spark.sql.adaptive.enabled", "true") \
    .config("spark.sql.adaptive.coalescePartitions.enabled", "true") \
    .config("spark.sql.parquet.compression.codec", "snappy") \
    .config("spark.sql.parquet.mergeSchema", "false") \
    .config("spark.sql.parquet.filterPushdown", "true") \
    .config("spark.sql.json.compression.codec", "gzip") \
    .getOrCreate()

# ==========================================
# OPTIMIZED CSV READING
# ==========================================

def read_csv_optimized(path: str):
    """
    Read CSV with performance optimizations
    """
    # Define explicit schema (faster than inferSchema)
    schema = StructType([
        StructField("id", IntegerType(), True),
        StructField("name", StringType(), True),
        StructField("value", DoubleType(), True),
        StructField("date", DateType(), True)
    ])
    
    df = spark.read \
        .schema(schema) \
        .option("header", "true") \
        .option("mode", "DROPMALFORMED") \  # Drop bad rows for speed
        .csv(path)
    
    # Repartition for better parallelism
    df = df.repartition(10)
    
    return df

# ==========================================
# OPTIMIZED PARQUET READING
# ==========================================

def read_parquet_optimized(path: str):
    """
    Read Parquet with predicate pushdown
    """
    # Use predicate pushdown for filtering
    df = spark.read \
        .parquet(path) \
        .filter(col("date") >= "2025-01-01")  # Filter pushed to file scan
    
    # Select only needed columns (column pruning)
    df = df.select("id", "name", "value", "date")
    
    return df

# ==========================================
# OPTIMIZED JSON READING
# ==========================================

def read_json_optimized(path: str):
    """
    Read JSON with explicit schema
    """
    # Explicit schema avoids expensive inference
    schema = StructType([
        StructField("id", IntegerType()),
        StructField("name", StringType()),
        StructField("value", DoubleType()),
        StructField("timestamp", TimestampType())
    ])
    
    df = spark.read \
        .schema(schema) \
        .json(path)
    
    return df

# ==========================================
# PARALLEL READING
# ==========================================

from concurrent.futures import ThreadPoolExecutor
from typing import Dict

def read_all_formats_parallel(paths: Dict[str, str]) -> Dict[str, DataFrame]:
    """
    Read all formats in parallel for faster loading
    """
    results = {}
    
    def read_csv_task():
        return ('csv', read_csv_optimized(paths['csv']))
    
    def read_parquet_task():
        return ('parquet', read_parquet_optimized(paths['parquet']))
    
    def read_json_task():
        return ('json', read_json_optimized(paths['json']))
    
    # Execute reads in parallel
    with ThreadPoolExecutor(max_workers=3) as executor:
        futures = [
            executor.submit(read_csv_task),
            executor.submit(read_parquet_task),
            executor.submit(read_json_task)
        ]
        
        for future in futures:
            format_type, df = future.result()
            results[format_type] = df
            logger.info(f"Loaded {format_type}: {df.count():,} records")
    
    return results

# Usage
paths = {
    'csv': 'data/csv/*.csv',
    'parquet': 'data/parquet/*.parquet',
    'json': 'data/json/*.json'
}

dataframes = read_all_formats_parallel(paths)
```

## Solution 5: Complete End-to-End Pipeline

```python
#!/usr/bin/env python3
"""
Complete Mixed-Format Data Processing Pipeline
Reads CSV, Parquet, and JSON, unifies schemas, and processes
"""

from pyspark.sql import SparkSession, DataFrame
from pyspark.sql.functions import *
from pyspark.sql.types import *
from typing import Dict, List
import logging
import sys

logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
    stream=sys.stdout
)
logger = logging.getLogger(__name__)

# ==========================================
# COMPLETE PIPELINE CLASS
# ==========================================

class MixedFormatPipeline:
    """
    Complete pipeline for mixed-format data processing
    """
    
    def __init__(self, spark: SparkSession):
        self.spark = spark
        self.source_dfs = {}
    
    def load_data(self, sources: Dict[str, Dict]):
        """
        Load data from multiple formats
        
        Args:
            sources: {
                'csv_sales': {'format': 'csv', 'path': '...', 'options': {}},
                'parquet_inventory': {'format': 'parquet', 'path': '...'},
                'json_events': {'format': 'json', 'path': '...'}
            }
        """
        logger.info("="*60)
        logger.info("LOADING DATA FROM MULTIPLE FORMATS")
        logger.info("="*60)
        
        for name, config in sources.items():
            format_type = config['format']
            path = config['path']
            options = config.get('options', {})
            
            logger.info(f"\nLoading {name} ({format_type})...")
            
            try:
                if format_type == 'csv':
                    df = self._read_csv(path, options)
                elif format_type == 'parquet':
                    df = self._read_parquet(path, options)
                elif format_type == 'json':
                    df = self._read_json(path, options)
                else:
                    raise ValueError(f"Unsupported format: {format_type}")
                
                # Add source metadata
                df = df.withColumn("_source_name", lit(name)) \
                       .withColumn("_source_format", lit(format_type)) \
                       .withColumn("_load_timestamp", current_timestamp())
                
                self.source_dfs[name] = df
                
                logger.info(f"  ✓ Loaded {df.count():,} records")
                
            except Exception as e:
                logger.error(f"  ✗ Failed to load {name}: {e}")
                raise
    
    def _read_csv(self, path: str, options: Dict) -> DataFrame:
        """Read CSV files"""
        default_opts = {
            "header": "true",
            "inferSchema": "true",
            "mode": "PERMISSIVE"
        }
        return self.spark.read.options(**{**default_opts, **options}).csv(path)
    
    def _read_parquet(self, path: str, options: Dict) -> DataFrame:
        """Read Parquet files"""
        default_opts = {
            "mergeSchema": "false"
        }
        return self.spark.read.options(**{**default_opts, **options}).parquet(path)
    
    def _read_json(self, path: str, options: Dict) -> DataFrame:
        """Read JSON files"""
        default_opts = {
            "multiLine": "true",
            "mode": "PERMISSIVE"
        }
        return self.spark.read.options(**{**default_opts, **options}).json(path)
    
    def unify_schemas(self, target_columns: List[str]):
        """
        Unify schemas across all source DataFrames
        
        Args:
            target_columns: List of column names to keep
        """
        logger.info("\n" + "="*60)
        logger.info("UNIFYING SCHEMAS")
        logger.info("="*60)
        
        unified_dfs = {}
        
        for name, df in self.source_dfs.items():
            logger.info(f"\nProcessing {name}...")
            
            # Add missing columns
            for col_name in target_columns:
                if col_name not in df.columns:
                    logger.info(f"  Adding missing column: {col_name}")
                    df = df.withColumn(col_name, lit(None))
            
            # Select only target columns (plus metadata)
            metadata_cols = ["_source_name", "_source_format", "_load_timestamp"]
            select_cols = target_columns + metadata_cols
            
            df = df.select(*[col(c) for c in select_cols if c in df.columns])
            
            unified_dfs[name] = df
            logger.info(f"  ✓ Schema unified")
        
        self.source_dfs = unified_dfs
    
    def combine_data(self) -> DataFrame:
        """
        Combine all sources into single DataFrame
        """
        logger.info("\n" + "="*60)
        logger.info("COMBINING DATA")
        logger.info("="*60)
        
        combined = None
        
        for name, df in self.source_dfs.items():
            if combined is None:
                combined = df
            else:
                combined = combined.union(df)
            
            logger.info(f"  Added {name}")
        
        total_records = combined.count()
        logger.info(f"\n✓ Combined total: {total_records:,} records")
        
        return combined
    
    def transform(self, df: DataFrame) -> DataFrame:
        """
        Apply business transformations
        """
        logger.info("\n" + "="*60)
        logger.info("APPLYING TRANSFORMATIONS")
        logger.info("="*60)
        
        # Example transformations
        df_transformed = df \
            .filter(col("id").isNotNull()) \
            .withColumn("value_normalized", col("value") / 100) \
            .withColumn("processing_date", current_date())
        
        logger.info("✓ Transformations applied")
        
        return df_transformed
    
    def write_output(self, df: DataFrame, output_path: str, format_type: str = "parquet"):
        """
        Write unified and transformed data
        """
        logger.info("\n" + "="*60)
        logger.info("WRITING OUTPUT")
        logger.info("="*60)
        
        df.write \
            .mode("overwrite") \
            .partitionBy("_source_format", "processing_date") \
            .format(format_type) \
            .save(output_path)
        
        logger.info(f"✓ Output written to: {output_path}")
    
    def run(
        self,
        sources: Dict,
        target_columns: List[str],
        output_path: str
    ):
        """
        Execute complete pipeline
        """
        logger.info("\n" + "="*60)
        logger.info("STARTING MIXED-FORMAT PROCESSING PIPELINE")
        logger.info("="*60)
        
        try:
            # 1. Load all sources
            self.load_data(sources)
            
            # 2. Unify schemas
            self.unify_schemas(target_columns)
            
            # 3. Combine data
            combined_df = self.combine_data()
            
            # 4. Transform
            transformed_df = self.transform(combined_df)
            
            # 5. Write output
            self.write_output(transformed_df, output_path)
            
            logger.info("\n" + "="*60)
            logger.info("✓ PIPELINE COMPLETED SUCCESSFULLY")
            logger.info("="*60)
            
        except Exception as e:
            logger.error(f"\n✗ PIPELINE FAILED: {e}", exc_info=True)
            raise

# ==========================================
# MAIN EXECUTION
# ==========================================

def main():
    # Initialize Spark
    spark = SparkSession.builder \
        .appName("MixedFormat_Pipeline") \
        .config("spark.sql.adaptive.enabled", "true") \
        .getOrCreate()
    
    # Define sources
    sources = {
        'sales_csv': {
            'format': 'csv',
            'path': 'data/sales/*.csv',
            'options': {
                'header': 'true',
                'inferSchema': 'true'
            }
        },
        'inventory_parquet': {
            'format': 'parquet',
            'path': 'data/inventory/*.parquet'
        },
        'events_json': {
            'format': 'json',
            'path': 'data/events/*.json',
            'options': {
                'multiLine': 'true'
            }
        }
    }
    
    # Define target schema (common columns across all sources)
    target_columns = ['id', 'name', 'value', 'date', 'category']
    
    # Run pipeline
    pipeline = MixedFormatPipeline(spark)
    pipeline.run(
        sources=sources,
        target_columns=target_columns,
        output_path='output/unified_data'
    )
    
    spark.stop()

if __name__ == "__main__":
    main()
```

## Key Takeaways:

**Format-Specific Considerations:**

**CSV:**
- ✅ Use `inferSchema=true` or explicit schema
- ✅ Handle headers, delimiters, quotes properly
- ✅ Set `mode=PERMISSIVE` for error handling
- ⚠️ Slowest format for large files
- ⚠️ No schema enforcement

**Parquet:**
- ✅ Fast, columnar, compressed
- ✅ Schema embedded in files
- ✅ Supports predicate pushdown
- ✅ Use `mergeSchema` for schema evolution
- ⚠️ Binary format (not human-readable)

**JSON:**
- ✅ Flexible, semi-structured
- ✅ Supports nested data
- ✅ Use `multiLine=true` for pretty-printed JSON
- ⚠️ Slower than Parquet
- ⚠️ Schema inference can be expensive

**Best Practices:**
1. **Explicit schemas** > schema inference (performance)
2. **Cache** reference data after reading
3. **Unify schemas** before combining
4. **Add source metadata** for traceability
5. **Handle errors** per format
6. **Optimize** file sizes (128-256 MB)
7. **Partition** output data appropriately

**Performance Tips:**
- Read Parquet when possible (fastest)
- Use explicit schemas (avoid inference)
- Enable adaptive query execution
- Coalesce/repartition after reading
- Use predicate pushdown for Parquet
- Filter early in pipeline

This comprehensive solution covers reading, unifying, and processing mixed-format data in PySpark!