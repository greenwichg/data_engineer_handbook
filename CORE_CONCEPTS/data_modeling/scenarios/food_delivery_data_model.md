# Understanding Facts, Dimensions, and Grains in Data Modeling

## A Beginner's Guide to Dimensional Modeling

---

## Think of it Like a Receipt

Imagine you order food from a restaurant. Your receipt looks like this:

```
Order #12345
Date: Jan 12, 2024, 7:30 PM
Customer: Sanath
Restaurant: Pizza Palace
Delivered by: John (Driver #456)

Items:
- Margherita Pizza: $12.99
- Garlic Bread: $4.99
- Coke: $2.99
------------------------
Subtotal: $20.97
Delivery Fee: $3.99
Tip: $4.00
TOTAL: $28.96
Delivery Time: 28 minutes
```

Now let's break this into Facts and Dimensions:

---

## What is a FACT?

**Facts are the NUMBERS you want to analyze** - the metrics, measurements, and business events.

From the receipt above, the facts are:
- **$20.97** (subtotal)
- **$3.99** (delivery fee)  
- **$4.00** (tip)
- **$28.96** (total)
- **28 minutes** (delivery time)

### Facts answer questions like:
- How much money did we make?
- How long did delivery take?
- How many orders were placed?

**Key point**: Facts are almost always numbers that you can add, average, or count.

---

## What is a DIMENSION?

**Dimensions are the CONTEXT around those numbers** - the who, what, when, where, why.

From the receipt above, the dimensions are:
- **When**: Jan 12, 2024, 7:30 PM
- **Who** (customer): Sanath
- **What** (restaurant): Pizza Palace
- **Who** (driver): John
- **Where**: Your delivery address

### Dimensions answer questions like:
- Who placed the order?
- What restaurant was it from?
- When did it happen?
- Which driver delivered it?

**Key point**: Dimensions give you ways to slice and filter your facts.

---

## What is GRAIN?

**Grain is the LEVEL OF DETAIL you're capturing** - what does ONE ROW represent?

Let's see different grains for the same order:

### Grain #1: One row = One entire order

```
order_id | date       | customer | restaurant   | total_amount | delivery_time
12345    | 2024-01-12 | Sanath   | Pizza Palace | $28.96       | 28 min
```

### Grain #2: One row = One item in an order

```
order_id | item              | price  | quantity
12345    | Margherita Pizza  | $12.99 | 1
12345    | Garlic Bread      | $4.99  | 1
12345    | Coke              | $2.99  | 1
```

### Grain #3: One row = One delivery (multiple orders combined)

```
delivery_id | driver | orders_delivered | total_distance | total_earnings
D789        | John   | 5                | 15 km          | $45.00
```

### The grain determines what questions you can answer:
- Grain #1: "What was the total sales per day?"
- Grain #2: "Which menu items are most popular?"
- Grain #3: "How much do drivers earn per delivery route?"

**Rule: Choose ONE grain and stick to it for a fact table.**

---

## Putting It Together: A Simple Food Delivery Data Model

### FACT TABLE: Fact_Orders
(Grain: One row = One order)

```
order_id | date_key | customer_key | restaurant_key | driver_key | order_amount | delivery_fee | tip_amount | delivery_time_minutes
12345    | 20240112 | C001         | R200          | D456       | 20.97        | 3.99         | 4.00       | 28
12346    | 20240112 | C002         | R201          | D457       | 45.50        | 5.99         | 9.00       | 35
12347    | 20240112 | C001         | R200          | D456       | 18.75        | 3.99         | 3.00       | 22
```

**Notice:**
- The facts (numbers): `order_amount`, `delivery_fee`, `tip_amount`, `delivery_time_minutes`
- Foreign keys to dimensions: `customer_key`, `restaurant_key`, `driver_key`, `date_key`

---

## DIMENSION TABLES

### Dim_Customer

