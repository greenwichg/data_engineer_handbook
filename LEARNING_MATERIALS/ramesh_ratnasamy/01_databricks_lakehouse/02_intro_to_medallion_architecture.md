# Medallion Architecture in Data Lakehouse

## Introduction

Welcome back. As we saw in the last lesson, Databricks enables us to build a modern Data Lakehouse platform.

While the Data Lakehouse can be shown as a single entity in diagrams, it's more involved than that. Let's delve deeper into the data architecture within the Data Lakehouse platform.

---

## What is Medallion Architecture?

The data architecture used in the Data Lakehouse is commonly referred to as **Medallion Architecture**—a term originally coined by Databricks and now widely adopted in the industry.

### Key Points to Understand:

- **Not an architectural pattern, but a data design pattern**
- Has existed in data warehouses and data lakes for some time
- Databricks refined it within the Data Lakehouse model using a simple three-layer structure: **Bronze, Silver, and Gold**
- The term "medallion" comes from these layer names

### Data Flow and Quality

In the Medallion Architecture, data flows through these layers (Bronze → Silver → Gold), and **as data progresses through each layer, its quality improves**.

### Flexibility in Layer Count:

- **Most common**: Three layers (Bronze, Silver, Gold)
- **Extended projects**: May include a fourth "Platinum" layer
- **Simpler projects**: May have only two layers
- **Key principle**: Clearly identify and define each layer's characteristics upfront to gain maximum benefits

---

## The Three Layers

### Bronze Layer: Raw Data

The Bronze layer contains **raw data as received from various data sources**.

**Characteristics:**

- Minimal to no transformation
- May include additional metadata:
  - Load timestamp
  - Source file name
  - Other tracking information for auditing and issue identification

**Benefits:**

- Maintains historical record of all data received
- Easy to replay data if pipeline issues occur
- Supports fast ingestion of high-volume and high-velocity data

---

### Silver Layer: Cleansed and Structured Data

The Silver layer holds **filtered, cleansed, and enriched data** with structure applied and schema either enforced or evolved to maintain consistency.

**Data Processing Activities:**

- Quality checks performed
- Invalid records removed
- Column values standardized
- Duplicates eliminated
- Missing values replaced or removed
- Required context or descriptions added

**Result:**

Structured, high-quality, and reliable data suitable for:
- Data science workloads
- Machine learning
- AI applications

---

### Gold Layer: Business-Ready Data

The Gold layer contains **business-level aggregated data**.

**Characteristics:**

- Data from Silver layer is further aggregated
- Enriched with additional context
- Ready for high-level business reporting and analysis
- Used for advanced analytics and applications

---

## Benefits of Medallion Architecture

### 1. Improved Data Lineage and Traceability

Moving data through clearly defined layers (Bronze, Silver, Gold) makes it easier to:
- Track where data came from
- Understand how it's transformed
- Monitor how it's used in applications

### 2. Enhanced Data Governance and Compliance

The layered approach helps enforce compliance policies such as:
- GDPR
- CCPA
- Other regulatory requirements

Each layer has defined meaning and data granularity, which helps define:
- Retention policies
- Access controls
- Compliance requirements

### 3. Incremental Processing Support

Allows for processing only **new and changed data** received at the Data Lakehouse, which:
- Reduces computational costs
- Improves performance

### 4. Better Workload Management

The layered approach enables:
- Workload management for each layer
- Creation of scalable solutions

### 5. Enhanced Security Control

Provides better control through:
- Role-based access control (RBAC)
- Ensuring only authorized users access secure and sensitive data

**Example**: Users can be granted access to only the Gold layer if they shouldn't have access to transactional-level customer data available in Bronze and Silver layers.

---

## Summary

The Medallion Architecture provides a **flexible data design pattern** that can be adapted based on your project requirements.

By clearly defining each layer's purpose and characteristics, you can ensure:
- Data consistency
- Data quality
- Efficiency throughout your data pipeline

---

*End of lesson*