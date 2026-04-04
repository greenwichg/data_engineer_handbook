# Practice Exercise: Ride-Hailing App Data Model

## The Scenario

A ride-hailing app (like Uber or Ola) operates as follows:

1. A **rider** opens the app and books a trip from their home to their office
2. The app assigns a **driver** who accepts the ride
3. The driver picks up the rider at the **pickup location**
4. The driver drives the rider to their **destination**
5. The rider pays for the trip (base fare + distance + time + surge pricing)
6. The rider can rate the driver and leave a tip

---

## Your Task

Before looking at the solution below, try to answer these questions:

### Question 1: What are the FACTS?
Think about the **numbers** that the business would want to measure and analyze.

**Hints:**
- What metrics involve money?
- What metrics involve time?
- What metrics involve distance?
- What other numeric measurements matter?

---

### Question 2: What are the DIMENSIONS?
Think about the **context** needed to slice and dice those facts.

**Hints:**
- **Who** is involved in this transaction?
- **When** did this happen?
- **Where** did this happen?
- **What** type of ride was it?
- **How** was payment made?

---

### Question 3: What is the GRAIN?
What does **ONE ROW** in your fact table represent?

**Think about these options:**
- One complete ride (from pickup to dropoff)?
- One mile driven?
- One minute of the trip?
- One pickup event?
- One payment transaction?

**Which one makes the most business sense?**

---

## Take a moment to write down your answers before scrolling down!

-------------

## Solution

### GRAIN Definition

**Fact_Rides Grain**: One row = One completed ride from pickup to dropoff

**Why this grain?**
- Most business questions are at the ride level
- "What was total revenue today?" (sum all ride_amounts)
- "What's the average trip duration?" (average all durations)
- "How many rides did each driver complete?" (count rows per driver)

**Alternative grains we could consider:**
- **One mile driven**: Good for detailed distance analysis, but too granular for most business questions
- **One driver shift**: Too aggregated, loses detail about individual rides
- **One payment**: Might need this as a separate fact table if you want to track payment processing separately

---

### FACTS (Measures)

These are the **numeric values** we want to analyze:

| Fact | Data Type | Description |
|------|-----------|-------------|
| `fare_amount` | DECIMAL(10,2) | Base fare charged to rider |
| `distance_miles` | DECIMAL(10,2) | Total distance traveled |
| `duration_minutes` | INT | Total time from pickup to dropoff |
| `surge_multiplier` | DECIMAL(4,2) | Surge pricing multiplier (e.g., 1.5x, 2.0x) |
| `tip_amount` | DECIMAL(10,2) | Tip given by rider |
| `toll_amount` | DECIMAL(10,2) | Tolls paid during the ride |
| `tax_amount` | DECIMAL(10,2) | Taxes charged |
| `total_amount` | DECIMAL(10,2) | Total charged to rider |
| `driver_earnings` | DECIMAL(10,2) | Amount paid to driver |
| `company_commission` | DECIMAL(10,2) | Company's cut of the fare |
| `wait_time_minutes` | INT | Time rider waited for pickup |
| `rider_rating` | DECIMAL(3,2) | Rating given by rider (1-5) |
| `driver_rating` | DECIMAL(3,2) | Rating given by driver (1-5) |

**Why these are facts:**
- All are numeric
- All can be aggregated (summed, averaged, counted)
- All answer "how much" or "how many"

---

### DIMENSIONS (Context)

These provide the **context** for analyzing those facts:

#### 1. Dim_Rider (Who requested the ride?)
```sql
CREATE TABLE Dim_Rider (
    rider_key INT PRIMARY KEY,
    rider_id INT,
    rider_name VARCHAR(100),
    email VARCHAR(100),
    phone VARCHAR(20),
    signup_date DATE,
    account_status VARCHAR(20),
    loyalty_tier VARCHAR(20),
    total_rides INT,
    avg_rider_rating DECIMAL(3,2),
    payment_method_on_file VARCHAR(50),
    is_active BOOLEAN
);
```

#### 2. Dim_Driver (Who drove the ride?)
```sql
CREATE TABLE Dim_Driver (
    driver_key INT PRIMARY KEY,
    driver_id INT,
    driver_name VARCHAR(100),
    license_number VARCHAR(50),
    driver_status VARCHAR(20),
    onboard_date DATE,
    total_rides_completed INT,
    avg_driver_rating DECIMAL(3,2),
    acceptance_rate DECIMAL(5,2),
    cancellation_rate DECIMAL(5,2),
    is_active BOOLEAN
);
```