```
customer_key | customer_id | name   | email              | phone        | signup_date | loyalty_tier
C001         | 1001        | Sanath | sanath@email.com   | 555-1234     | 2023-05-10  | Gold
C002         | 1002        | Priya  | priya@email.com    | 555-5678     | 2023-08-15  | Silver
```

### Dim_Restaurant

```
restaurant_key | restaurant_id | name         | cuisine_type | rating | city      | neighborhood
R200           | 2001          | Pizza Palace | Italian      | 4.5    | Bengaluru | Koramangala
R201           | 2002          | Curry House  | Indian       | 4.7    | Bengaluru | Indiranagar
```

### Dim_Driver

```
driver_key | driver_id | name | vehicle_type | rating | join_date  | status
D456       | 4001      | John | Bike         | 4.8    | 2022-01-15 | Active
D457       | 4002      | Mary | Scooter      | 4.9    | 2023-03-20 | Active
```

### Dim_Date

```
date_key | full_date  | day | month | year | day_of_week | is_weekend | month_name
20240112 | 2024-01-12 | 12  | 1     | 2024 | Friday      | No         | January
20240113 | 2024-01-13 | 13  | 1     | 2024 | Saturday    | Yes        | January
```

---

## How It Works: Asking Business Questions

Let's say your boss asks: **"What's the total revenue from Italian restaurants last week?"**

```sql
SELECT 
    SUM(f.order_amount) as total_revenue
FROM Fact_Orders f
JOIN Dim_Restaurant r ON f.restaurant_key = r.restaurant_key
JOIN Dim_Date d ON f.date_key = d.date_key
WHERE r.cuisine_type = 'Italian'
    AND d.full_date BETWEEN '2024-01-05' AND '2024-01-12';
```

### What's happening:
1. Start with the fact table (the numbers)
2. Join to dimensions to filter (cuisine_type = 'Italian')
3. Join to date dimension to filter by time
4. Aggregate the facts (SUM)

---

## Why Separate Facts from Dimensions?

### Without Dimensional Modeling (All in one table):

```
order_id | date       | customer_name | customer_email | restaurant_name | restaurant_city | order_amount
12345    | 2024-01-12 | Sanath       | s@email.com    | Pizza Palace    | Bengaluru       | 20.97
12346    | 2024-01-12 | Priya        | p@email.com    | Curry House     | Bengaluru       | 45.50
12347    | 2024-01-12 | Sanath       | s@email.com    | Pizza Palace    | Bengaluru       | 18.75
```

### Problems:
- Customer name repeats (row 1 and 3) - wasted space
- If Sanath changes his email, you have to update multiple rows
- Hard to analyze customer behavior across all orders

### With Dimensional Modeling:
- Customer data stored ONCE in Dim_Customer
- Each order just references the customer with a key
- Easy to update customer info in one place
- Efficient queries for analysis

---

## Visual Summary: Star Schema

```
            ┌─────────────────┐
            │   Dim_Customer  │
            │  (Who ordered?) │
            └────────┬────────┘
                     │
         ┌───────────┼───────────┐
         │           │           │
    ┌────▼────┐ ┌───▼──────┐ ┌──▼────────┐
    │Dim_Date │ │FACT_ORDERS│ │Dim_Driver │
    │ (When?) │ │  (Numbers)│ │(Who deliv?│
    └─────────┘ └───┬──────┘ └───────────┘
                    │
            ┌───────▼──────────┐
            │  Dim_Restaurant  │
            │(Which restaurant?)│
            └──────────────────┘
```

This is called a **STAR SCHEMA** because the fact table is in the center with dimensions radiating out like a star!

---

## Complete Example: Food Delivery Data Model

### Business Requirements

Design a data model for a food delivery app that can answer:
1. What's the average order value by restaurant?
2. How long do deliveries take by region?
3. What's the customer retention rate?
4. Which restaurants generate the most revenue?

### Step 1: Identify Business Processes
- Orders
- Deliveries
- Payments
- Restaurant operations

