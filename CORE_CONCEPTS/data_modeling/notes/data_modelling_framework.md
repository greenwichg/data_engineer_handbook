# Framework: How to Identify Facts, Dimensions, and Grain

## A Systematic Approach to Analyzing Any Business Scenario

---

## The Analysis Framework

### Step 1: Understand the Business Process

**Ask yourself:**
- What is the core business activity?
- What event triggers data creation?
- What is the business trying to optimize or measure?

**Example - Ride Hailing:**
- Core activity: Matching riders with drivers and completing trips
- Trigger: A rider requests a ride
- Business goals: Maximize rides, revenue, driver utilization, customer satisfaction

**Example - E-commerce:**
- Core activity: Customers buying products online
- Trigger: Customer places an order
- Business goals: Increase sales, reduce cart abandonment, improve delivery times

---

## Step 2: Identify FACTS Using the "Money, Time, Quantity" Framework

### The MTQ Framework:

**M = MONEY** (Follow the money trail)
- What is being paid?
- What costs are involved?
- What revenue is generated?
- What fees/taxes/commissions apply?

**T = TIME** (Track all durations)
- How long did it take?
- When did it start/end?
- What wait times exist?
- What processing times matter?

**Q = QUANTITY** (Count everything)
- How many items?
- How much distance?
- How many units?
- What volumes are involved?

### Deep Dive Questions for Facts:

#### 1. Money Questions:
```
- What is the customer paying for?
- Are there multiple charges? (base + extras)
- What's the breakdown? (subtotal, tax, fees, tips)
- Who gets what? (revenue split between parties)
- Are there discounts or refunds?
- What are the costs? (operational costs)
```

#### 2. Time Questions:
```
- How long did the process take? (start to finish)
- Were there wait times? (queuing, delays)
- What are the sub-durations? (prep time, delivery time)
- Are there SLA metrics? (promised vs actual time)
- What's the response time?
```

#### 3. Quantity Questions:
```
- How much/many? (items, units, volume, weight)
- What's the capacity? (seats, slots, space)
- What distance? (miles, kilometers)
- What's the count? (number of events, transactions)
- What's the rate? (items per hour, speed)
```

#### 4. Quality/Performance Questions:
```
- What ratings/scores exist?
- What's the accuracy rate?
- What's the success/failure rate?
- What's the satisfaction level?
```

---

## Step 3: Identify DIMENSIONS Using the "5W + 1H" Framework

### The 5W + 1H Framework:

**WHO** - The actors/participants
- Who initiated this?
- Who performed the action?
- Who received the service/product?
- Who else is involved?

**WHAT** - The objects/items
- What product/service?
- What type/category?
- What variant/SKU?
- What method/channel?

**WHEN** - The temporal context
- What date?
- What time of day?
- What season/quarter?
- Is it a weekday/weekend?
- Is it a holiday?

**WHERE** - The spatial context
- What location?
- What region/zone?
- What store/warehouse?
- Start location vs end location?

**WHY** - The reason/purpose
- What category/type?
- What reason code?
- What campaign/promotion?
- What source/channel?

**HOW** - The method/process
- How was payment made?
- How was it delivered?
- How was it processed?
- What was the method/mode?

### Deep Dive Questions for Dimensions:

```
WHO:
- Customers/users (demographics, segments, loyalty status)
- Employees/agents (who processed it, who delivered it)
- Partners/vendors (who supplied it)
- Teams/departments (who owns it)

WHAT:
- Products (SKU, category, brand)
- Services (type, tier, package)
- Channels (online, store, mobile app)
- Status (completed, cancelled, pending)

WHEN:
- Date (full date hierarchy)
- Time (hour, minute, time of day)
- Fiscal periods (fiscal year, quarter)
- Special dates (holidays, events)

WHERE:
- Geography (country, state, city, zip)
- Facility (store, warehouse, branch)
- Zone (territory, region, district)
- Virtual location (website section, app screen)

WHY:
- Purpose (personal, business)
- Category (standard, premium, economy)
- Source (referral, organic, paid ad)
- Reason (promo code, loyalty points)

HOW:
- Payment method (credit card, cash, digital wallet)
- Delivery method (pickup, shipping, digital)
- Process (automated, manual, hybrid)
- Channel (web, mobile, in-person)
```

