from pyspark.sql import SparkSession
from pyspark.sql.functions import col, row_number
from pyspark.sql.types import StructType, StructField, StringType, IntegerType, DoubleType, TimestampType
from pyspark.sql.window import Window

spark = SparkSession.builder.appName("S3_to_Redshift").getOrCreate()

# 1. Define schema
schema = StructType([
    StructField("order_no", StringType(), True),
    StructField("load_date", TimestampType(), True),
    StructField("oq", IntegerType(), True),
    StructField("up", DoubleType(), True)
])

# 2. Read file from S3
df1 = spark.read \
    .schema(schema) \
    .option("header", "true") \
    .csv("s3://bucket-name/path/to/file")

# 3. Remove duplicates (keep latest load_date per order_no)
windowSpec = Window.partitionBy("order_no").orderBy(col("load_date").desc())

df2 = df1.withColumn(
        "rn",
        row_number().over(windowSpec)
     ).filter(col("rn") == 1) \
      .drop("rn")

# 4. Create sales_amount column
df3 = df2.withColumn(
        "sales_amount",
        col("oq") * col("up")
     )

# 5. Load to Amazon Redshift
df3.write \
    .format("jdbc") \
    .option("url", "jdbc:redshift://host:5439/database") \
    .option("dbtable", "schema.table_name") \
    .option("user", "username") \
    .option("password", "password") \
    .mode("append") \
    .save()