### Step 2: Choose the Grain

**Fact_Orders grain**: One row = One order placed by a customer

### Step 3: Identify Facts (Measures)

From Fact_Orders:
- `order_amount` (dollars)
- `discount_amount` (dollars)
- `delivery_fee` (dollars)
- `tip_amount` (dollars)
- `tax_amount` (dollars)
- `preparation_time_minutes` (minutes)
- `delivery_time_minutes` (minutes)

### Step 4: Identify Dimensions (Context)

- **Dim_Customer**: Who placed the order?
- **Dim_Restaurant**: Which restaurant?
- **Dim_Driver**: Who delivered it?
- **Dim_Date**: What day?
- **Dim_Time**: What time?
- **Dim_Location**: Where was it delivered?
- **Dim_Payment_Method**: How did they pay?

### Step 5: Design Dimension Tables

#### Dim_Customer
```sql
CREATE TABLE Dim_Customer (
    customer_key INT PRIMARY KEY,           -- Surrogate key
    customer_id INT,                        -- Business key
    customer_name VARCHAR(100),
    email VARCHAR(100),
    phone VARCHAR(20),
    signup_date DATE,
    loyalty_tier VARCHAR(20),
    total_orders INT,
    total_lifetime_value DECIMAL(10,2),
    is_active BOOLEAN,
    created_date TIMESTAMP,
    updated_date TIMESTAMP
);
```

#### Dim_Restaurant
```sql
CREATE TABLE Dim_Restaurant (
    restaurant_key INT PRIMARY KEY,         -- Surrogate key
    restaurant_id INT,                      -- Business key
    restaurant_name VARCHAR(200),
    cuisine_type VARCHAR(50),
    avg_rating DECIMAL(3,2),
    total_reviews INT,
    price_range VARCHAR(20),
    city VARCHAR(100),
    neighborhood VARCHAR(100),
    latitude DECIMAL(9,6),
    longitude DECIMAL(9,6),
    is_active BOOLEAN,
    created_date TIMESTAMP,
    updated_date TIMESTAMP
);
```

#### Dim_Driver
```sql
CREATE TABLE Dim_Driver (
    driver_key INT PRIMARY KEY,             -- Surrogate key
    driver_id INT,                          -- Business key
    driver_name VARCHAR(100),
    vehicle_type VARCHAR(50),
    license_plate VARCHAR(20),
    driver_rating DECIMAL(3,2),
    join_date DATE,
    total_deliveries INT,
    status VARCHAR(20),
    created_date TIMESTAMP,
    updated_date TIMESTAMP
);
```

#### Dim_Date
```sql
CREATE TABLE Dim_Date (
    date_key INT PRIMARY KEY,               -- Format: YYYYMMDD
    full_date DATE,
    day_of_month INT,
    day_of_week INT,
    day_of_week_name VARCHAR(20),
    day_of_year INT,
    week_of_year INT,
    month INT,
    month_name VARCHAR(20),
    quarter INT,
    year INT,
    is_weekend BOOLEAN,
    is_holiday BOOLEAN,
    holiday_name VARCHAR(100)
);
```

#### Dim_Time
```sql
CREATE TABLE Dim_Time (
    time_key INT PRIMARY KEY,               -- Format: HHMMSS
    hour INT,
    minute INT,
    second INT,
    time_of_day VARCHAR(20),               -- Breakfast, Lunch, Dinner, Late Night
    is_business_hours BOOLEAN
);
```

#### Dim_Location
```sql
CREATE TABLE Dim_Location (
    location_key INT PRIMARY KEY,
    city VARCHAR(100),
    state VARCHAR(100),
    country VARCHAR(100),
    zone VARCHAR(50),
    postal_code VARCHAR(20),
    latitude DECIMAL(9,6),
    longitude DECIMAL(9,6)
);
```

### Step 6: Design Fact Table