---

## Step 4: Determine GRAIN Using the "Business Question" Test

### The Grain Decision Process:

#### Ask: "What is the atomic business event we're measuring?"

**Test different grain options:**

| Grain Option | Question to Ask | When to Use This Grain |
|--------------|----------------|------------------------|
| One transaction | "Do we analyze complete transactions?" | Most common - captures complete business events |
| One line item | "Do we need product-level detail?" | When transaction details matter (what was bought) |
| One event/step | "Do we track each step in a process?" | When process analysis is needed (funnel, lifecycle) |
| One time period | "Do we aggregate by day/hour?" | For summary/snapshot tables |
| One shipment | "Do we track fulfillment separately?" | When logistics is a separate process |

#### The Grain Validation Questions:

```
1. Can I answer all my business questions at this grain?
   ✓ "What was revenue yesterday?" → Need transaction-level grain
   ✓ "What products sell best?" → Need line-item-level grain

2. Is this the lowest level of detail I need?
   ✗ Too granular: One second of ride → Creates billions of rows
   ✓ Just right: One complete ride → Manageable and useful

3. Are all facts truly at this grain level?
   ✓ At "one order" grain: order_total ✓, item_price ✗ (varies by item)
   ✓ At "one order line" grain: item_price ✓, order_total ✗ (same for all lines)

4. Will this grain handle exceptions?
   ? One order with multiple addresses? → Might need different grain
   ? One transaction with multiple payment methods? → Consider implications
```

---

## Step 5: The Mental Walkthrough Method

### Visualize the Business Process:

**Step-by-step visualization:**

1. **Start with a specific example**
   - "Sanath orders a pizza from Pizza Palace at 7 PM on Friday"

2. **Walk through each step**
   - Sanath opens app → sees menu → adds items → checks out → pays
   - System assigns order to Pizza Palace
   - Restaurant receives order → prepares food
   - System assigns driver John
   - John picks up food → delivers to Sanath
   - Transaction completes

3. **At each step, ask:**
   - What **numbers** am I creating? (FACTS)
   - What **context** describes this? (DIMENSIONS)
   - What is the **unit of measurement**? (GRAIN)

4. **Write down everything you observe:**

```
Step: Order Placed
Numbers: order_amount ($28.96), item_count (3), tax ($2.50)
Context: who (Sanath), what restaurant (Pizza Palace), when (7 PM Friday)
Grain: One order

Step: Payment Processed
Numbers: payment_amount ($28.96), tip ($4.00), processing_fee ($0.50)
Context: payment_method (Credit Card), processor (Stripe)
Grain: One payment? Or part of one order?

Step: Food Prepared
Numbers: prep_time (15 mins), items_prepared (3)
Context: which restaurant, which chef
Grain: Still one order

Step: Delivery
Numbers: delivery_time (25 mins), distance (5 miles)
Context: which driver, which route
Grain: Still one order
```

5. **Consolidate:**
   - All these steps are part of ONE ORDER
   - So grain = "One order"
   - Facts = all the numbers we collected
   - Dimensions = all the context

---

## Step 6: Look at Real Data (If Available)

### Analyze Existing Reports/Dashboards:

**Questions to ask:**
```
1. What reports does the business run today?
   → These reveal what facts they care about

2. What are the rows in current reports?
   → This reveals the grain they're using

3. What filters/groupings do they use?
   → These become your dimensions

4. What calculations do they perform?
   → These become your facts
```

**Example - Looking at a Sales Report:**

```
Report: "Daily Sales by Store"
Rows: Each store, each day
Columns: Total Sales, Transaction Count, Avg Transaction Value

Analysis:
→ Facts: total_sales, transaction_count, avg_transaction_value
→ Dimensions: Dim_Store, Dim_Date
→ Current grain: One day per store (aggregated)
→ Better grain for data warehouse: One transaction (lower level)
```

---

## Step 7: Common Patterns by Industry

### Food Delivery / Ride Hailing