#### 3. Dim_Vehicle (What vehicle was used?)
```sql
CREATE TABLE Dim_Vehicle (
    vehicle_key INT PRIMARY KEY,
    vehicle_id INT,
    make VARCHAR(50),
    model VARCHAR(50),
    year INT,
    color VARCHAR(30),
    license_plate VARCHAR(20),
    vehicle_type VARCHAR(30),
    seating_capacity INT,
    is_active BOOLEAN
);
```

#### 4. Dim_Date (What day?)
```sql
CREATE TABLE Dim_Date (
    date_key INT PRIMARY KEY,          -- YYYYMMDD format
    full_date DATE,
    day_of_week INT,
    day_of_week_name VARCHAR(20),
    day_of_month INT,
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

#### 5. Dim_Time (What time of day?)
```sql
CREATE TABLE Dim_Time (
    time_key INT PRIMARY KEY,          -- HHMMSS format
    hour INT,
    minute INT,
    second INT,
    time_of_day VARCHAR(20),          -- Morning, Afternoon, Evening, Night
    is_rush_hour BOOLEAN,
    is_business_hours BOOLEAN
);
```

#### 6. Dim_Location (Where?)

**Note**: You need TWO location dimensions - pickup and dropoff!

```sql
CREATE TABLE Dim_Location (
    location_key INT PRIMARY KEY,
    location_id INT,
    address VARCHAR(200),
    city VARCHAR(100),
    state VARCHAR(100),
    postal_code VARCHAR(20),
    country VARCHAR(100),
    zone VARCHAR(50),                 -- North, South, Central, etc.
    neighborhood VARCHAR(100),
    latitude DECIMAL(9,6),
    longitude DECIMAL(9,6),
    is_airport BOOLEAN,
    is_downtown BOOLEAN
);
```

#### 7. Dim_Ride_Type (What kind of ride?)
```sql
CREATE TABLE Dim_Ride_Type (
    ride_type_key INT PRIMARY KEY,
    ride_type_id INT,
    ride_type_name VARCHAR(50),       -- Standard, Premium, Shared, XL
    description VARCHAR(200),
    base_fare DECIMAL(10,2),
    price_per_mile DECIMAL(10,2),
    price_per_minute DECIMAL(10,2),
    min_fare DECIMAL(10,2),
    max_passengers INT
);
```

#### 8. Dim_Payment_Method (How did they pay?)
```sql
CREATE TABLE Dim_Payment_Method (
    payment_method_key INT PRIMARY KEY,
    payment_method_id INT,
    payment_type VARCHAR(50),         -- Credit Card, Debit Card, Digital Wallet, Cash
    processor VARCHAR(50),            -- Stripe, PayPal, etc.
    is_digital BOOLEAN
);
```

---

### FACT TABLE: Fact_Rides

```sql
CREATE TABLE Fact_Rides (
    ride_id BIGINT PRIMARY KEY,
    
    -- Dimension Foreign Keys
    rider_key INT REFERENCES Dim_Rider(rider_key),
    driver_key INT REFERENCES Dim_Driver(driver_key),
    vehicle_key INT REFERENCES Dim_Vehicle(vehicle_key),
    pickup_date_key INT REFERENCES Dim_Date(date_key),
    pickup_time_key INT REFERENCES Dim_Time(time_key),
    dropoff_date_key INT REFERENCES Dim_Date(date_key),
    dropoff_time_key INT REFERENCES Dim_Time(time_key),
    pickup_location_key INT REFERENCES Dim_Location(location_key),
    dropoff_location_key INT REFERENCES Dim_Location(location_key),
    ride_type_key INT REFERENCES Dim_Ride_Type(ride_type_key),
    payment_method_key INT REFERENCES Dim_Payment_Method(payment_method_key),
    
    -- Facts (Measures)
    fare_amount DECIMAL(10,2),
    distance_miles DECIMAL(10,2),
    duration_minutes INT,
    surge_multiplier DECIMAL(4,2),
    tip_amount DECIMAL(10,2),
    toll_amount DECIMAL(10,2),
    tax_amount DECIMAL(10,2),
    total_amount DECIMAL(10,2),
    driver_earnings DECIMAL(10,2),
    company_commission DECIMAL(10,2),
    wait_time_minutes INT,
    rider_rating DECIMAL(3,2),
    driver_rating DECIMAL(3,2),
    
    -- Degenerate Dimensions (don't need their own tables)
    ride_status VARCHAR(20),          -- Completed, Cancelled, No-Show
    cancellation_reason VARCHAR(100),
    
    -- Timestamps
    request_timestamp TIMESTAMP,
    pickup_timestamp TIMESTAMP,
    dropoff_timestamp TIMESTAMP,
    
    -- Audit fields
    created_date TIMESTAMP,
    updated_date TIMESTAMP
)
DISTKEY(rider_key)                    -- For Redshift: distribute by rider
SORTKEY(pickup_date_key, pickup_time_key);  -- For Redshift: sort by time
```

---

## The Complete Star Schema

```
                 Dim_Date                    Dim_Date
              (Pickup Date)               (Dropoff Date)
                     │                          │
                     │                          │
        ┌────────────┼──────────────────────────┼─────────────┐
        │            │                          │             │
        │            │                          │             │
   Dim_Time     Dim_Rider                  Dim_Driver    Dim_Time
 (Pickup Time)      │                          │       (Dropoff Time)
        │            │                          │             │
        │            │                          │             │
        └────────────┼──────────────────────────┼─────────────┘
                     │                          │
                     └────────► FACT_RIDES ◄────┘
                                    │
                ┌───────────────────┼───────────────────┐
                │                   │                   │
                │                   │                   │
          Dim_Location        Dim_Vehicle        Dim_Location
           (Pickup)                               (Dropoff)
                                   │
                        ┌──────────┼──────────┐
                        │                     │
                  Dim_Ride_Type      Dim_Payment_Method
```

---

## Sample Data

### Dim_Rider
```
rider_key | rider_id | rider_name | email            | signup_date | loyalty_tier | avg_rider_rating
1001      | R001     | Sanath     | s@email.com      | 2023-01-15  | Gold         | 4.8
1002      | R002     | Priya      | p@email.com      | 2023-03-20  | Silver       | 4.9
1003      | R003     | Rahul      | r@email.com      | 2024-01-05  | Bronze       | 4.7
```

### Dim_Driver
```
driver_key | driver_id | driver_name | license_number | onboard_date | avg_driver_rating | total_rides_completed
2001       | D001      | John Kumar  | KA01AB1234    | 2022-06-10   | 4.9              | 2450
2002       | D002      | Mary David  | KA02CD5678    | 2023-01-15   | 4.8              | 1200
```

### Dim_Location
```
location_key | city      | zone    | neighborhood | is_airport | is_downtown
3001         | Bengaluru | North   | Koramangala  | FALSE      | FALSE
3002         | Bengaluru | Central | MG Road      | FALSE      | TRUE
3003         | Bengaluru | South   | Airport      | TRUE       | FALSE
```

### Fact_Rides (Sample Rows)
```
ride_id | rider_key | driver_key | pickup_location_key | dropoff_location_key | pickup_date_key | fare_amount | distance_miles | duration_minutes | surge_multiplier | tip_amount | total_amount
R12345  | 1001      | 2001       | 3001               | 3002                | 20240112        | 250.00      | 12.5          | 35              | 1.0             | 50.00      | 300.00
R12346  | 1002      | 2002       | 3002               | 3003                | 20240112        | 450.00      | 18.0          | 45              | 1.5             | 75.00      | 525.00
R12347  | 1001      | 2001       | 3003               | 3001                | 20240112        | 500.00      | 20.0          | 55              | 2.0             | 100.00     | 600.00
```

---

## Sample Business Questions & SQL Queries

### Question 1: What's the total revenue by city today?

```sql
SELECT 
    l.city,
    COUNT(f.ride_id) as total_rides,
    SUM(f.total_amount) as total_revenue,
    AVG(f.total_amount) as avg_fare,
    AVG(f.distance_miles) as avg_distance
FROM Fact_Rides f
JOIN Dim_Location l ON f.pickup_location_key = l.location_key
JOIN Dim_Date d ON f.pickup_date_key = d.date_key
WHERE d.full_date = CURRENT_DATE
GROUP BY l.city
ORDER BY total_revenue DESC;
```

---

### Question 2: Which drivers earned the most last week?

```sql
SELECT 
    dr.driver_name,
    dr.driver_id,
    COUNT(f.ride_id) as rides_completed,
    SUM(f.driver_earnings) as total_earnings,
    AVG(f.driver_earnings) as avg_earnings_per_ride,
    AVG(f.rider_rating) as avg_rating_received
FROM Fact_Rides f
JOIN Dim_Driver dr ON f.driver_key = dr.driver_key
JOIN Dim_Date d ON f.pickup_date_key = d.date_key
WHERE d.full_date BETWEEN CURRENT_DATE - 7 AND CURRENT_DATE
    AND f.ride_status = 'Completed'
GROUP BY dr.driver_name, dr.driver_id
ORDER BY total_earnings DESC
LIMIT 10;
```

---

### Question 3: What's the surge pricing impact on revenue?

```sql
SELECT 
    CASE 
        WHEN f.surge_multiplier = 1.0 THEN 'No Surge'
        WHEN f.surge_multiplier BETWEEN 1.1 AND 1.5 THEN 'Low Surge (1.1-1.5x)'
        WHEN f.surge_multiplier BETWEEN 1.6 AND 2.0 THEN 'Medium Surge (1.6-2.0x)'
        ELSE 'High Surge (>2.0x)'
    END as surge_category,
    COUNT(f.ride_id) as total_rides,
    AVG(f.surge_multiplier) as avg_surge_multiplier,
    SUM(f.fare_amount) as total_base_fare,
    SUM(f.total_amount) as total_revenue,
    SUM(f.total_amount) - SUM(f.fare_amount) as surge_revenue,
    AVG(f.duration_minutes) as avg_duration
FROM Fact_Rides f
JOIN Dim_Date d ON f.pickup_date_key = d.date_key
WHERE d.year = 2024 
    AND d.month = 1
    AND f.ride_status = 'Completed'
GROUP BY 
    CASE 
        WHEN f.surge_multiplier = 1.0 THEN 'No Surge'
        WHEN f.surge_multiplier BETWEEN 1.1 AND 1.5 THEN 'Low Surge (1.1-1.5x)'
        WHEN f.surge_multiplier BETWEEN 1.6 AND 2.0 THEN 'Medium Surge (1.6-2.0x)'
        ELSE 'High Surge (>2.0x)'
    END
ORDER BY avg_surge_multiplier;
```

---

### Question 4: Peak hours analysis - when are most rides happening?

```sql
SELECT 
    t.hour,
    t.time_of_day,
    d.day_of_week_name,
    COUNT(f.ride_id) as total_rides,
    AVG(f.wait_time_minutes) as avg_wait_time,
    AVG(f.surge_multiplier) as avg_surge,
    SUM(f.total_amount) as total_revenue
FROM Fact_Rides f
JOIN Dim_Time t ON f.pickup_time_key = t.time_key
JOIN Dim_Date d ON f.pickup_date_key = d.date_key
WHERE d.year = 2024 
    AND d.month = 1
    AND f.ride_status = 'Completed'
GROUP BY t.hour, t.time_of_day, d.day_of_week_name
ORDER BY d.day_of_week_name, t.hour;
```

---

### Question 5: Popular routes (pickup-dropoff pairs)

```sql
SELECT 
    l_pickup.neighborhood as pickup_neighborhood,
    l_pickup.zone as pickup_zone,
    l_dropoff.neighborhood as dropoff_neighborhood,
    l_dropoff.zone as dropoff_zone,
    COUNT(f.ride_id) as total_rides,
    AVG(f.distance_miles) as avg_distance,
    AVG(f.duration_minutes) as avg_duration,
    AVG(f.total_amount) as avg_fare
FROM Fact_Rides f
JOIN Dim_Location l_pickup ON f.pickup_location_key = l_pickup.location_key
JOIN Dim_Location l_dropoff ON f.dropoff_location_key = l_dropoff.location_key
JOIN Dim_Date d ON f.pickup_date_key = d.date_key
WHERE d.year = 2024 
    AND d.month = 1
    AND f.ride_status = 'Completed'
GROUP BY 
    l_pickup.neighborhood,
    l_pickup.zone,
    l_dropoff.neighborhood,
    l_dropoff.zone
HAVING COUNT(f.ride_id) >= 10  -- Only show routes with at least 10 rides
ORDER BY total_rides DESC
LIMIT 20;
```

---

### Question 6: Rider loyalty analysis

```sql
WITH rider_metrics AS (
    SELECT 
        r.rider_name,
        r.loyalty_tier,
        r.signup_date,
        COUNT(f.ride_id) as total_rides,
        SUM(f.total_amount) as total_spent,
        AVG(f.total_amount) as avg_fare,
        AVG(f.tip_amount) as avg_tip,
        MIN(d.full_date) as first_ride_date,
        MAX(d.full_date) as last_ride_date,
        DATEDIFF(day, MIN(d.full_date), MAX(d.full_date)) as customer_lifetime_days
    FROM Fact_Rides f
    JOIN Dim_Rider r ON f.rider_key = r.rider_key
    JOIN Dim_Date d ON f.pickup_date_key = d.date_key
    WHERE f.ride_status = 'Completed'
    GROUP BY r.rider_name, r.loyalty_tier, r.signup_date
)
SELECT 
    loyalty_tier,
    COUNT(*) as rider_count,
    AVG(total_rides) as avg_rides_per_rider,
    AVG(total_spent) as avg_lifetime_value,
    AVG(avg_tip) as avg_tip_per_ride,
    AVG(customer_lifetime_days) as avg_customer_lifetime_days
FROM rider_metrics
GROUP BY loyalty_tier
ORDER BY avg_lifetime_value DESC;
```

---

## Advanced Scenarios

### Scenario 1: Tracking Cancelled Rides

**Should cancelled rides be in the same fact table?**

**Option A**: Yes, keep them in Fact_Rides with a status field
```sql
WHERE f.ride_status IN ('Completed', 'Cancelled', 'No-Show')
```

**Pros:**
- Single source of truth
- Easy to analyze cancellation rates
- Complete ride request history

**Cons:**
- Cancelled rides have NULL values for many facts (no distance, duration, payment)
- Can skew averages if not filtered properly

**Option B**: Create a separate Fact_Ride_Requests table
```sql
-- All ride requests
CREATE TABLE Fact_Ride_Requests (
    request_id BIGINT PRIMARY KEY,
    rider_key INT,
    requested_date_key INT,
    request_status VARCHAR(20),  -- Matched, Cancelled, Expired
    ...
);

-- Only completed rides
CREATE TABLE Fact_Completed_Rides (
    ride_id BIGINT PRIMARY KEY,
    ...
);
```

**Best Practice**: Use Option A for simplicity, but always filter by status in queries.

---

### Scenario 2: Shared Rides (Multiple Riders)

**Problem**: One ride can have multiple riders!

**Solution**: Use a Bridge Table

```sql
CREATE TABLE Bridge_Ride_Riders (
    ride_id BIGINT REFERENCES Fact_Rides(ride_id),
    rider_key INT REFERENCES Dim_Rider(rider_key),
    pickup_sequence INT,              -- Which rider was picked up first?
    individual_fare DECIMAL(10,2),    -- How much did this rider pay?
    pickup_location_key INT,
    dropoff_location_key INT,
    PRIMARY KEY (ride_id, rider_key)
);
```

**Query**: Total revenue from shared rides
```sql
SELECT 
    f.ride_id,
    COUNT(b.rider_key) as total_riders,
    SUM(b.individual_fare) as total_fare_collected
FROM Fact_Rides f
JOIN Bridge_Ride_Riders b ON f.ride_id = b.ride_id
WHERE f.ride_type_key = (SELECT ride_type_key FROM Dim_Ride_Type WHERE ride_type_name = 'Shared')
GROUP BY f.ride_id;
```

---

### Scenario 3: SCD Type 2 for Drivers

**Problem**: Driver ratings change over time. You want historical accuracy.

**Solution**: Implement SCD Type 2 on Dim_Driver

```sql
CREATE TABLE Dim_Driver (
    driver_key INT PRIMARY KEY,          -- Surrogate key (changes)
    driver_id INT,                       -- Business key (same)
    driver_name VARCHAR(100),
    avg_driver_rating DECIMAL(3,2),     -- This changes!
    effective_date DATE,
    end_date DATE,
    is_current BOOLEAN
);
```

**Sample Data**:
```
driver_key | driver_id | driver_name | avg_driver_rating | effective_date | end_date   | is_current
2001       | D001      | John Kumar  | 4.7              | 2023-01-01     | 2023-12-31 | FALSE
2002       | D001      | John Kumar  | 4.9              | 2024-01-01     | 9999-12-31 | TRUE
```

**Query**: Compare driver rating at time of ride vs. current rating
```sql
SELECT 
    f.ride_id,
    d_historical.driver_name,
    d_historical.avg_driver_rating as rating_when_ride_happened,
    d_current.avg_driver_rating as current_rating,
    (d_current.avg_driver_rating - d_historical.avg_driver_rating) as rating_improvement
FROM Fact_Rides f
JOIN Dim_Driver d_historical 
    ON f.driver_key = d_historical.driver_key
JOIN Dim_Driver d_current 
    ON d_historical.driver_id = d_current.driver_id 
    AND d_current.is_current = TRUE;
```

---

## Optimization for Redshift

### 1. Distribution Key Strategy

```sql
-- Distribute by rider_key (most common join pattern)
CREATE TABLE Fact_Rides (
    ...
)
DISTKEY(rider_key);

-- Distribute small dimension tables to all nodes
CREATE TABLE Dim_Ride_Type (
    ...
)
DISTSTYLE ALL;
```

### 2. Sort Key Strategy

```sql
-- Sort by date and time (most common filters)
CREATE TABLE Fact_Rides (
    ...
)
SORTKEY(pickup_date_key, pickup_time_key);
```

### 3. Compression

```sql
-- Analyze table to apply automatic compression
ANALYZE COMPRESSION Fact_Rides;

-- Apply compression
CREATE TABLE Fact_Rides (
    ride_id BIGINT ENCODE ZSTD,
    pickup_date_key INT ENCODE DELTA,
    fare_amount DECIMAL(10,2) ENCODE AZ64,
    ...
);
```

---

## Variations to Consider

### Alternative Grain 1: Fact_Ride_Events
**Grain**: One row = One event in the ride lifecycle

```
event_id | ride_id | event_type      | event_timestamp      | location_key
1        | R12345  | Request         | 2024-01-12 08:00:00 | 3001
2        | R12345  | Driver Assigned | 2024-01-12 08:02:00 | NULL
3        | R12345  | Pickup          | 2024-01-12 08:15:00 | 3001
4        | R12345  | Dropoff         | 2024-01-12 08:50:00 | 3002
```

**Use case**: Detailed tracking of ride lifecycle, wait time analysis

---

### Alternative Grain 2: Fact_Driver_Shifts
**Grain**: One row = One driver shift

```sql
CREATE TABLE Fact_Driver_Shifts (
    shift_id BIGINT PRIMARY KEY,
    driver_key INT,
    shift_date_key INT,
    start_time_key INT,
    end_time_key INT,
    rides_completed INT,
    total_distance_miles DECIMAL(10,2),
    total_duration_minutes INT,
    total_earnings DECIMAL(10,2),
    online_minutes INT,
    idle_minutes INT
);
```

**Use case**: Driver performance and earnings analysis

---

## Key Learnings Summary

### 1. The Grain is Critical
- Defines what one row represents
- Must be clearly stated
- All facts must be at this grain level

### 2. Multiple Date/Time Dimensions
- Pickup date/time vs Dropoff date/time
- Both are needed for complete analysis

### 3. Multiple Location Dimensions
- Pickup location vs Dropoff location
- Cannot use a single location dimension

### 4. Bridge Tables for Many-to-Many
- Shared rides = multiple riders per ride
- Bridge table handles this elegantly

### 5. Degenerate Dimensions
- Simple attributes like status don't need their own dimension table
- Store directly in fact table

### 6. Star Schema Simplifies Queries
- All dimensions connect directly to fact
- Fewer joins = better performance

---

## Your Next Steps

1. **Draw the star schema** on paper - helps visualize relationships
2. **Write 5 business questions** you want to answer
3. **Write SQL queries** for those questions
4. **Think about edge cases**: What happens with cancelled rides? Shared rides? Refunds?
5. **Consider SCD strategies**: Which attributes need history tracking?

---

## Challenge Exercise 

Now try designing a data model for one of these:

1. **E-commerce**: Orders, Products, Customers, Shipments
2. **Healthcare**: Patient visits, Diagnoses, Treatments, Billing
3. **Banking**: Transactions, Accounts, Customers, Branches
4. **Streaming Service**: Views, Content, Users, Devices

Pick one and work through the same process:
- Define the grain
- Identify facts
- Identify dimensions
- Design the star schema
- Write sample queries

Good luck! 🚀