#### Fact_Orders
```sql
CREATE TABLE Fact_Orders (
    order_id BIGINT PRIMARY KEY,
    
    -- Foreign Keys to Dimensions
    customer_key INT REFERENCES Dim_Customer(customer_key),
    restaurant_key INT REFERENCES Dim_Restaurant(restaurant_key),
    driver_key INT REFERENCES Dim_Driver(driver_key),
    date_key INT REFERENCES Dim_Date(date_key),
    time_key INT REFERENCES Dim_Time(time_key),
    delivery_location_key INT REFERENCES Dim_Location(location_key),
    
    -- Facts (Measures)
    order_amount DECIMAL(10,2),
    discount_amount DECIMAL(10,2),
    delivery_fee DECIMAL(10,2),
    tip_amount DECIMAL(10,2),
    tax_amount DECIMAL(10,2),
    total_amount DECIMAL(10,2),
    
    preparation_time_minutes INT,
    delivery_time_minutes INT,
    total_time_minutes INT,
    
    -- Degenerate Dimension (doesn't warrant its own table)
    order_status VARCHAR(20),
    payment_method VARCHAR(20),
    
    -- Audit fields
    created_timestamp TIMESTAMP,
    updated_timestamp TIMESTAMP
);
```

---

## Star Schema vs. Snowflake Schema

### Star Schema (Recommended)

```
Fact_Orders (center)
    ├── Dim_Customer (denormalized - all customer info in one table)
    ├── Dim_Restaurant (denormalized - includes city, neighborhood)
    ├── Dim_Date (denormalized)
    └── Dim_Driver (denormalized)
```

**Advantages:**
- Simpler queries (fewer joins)
- Better query performance
- Easier for BI tools to navigate
- Preferred for OLAP workloads in data warehouses

**Example Query:**
```sql
SELECT 
    r.city,
    SUM(f.order_amount) as total_revenue
FROM Fact_Orders f
JOIN Dim_Restaurant r ON f.restaurant_key = r.restaurant_key
GROUP BY r.city;
```
*Only 1 join needed!*

### Snowflake Schema

```
Fact_Orders
    └── Dim_Restaurant
            ├── Dim_Cuisine_Type
            └── Dim_Location
                    └── Dim_City
```

**When to use:**
- Storage is a concern (eliminates redundancy)
- Dimension tables are massive
- You have complex hierarchies that change independently

**Same Query with Snowflake:**
```sql
SELECT 
    c.city_name,
    SUM(f.order_amount) as total_revenue
FROM Fact_Orders f
JOIN Dim_Restaurant r ON f.restaurant_key = r.restaurant_key
JOIN Dim_Location l ON r.location_key = l.location_key
JOIN Dim_City c ON l.city_key = c.city_key
GROUP BY c.city_name;
```
*3 joins needed!*

**Recommendation**: Use star schema for analytical workloads. The storage savings from snowflaking are minimal with modern compression.

---

## Bridge Tables (Handling Many-to-Many Relationships)

### When to Use Bridge Tables

Bridge tables solve many-to-many relationships between facts and dimensions.

**Example**: One order can have multiple menu items

```
Fact_Orders (one order)
    └── Bridge_Order_Items (multiple items)
            └── Dim_Menu_Item (item details)
```

### Without Bridge Table (Wrong Approach)

```sql
-- This creates cartesian product!
SELECT 
    f.order_id,
    f.order_amount,
    m.item_name,
    m.item_price
FROM Fact_Orders f
JOIN Dim_Menu_Item m ON ??? -- No direct relationship!
```

### With Bridge Table (Correct Approach)