**Facts:** money (fare, tip, fees), time (wait, delivery, duration), distance, ratings
**Dimensions:** customer, provider (restaurant/driver), location (pickup/dropoff), date/time
**Grain:** One completed order/ride

### E-commerce

**Facts:** price, quantity, discount, shipping cost, tax, item weight
**Dimensions:** customer, product, store, date/time, shipping method, promotion
**Grain:** One order line item (each product in the order)

### Banking

**Facts:** transaction amount, balance, interest, fees
**Dimensions:** account, customer, branch, date/time, transaction type, channel
**Grain:** One transaction

### Healthcare

**Facts:** charge amount, quantity (units), duration (minutes), dosage
**Dimensions:** patient, provider, diagnosis, procedure, date/time, facility
**Grain:** One procedure/service

### Manufacturing

**Facts:** quantity produced, defect count, production time, cost, yield rate
**Dimensions:** product, machine, shift, date/time, operator, plant
**Grain:** One production run or one unit produced

### Streaming/Media

**Facts:** watch time (minutes), data consumed (GB), revenue, ad impressions
**Dimensions:** user, content, device, date/time, subscription tier
**Grain:** One viewing session or one content view event

---

## Practice Exercise Framework

### Template for Any Scenario:

```markdown
SCENARIO: [Describe the business process]

STEP 1: Business Process
- Core activity: 
- Trigger event: 
- Business goals: 

STEP 2: FACTS (MTQ Framework)
Money:
- 
Time:
- 
Quantity:
- 
Other:
- 

STEP 3: DIMENSIONS (5W+1H)
WHO:
- 
WHAT:
- 
WHEN:
- 
WHERE:
- 
WHY:
- 
HOW:
- 

STEP 4: GRAIN
Grain: One [what?]
Validation:
- Can I answer business questions? 
- Lowest needed level? 
- All facts at this grain? 

STEP 5: Business Questions (that this model should answer)
1. 
2. 
3. 
```

---

## Worked Example: Hotel Booking System

Let me show you the complete process:

### SCENARIO: 
A customer books a hotel room online for 3 nights.

### STEP 1: Business Process
- **Core activity:** Managing hotel reservations and stays
- **Trigger event:** Customer makes a booking
- **Business goals:** Maximize occupancy, revenue per room, customer satisfaction

### STEP 2: Identify FACTS

**Money (Follow the money):**
```
Q: What is the customer paying?
A: Room rate per night ($150/night), taxes ($30), resort fees ($45), parking ($20/day)

Q: Are there discounts?
A: Member discount ($20), promo code discount ($15)

Q: What's the total?
A: Total amount paid ($475)

Q: What are the costs?
A: Housekeeping cost, amenities cost, utilities

Facts identified:
- room_rate_per_night
- number_of_nights
- subtotal_amount
- tax_amount
- resort_fee
- parking_fee
- discount_amount
- total_amount_paid
- cost_to_service (if available)
- revenue (total - costs)
```

**Time (Track durations):**
```
Q: How long is the stay?
A: 3 nights (check-in to check-out)

Q: How long between booking and arrival?
A: 30 days (advance booking)

Q: Did they check out late?
A: Yes, 2 hours late (late_checkout_minutes)

Facts identified:
- number_of_nights
- booking_lead_time_days
- late_checkout_minutes
- early_checkin_minutes (if any)
```

**Quantity (Count everything):**
```
Q: How many rooms?
A: 1 room

Q: How many guests?
A: 2 adults, 1 child

Q: How many nights?
A: 3 nights

Facts identified:
- number_of_rooms
- number_of_adults
- number_of_children
- total_guests
```

**Quality/Performance:**
```
Q: What ratings?
A: Guest satisfaction rating (4.5/5), cleanliness rating (5/5)

Facts identified:
- guest_satisfaction_rating
- cleanliness_rating
- amenities_rating
```

### STEP 3: Identify DIMENSIONS

**WHO:**
```
Q: Who booked?
A: Customer (name, email, phone, membership status, loyalty tier)

Dimension: Dim_Guest
- guest_id, name, email, membership_level, loyalty_points, booking_history
```

**WHAT:**
```
Q: What was booked?
A: Deluxe King Room

Q: What type?
A: Room type, bed type, view type

Q: What rate plan?
A: Standard rate, corporate rate, weekend package?

Dimensions: 
- Dim_Room_Type (room_type_id, description, capacity, bed_type, amenities)
- Dim_Rate_Plan (rate_plan_id, rate_type, cancellation_policy)
```

**WHEN:**
```
Q: When was it booked?
A: December 15, 2024

Q: When was the stay?
A: January 12-15, 2025

Dimensions:
- Dim_Booking_Date (when reservation was made)
- Dim_Checkin_Date (when stay started)
- Dim_Checkout_Date (when stay ended)
```

**WHERE:**
```
Q: Which hotel?
A: Marriott Whitefield, Bangalore

Q: Which room?
A: Room 305, 3rd floor

Dimensions:
- Dim_Hotel (hotel_id, name, brand, city, country, star_rating)
- Dim_Room (room_id, room_number, floor, building)
```

**WHY:**
```
Q: Purpose of stay?
A: Business trip, vacation, wedding, conference?

Q: How did they find us?
A: Direct website, booking.com, travel agent

Dimensions:
- Dim_Booking_Source (source_id, source_name, source_type, commission_rate)
- Dim_Stay_Purpose (purpose_id, purpose_type)
```

**HOW:**
```
Q: Payment method?
A: Credit card, cash, corporate account

Q: Booking channel?
A: Website, mobile app, phone, front desk

Dimensions:
- Dim_Payment_Method (payment_method_id, payment_type)
- Dim_Booking_Channel (channel_id, channel_name, device_type)
```

### STEP 4: Determine GRAIN

**Option A: One reservation**
```
Grain: One row = One complete booking

Pros:
- Captures complete reservation details
- Easy to calculate revenue, occupancy
- Natural business unit

Cons:
- Multi-room bookings? (Family books 2 rooms)
- Multi-night stays? (All nights lumped together)

Validation:
✓ "What's total revenue?" → SUM(total_amount) works
✓ "What's average length of stay?" → AVG(number_of_nights) works
✗ "Which day of week has highest occupancy?" → Can't tell, all nights are one row
```

**Option B: One room-night**
```
Grain: One row = One room for one night

Pros:
- Can analyze by specific nights
- Can track daily occupancy
- Can handle multi-room bookings

Cons:
- More rows (3-night stay = 3 rows)
- Have to distribute total amount across nights

Validation:
✓ "Which day of week has highest occupancy?" → COUNT rows by day_of_week works
✓ "What's occupancy rate on Fridays?" → Can calculate
✓ "How many rooms occupied each night?" → COUNT(*) works
```

**Decision: Use Option B (One room-night) because:**
- Hotel's key metric is daily occupancy rate
- Needs to analyze demand by specific dates
- Weekend vs weekday pricing differs
- Can still roll up to reservation level if needed

### STEP 5: Design the Fact Table

```sql
CREATE TABLE Fact_Hotel_Stays (
    stay_id BIGINT PRIMARY KEY,
    
    -- Foreign Keys
    reservation_key INT,              -- Links back to reservation
    guest_key INT,
    room_key INT,
    room_type_key INT,
    hotel_key INT,
    stay_date_key INT,               -- The specific night
    booking_date_key INT,
    booking_channel_key INT,
    rate_plan_key INT,
    
    -- Facts (Money)
    room_rate DECIMAL(10,2),         -- Rate for THIS night
    tax_amount DECIMAL(10,2),
    resort_fee DECIMAL(10,2),
    parking_fee DECIMAL(10,2),
    discount_amount DECIMAL(10,2),
    total_amount DECIMAL(10,2),
    
    -- Facts (Quantity)
    number_of_adults INT,
    number_of_children INT,
    
    -- Facts (Performance)
    guest_satisfaction_rating DECIMAL(3,2),
    
    -- Degenerate Dimensions
    confirmation_number VARCHAR(20),
    booking_status VARCHAR(20),
    
    -- Timestamps
    created_timestamp TIMESTAMP
)
DISTKEY(hotel_key)
SORTKEY(stay_date_key);
```

### STEP 6: Sample Business Questions