```sql
CREATE TABLE Bridge_Order_Items (
    order_id BIGINT REFERENCES Fact_Orders(order_id),
    menu_item_key INT REFERENCES Dim_Menu_Item(menu_item_key),
    quantity INT,
    item_price DECIMAL(10,2),
    PRIMARY KEY (order_id, menu_item_key)
);

-- Now you can query both order-level and item-level
SELECT 
    f.order_id,
    f.order_amount,
    m.item_name,
    b.quantity,
    b.item_price
FROM Fact_Orders f
JOIN Bridge_Order_Items b ON f.order_id = b.order_id
JOIN Dim_Menu_Item m ON b.menu_item_key = m.menu_item_key;
```

### Use bridge tables when:
- One order contains multiple items
- One student enrolls in multiple courses
- One movie has multiple actors
- You need to analyze at both aggregate AND detail levels

---

## Slowly Changing Dimensions (SCDs)

Dimensions change over time. How do you handle this?

### Type 1: Overwrite (No History)

**Use when**: The change is a correction or insignificant

```sql
-- Customer updates phone number
UPDATE Dim_Customer 
SET phone = '555-9999',
    updated_date = CURRENT_TIMESTAMP
WHERE customer_id = 123;
```

**Result**: Old phone number is lost forever

**Use for:**
- Typo corrections
- Phone numbers
- Email addresses
- Non-significant changes

### Type 2: Add New Row (Full History)

**Use when**: You need to track historical changes

```sql
-- Restaurant rating changes from 4.5 to 4.8
INSERT INTO Dim_Restaurant (
    restaurant_key,      -- New surrogate key
    restaurant_id,       -- Same business key
    restaurant_name,
    cuisine_type,
    avg_rating,          -- New rating
    effective_date,
    end_date,
    is_current,
    created_date
) VALUES (
    789,                 -- New key
    456,                 -- Same restaurant
    'Pizza Palace',
    'Italian',
    4.8,                 -- Updated from 4.5
    '2024-01-12',
    '9999-12-31',
    TRUE,
    CURRENT_TIMESTAMP
);

-- Mark old record as no longer current
UPDATE Dim_Restaurant
SET end_date = '2024-01-11',
    is_current = FALSE,
    updated_date = CURRENT_TIMESTAMP
WHERE restaurant_key = 788;
```

**Result**: You maintain full history

**Dim_Restaurant now looks like:**
```
restaurant_key | restaurant_id | name         | avg_rating | effective_date | end_date   | is_current
788           | 456           | Pizza Palace | 4.5        | 2023-01-01     | 2024-01-11 | FALSE
789           | 456           | Pizza Palace | 4.8        | 2024-01-12     | 9999-12-31 | TRUE
```

**Query for historical accuracy:**
```sql
-- What was the restaurant's rating when this order was placed?
SELECT 
    f.order_id,
    f.order_date,
    r.restaurant_name,
    r.avg_rating as rating_at_order_time
FROM Fact_Orders f
JOIN Dim_Restaurant r 
    ON f.restaurant_key = r.restaurant_key
    AND f.order_date BETWEEN r.effective_date AND r.end_date;
```

**Use for:**
- Price changes
- Status changes
- Rating changes
- Customer address changes
- Any attribute important for historical analysis

### Type 3: Add New Column (Limited History)

**Use when**: You only need current and previous value

```sql
ALTER TABLE Dim_Customer 
ADD COLUMN previous_loyalty_tier VARCHAR(20),
ADD COLUMN tier_change_date DATE;

-- Track only current and previous
UPDATE Dim_Customer 
SET previous_loyalty_tier = current_loyalty_tier,
    current_loyalty_tier = 'Gold',
    tier_change_date = CURRENT_DATE
WHERE customer_id = 123;
```

**Result**: You know current and previous, but nothing before that

**Use for:**
- Loyalty tier changes
- Subscription level changes
- When you only care about "before and after"

### SCD Strategy for Food Delivery

| Attribute | SCD Type | Reason |
|-----------|----------|--------|
| Customer phone | Type 1 | Not analytically significant |
| Customer email | Type 1 | Not analytically significant |
| Customer address | Type 2 | Affects delivery zones, important for analysis |
| Customer loyalty tier | Type 2 or 3 | Business decision - how much history needed? |
| Restaurant rating | Type 2 | Important for analyzing performance over time |
| Restaurant address | Type 2 | Affects delivery zones |
| Driver vehicle | Type 1 | Not significant for analysis |
| Menu item price | Type 2 | Important for revenue analysis |