```sql
-- 1. Daily occupancy rate
SELECT 
    d.full_date,
    d.day_of_week_name,
    COUNT(DISTINCT f.room_key) as rooms_occupied,
    (COUNT(DISTINCT f.room_key) * 100.0 / h.total_rooms) as occupancy_rate
FROM Fact_Hotel_Stays f
JOIN Dim_Date d ON f.stay_date_key = d.date_key
JOIN Dim_Hotel h ON f.hotel_key = h.hotel_key
GROUP BY d.full_date, d.day_of_week_name, h.total_rooms;

-- 2. Revenue by room type
SELECT 
    rt.room_type_name,
    COUNT(*) as room_nights_sold,
    SUM(f.total_amount) as total_revenue,
    AVG(f.total_amount) as avg_revenue_per_night
FROM Fact_Hotel_Stays f
JOIN Dim_Room_Type rt ON f.room_type_key = rt.room_type_key
GROUP BY rt.room_type_name;

-- 3. Booking lead time analysis
SELECT 
    DATEDIFF(day, bd.full_date, sd.full_date) as lead_time_days,
    COUNT(*) as number_of_bookings,
    AVG(f.total_amount) as avg_booking_value
FROM Fact_Hotel_Stays f
JOIN Dim_Date bd ON f.booking_date_key = bd.date_key
JOIN Dim_Date sd ON f.stay_date_key = sd.date_key
GROUP BY DATEDIFF(day, bd.full_date, sd.full_date)
ORDER BY lead_time_days;
```

---

## Red Flags & Common Mistakes

### ❌ MISTAKE 1: Mixing Grains
```sql
-- WRONG: Mixing order-level and item-level facts
CREATE TABLE Fact_Orders (
    order_id INT,
    item_name VARCHAR(100),      -- Item level
    item_price DECIMAL(10,2),    -- Item level
    order_total DECIMAL(10,2),   -- Order level ❌
    ...
);
-- Problem: order_total repeats for each item
```

**Solution:** Keep consistent grain OR use bridge tables

### ❌ MISTAKE 2: Facts in Dimensions
```sql
-- WRONG: Storing transaction amounts in customer dimension
CREATE TABLE Dim_Customer (
    customer_id INT,
    customer_name VARCHAR(100),
    total_spent DECIMAL(10,2),    -- This is a FACT! ❌
    ...
);
```

**Solution:** Calculate aggregated facts on the fly from fact table

### ❌ MISTAKE 3: Too Granular
```sql
-- WRONG: One second of ride
Grain: One row = One second of ride
-- Problem: 30-minute ride = 1,800 rows!
```

**Solution:** Choose the atomic business event, not sub-second intervals

### ❌ MISTAKE 4: Missing Dimensions
```sql
-- INCOMPLETE: Can't answer "Which city generates most revenue?"
CREATE TABLE Fact_Orders (
    order_id INT,
    customer_key INT,
    order_amount DECIMAL(10,2)
    -- Missing: location_key! ❌
);
```

**Solution:** Think through all 5W+1H questions

---

## Quick Reference Checklist

```
□ Understand the business process
□ Walk through a specific example
□ Apply MTQ framework for facts (Money, Time, Quantity)
□ Apply 5W+1H for dimensions (Who, What, When, Where, Why, How)
□ Test grain options against business questions
□ Validate: All facts at same grain level?
□ Validate: Can answer key business questions?
□ Check for common patterns in similar industries
□ Look at existing reports for clues
□ Avoid common mistakes (mixed grain, facts in dims, etc.)
```

---

## Summary

**The key is systematic thinking:**

1. **Start with the business event** - What happened?
2. **Follow the money, time, and quantities** - What was measured?
3. **Ask 5W+1H** - What's the context?
4. **Test grain options** - What level of detail?
5. **Validate with business questions** - Can you answer them?

**Practice makes perfect!** The more scenarios you work through, the faster you'll recognize patterns.

---

## Your Next Steps

1. **Pick 3 different industries** (banking, retail, healthcare)
2. **Write a scenario** (1-2 paragraphs describing a business process)
3. **Apply this framework step-by-step**
4. **Design the dimensional model**
5. **Write 5 business questions and SQL queries**

Good luck! 🎯