---

## SQL Queries and Optimization

### Example Query 1: Top Restaurants by Revenue

```sql
SELECT 
    r.restaurant_name,
    r.cuisine_type,
    r.city,
    SUM(o.order_amount) as total_revenue,
    COUNT(DISTINCT o.order_id) as total_orders,
    AVG(o.order_amount) as avg_order_value,
    AVG(o.delivery_time_minutes) as avg_delivery_time
FROM Fact_Orders o
JOIN Dim_Restaurant r 
    ON o.restaurant_key = r.restaurant_key
JOIN Dim_Date d 
    ON o.date_key = d.date_key
WHERE d.year = 2024
    AND d.month = 1
    AND r.is_current = TRUE  -- Only current restaurant records
GROUP BY 
    r.restaurant_name, 
    r.cuisine_type, 
    r.city
ORDER BY total_revenue DESC
LIMIT 10;
```

### Example Query 2: Customer Retention Analysis

```sql
WITH customer_orders AS (
    SELECT 
        c.customer_id,
        c.customer_name,
        COUNT(o.order_id) as total_orders,
        MIN(d.full_date) as first_order_date,
        MAX(d.full_date) as last_order_date,
        DATEDIFF(day, MIN(d.full_date), MAX(d.full_date)) as customer_lifetime_days
    FROM Fact_Orders o
    JOIN Dim_Customer c ON o.customer_key = c.customer_key
    JOIN Dim_Date d ON o.date_key = d.date_key
    GROUP BY c.customer_id, c.customer_name
)
SELECT 
    CASE 
        WHEN total_orders = 1 THEN 'One-time'
        WHEN total_orders BETWEEN 2 AND 5 THEN 'Occasional'
        WHEN total_orders BETWEEN 6 AND 20 THEN 'Regular'
        ELSE 'Loyal'
    END as customer_segment,
    COUNT(*) as customer_count,
    AVG(total_orders) as avg_orders_per_customer,
    AVG(customer_lifetime_days) as avg_lifetime_days
FROM customer_orders
GROUP BY 
    CASE 
        WHEN total_orders = 1 THEN 'One-time'
        WHEN total_orders BETWEEN 2 AND 5 THEN 'Occasional'
        WHEN total_orders BETWEEN 6 AND 20 THEN 'Regular'
        ELSE 'Loyal'
    END
ORDER BY customer_count DESC;
```

### Example Query 3: Delivery Performance by Time of Day

```sql
SELECT 
    t.time_of_day,
    d.day_of_week_name,
    COUNT(o.order_id) as total_orders,
    AVG(o.delivery_time_minutes) as avg_delivery_time,
    AVG(o.order_amount) as avg_order_value,
    SUM(o.order_amount) as total_revenue
FROM Fact_Orders o
JOIN Dim_Time t ON o.time_key = t.time_key
JOIN Dim_Date d ON o.date_key = d.date_key
WHERE d.year = 2024
    AND d.month = 1
GROUP BY t.time_of_day, d.day_of_week_name
ORDER BY 
    CASE d.day_of_week_name
        WHEN 'Monday' THEN 1
        WHEN 'Tuesday' THEN 2
        WHEN 'Wednesday' THEN 3
        WHEN 'Thursday' THEN 4
        WHEN 'Friday' THEN 5
        WHEN 'Saturday' THEN 6
        WHEN 'Sunday' THEN 7
    END,
    t.time_of_day;
```

### Example Query 4: SCD Type 2 - Historical Restaurant Rating

```sql
-- Get current rating vs. rating at order time
SELECT 
    o.order_id,
    d.full_date as order_date,
    r_historical.restaurant_name,
    r_historical.avg_rating as rating_at_order_time,
    r_current.avg_rating as current_rating,
    (r_current.avg_rating - r_historical.avg_rating) as rating_change
FROM Fact_Orders o
JOIN Dim_Date d 
    ON o.date_key = d.date_key
-- Join to historical state (rating when order was placed)
JOIN Dim_Restaurant r_historical 
    ON o.restaurant_key = r_historical.restaurant_key
-- Join to current state
JOIN Dim_Restaurant r_current 
    ON r_historical.restaurant_id = r_current.restaurant_id
    AND r_current.is_current = TRUE
WHERE d.year = 2024
    AND d.month = 1
    AND r_current.avg_rating != r_historical.avg_rating
ORDER BY rating_change DESC;
```

---

## Query Optimization Strategies

### 1. Partition Pruning (Always Filter on Date)

```sql
-- BAD: Full table scan
SELECT SUM(order_amount)
FROM Fact_Orders;

-- GOOD: Uses partition pruning
SELECT SUM(order_amount)
FROM Fact_Orders o
JOIN Dim_Date d ON o.date_key = d.date_key
WHERE d.year = 2024 AND d.month = 1;
```

### 2. Select Only What You Need

```sql
-- BAD: Retrieves all columns (waste in columnar storage)
SELECT *
FROM Fact_Orders o
JOIN Dim_Restaurant r ON o.restaurant_key = r.restaurant_key;

-- GOOD: Only retrieves needed columns
SELECT 
    o.order_id,
    o.order_amount,
    r.restaurant_name
FROM Fact_Orders o
JOIN Dim_Restaurant r ON o.restaurant_key = r.restaurant_key;
```

### 3. Push Filters Down (WHERE vs HAVING)

```sql
-- BAD: Filter after aggregation
SELECT restaurant_key, SUM(order_amount) as revenue
FROM Fact_Orders
GROUP BY restaurant_key
HAVING restaurant_key = 123;

-- GOOD: Filter before aggregation
SELECT restaurant_key, SUM(order_amount) as revenue
FROM Fact_Orders
WHERE restaurant_key = 123
GROUP BY restaurant_key;
```

### 4. Redshift-Specific: Distribution Keys

```sql
-- Distribute fact table by frequently joined dimension
CREATE TABLE Fact_Orders (
    order_id BIGINT,
    customer_key INT,
    restaurant_key INT,
    order_amount DECIMAL(10,2)
)
DISTKEY(customer_key)  -- Distribute by customer for customer-centric queries
SORTKEY(date_key, restaurant_key);  -- Sort by common filter columns
```

**Distribution strategies:**
- **KEY**: Distribute based on a column (good for large tables, enables co-location)
- **ALL**: Copy entire table to all nodes (good for small dimension tables)
- **EVEN**: Round-robin distribution (use when no obvious join pattern)

### 5. Sort Keys for Query Performance

```sql
-- Sort by columns commonly used in filters and joins
CREATE TABLE Fact_Orders (
    ...
)
SORTKEY(date_key, restaurant_key);

-- Compound sort key (order matters)
-- Good for queries that filter on date_key AND restaurant_key
WHERE date_key = 20240112 AND restaurant_key = 789;

-- Interleaved sort key (all columns weighted equally)
INTERLEAVED SORTKEY(date_key, customer_key, restaurant_key);
-- Good when you filter on different columns in different queries
```

### 6. Regular Maintenance

```sql
-- Update statistics for query planner
ANALYZE Fact_Orders;

-- Reclaim space and resort
VACUUM SORT ONLY Fact_Orders;

-- Check table statistics
SELECT * FROM SVV_TABLE_INFO WHERE "table" = 'fact_orders';
```

### 7. Use EXPLAIN to Understand Query Plans

```sql
EXPLAIN 
SELECT 
    r.restaurant_name,
    SUM(o.order_amount) as revenue
FROM Fact_Orders o
JOIN Dim_Restaurant r ON o.restaurant_key = r.restaurant_key
WHERE o.date_key >= 20240101
GROUP BY r.restaurant_name;

-- Look for:
-- - Seq Scan vs Index Scan
-- - Hash Join vs Merge Join vs Nested Loop
-- - Disk-based operations (should be in-memory)
```

---

## Practice Exercise: Ride-Hailing App

Now it's your turn! Try designing a data model for a ride-hailing app.

### Scenario
A rider books a trip from home to work. The driver picks them up, drives them to their destination, and the rider pays.

### Your Task
Identify:

1. **Facts (Numbers to measure)**
   - What metrics would you track?
   - Think: money, time, distance

2. **Dimensions (Context)**
   - Who is involved?
   - When did it happen?
   - Where did it happen?
   - What other context is important?

3. **Grain (What does one row represent?)**
   - One complete trip?
   - One pickup/dropoff event?
   - One mile driven?

### Suggested Fact Table: Fact_Rides

**Grain**: One row = One completed ride

**Facts (Measures)**:
- ride_amount (fare)
- tip_amount
- surge_multiplier
- distance_miles
- duration_minutes
- driver_earnings
- company_commission

**Dimensions**:
- Dim_Rider (who took the ride?)
- Dim_Driver (who drove?)
- Dim_Vehicle (what car?)
- Dim_Date (what day?)
- Dim_Time (what time?)
- Dim_Pickup_Location (where did it start?)
- Dim_Dropoff_Location (where did it end?)
- Dim_Ride_Type (standard, premium, shared?)

### Sample Schema

```sql
CREATE TABLE Fact_Rides (
    ride_id BIGINT PRIMARY KEY,
    
    -- Dimension Keys
    rider_key INT,
    driver_key INT,
    vehicle_key INT,
    date_key INT,
    time_key INT,
    pickup_location_key INT,
    dropoff_location_key INT,
    ride_type_key INT,
    
    -- Facts
    ride_amount DECIMAL(10,2),
    tip_amount DECIMAL(10,2),
    surge_multiplier DECIMAL(4,2),
    distance_miles DECIMAL(10,2),
    duration_minutes INT,
    driver_earnings DECIMAL(10,2),
    company_commission DECIMAL(10,2),
    
    -- Status
    ride_status VARCHAR(20),
    
    -- Timestamps
    created_timestamp TIMESTAMP
);
```

---

## Key Takeaways

1. **Facts** = Numbers you want to analyze (revenue, quantity, time, distance)

2. **Dimensions** = Context around those numbers (who, what, when, where, why)

3. **Grain** = Level of detail (what does ONE ROW represent?)

4. **Star Schema** = Fact table at center, dimensions radiating out (best for analytics)

5. **Bridge Tables** = Handle many-to-many relationships

6. **SCD Type 2** = Track historical changes by adding new rows with date ranges

7. **Always filter on date** = Essential for partition pruning and performance

8. **Distribution & Sort Keys** = Critical for Redshift query performance

---

## Additional Resources

- **Kimball's Data Warehouse Toolkit**: The bible of dimensional modeling
- **Redshift Documentation**: Best practices for distribution and sort keys
- **Practice**: Design models for different domains (e-commerce, healthcare, finance)

---

## Quick Reference: Design Checklist

When designing a dimensional model:

- [ ] Define business questions to answer
- [ ] Choose the grain (be very specific!)
- [ ] Identify facts (numeric measures)
- [ ] Identify dimensions (context)
- [ ] Decide on star vs snowflake (prefer star)
- [ ] Handle many-to-many with bridge tables
- [ ] Choose SCD type for each dimension attribute
- [ ] Design for query patterns (distribution/sort keys)
- [ ] Plan for data volume and growth
- [ ] Document everything!

---

Good luck with your interview! Remember: the grain is the single most important design decision. Get that right, and everything else follows.