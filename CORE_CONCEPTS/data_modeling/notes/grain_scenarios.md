# Understanding Grain with Real-World Examples

## Different Grain Options for Various Business Scenarios

---

## Example 1: Hotel Booking System

### The Scenario:
A customer books a hotel room for 3 nights (Jan 12-15, 2024)

**Booking Details:**
- Guest: John Smith
- Room: Deluxe King (Room 305)
- Check-in: Jan 12, 2024
- Check-out: Jan 15, 2024
- Total: $450 ($150/night × 3 nights)

### Grain Option A: One Row = One Reservation (Coarsest)

```
reservation_id | guest_name  | room_number | check_in   | check_out  | total_amount | num_nights
R001          | John Smith  | 305         | 2024-01-12 | 2024-01-15 | 450.00      | 3
R002          | Jane Doe    | 405         | 2024-01-13 | 2024-01-14 | 150.00      | 1
```

**Can Answer:**
✅ "How many reservations this month?"
✅ "Total revenue this month?"
✅ "Average stay length?"

**Cannot Answer:**
❌ "Which specific date has highest occupancy?"
❌ "How many rooms occupied on Jan 13?"
❌ "Weekend vs weekday demand?"

---

### Grain Option B: One Row = One Room-Night (Fine Grain)

```
stay_id | reservation_id | guest_name  | room_number | stay_date  | rate_per_night
S001    | R001          | John Smith  | 305         | 2024-01-12 | 150.00
S002    | R001          | John Smith  | 305         | 2024-01-13 | 150.00
S003    | R001          | John Smith  | 305         | 2024-01-14 | 150.00
S004    | R002          | Jane Doe    | 405         | 2024-01-13 | 150.00
```

**Can Answer:**
✅ "Which specific date has highest occupancy?" (COUNT rows by date)
✅ "How many rooms occupied on Jan 13?" (2 rooms)
✅ "Weekend vs weekday demand?" (GROUP BY day_of_week)
✅ ALL questions from Option A (just aggregate)

**Trade-off:**
⚠️ More rows (3x for 3-night stay)
⚠️ More storage space

---

### Grain Option C: One Row = One Reservation Line (If Multiple Rooms)

```
reservation_line_id | reservation_id | guest_name  | room_number | check_in   | check_out  | room_total
RL001              | R003          | Bob Jones   | 305         | 2024-01-12 | 2024-01-15 | 450.00
RL002              | R003          | Bob Jones   | 306         | 2024-01-12 | 2024-01-15 | 450.00
```
*(Bob booked 2 rooms for his family)*

**Use When:**
- Customers can book multiple rooms in one reservation
- Need to track each room separately
- Want room-level details but not night-by-night

---

### **Recommended for Hotels: Option B (Room-Night)**
**Why?** Hotels need daily occupancy rates, pricing varies by day of week

---

## Example 2: Streaming Service (Netflix/Spotify)

### The Scenario:
A user watches movies/shows on your platform

**User Activity:**
- User: Sarah
- Date: Jan 12, 2024
- Watched "Stranger Things S1E1" (52 minutes)
- Then watched "The Crown S1E1" (58 minutes)

### Grain Option A: One Row = One Day of Usage

```
user_id | date       | total_minutes_watched | content_count
U001    | 2024-01-12 | 110                  | 2
U001    | 2024-01-13 | 45                   | 1
U002    | 2024-01-12 | 180                  | 3
```

**Can Answer:**
✅ "Average daily usage per user?"
✅ "Total viewing hours this month?"

**Cannot Answer:**
❌ "Which shows are most popular?"
❌ "What do users watch after 'Stranger Things'?"
❌ "Average episode completion rate?"

---

### Grain Option B: One Row = One Viewing Session (Medium Grain)

```
session_id | user_id | content_title      | start_time          | duration_mins | completion_pct | device
V001       | U001    | Stranger Things E1 | 2024-01-12 20:00:00| 52           | 100%          | TV
V002       | U001    | The Crown E1       | 2024-01-12 21:00:00| 58           | 100%          | TV
V003       | U002    | Breaking Bad E1    | 2024-01-12 19:30:00| 30           | 60%           | Mobile
```

**Can Answer:**
✅ "Which shows are most popular?" (COUNT sessions by content)
✅ "What do users watch after 'Stranger Things'?" (Find next session)
✅ "Average episode completion rate?" (AVG completion_pct)
✅ ALL questions from Option A (aggregate)

**Trade-off:**
⚠️ More rows, but manageable

---

### Grain Option C: One Row = One Minute Watched (Too Fine!)

```
minute_id | user_id | content_title      | timestamp           | device
M001      | U001    | Stranger Things E1 | 2024-01-12 20:00:00| TV
M002      | U001    | Stranger Things E1 | 2024-01-12 20:01:00| TV
M003      | U001    | Stranger Things E1 | 2024-01-12 20:02:00| TV
... (52 rows for one episode!)
```

**Problems:**
❌ Massive data volume (52 rows per episode!)
❌ Expensive to store and query
❌ Most detail is not useful

---

### **Recommended for Streaming: Option B (Viewing Session)**
**Why?** Balances detail (can analyze content) with efficiency

---

## Example 3: Bank Account Transactions

### The Scenario:
A customer makes several transactions in their account

**Transaction Details:**
- Customer: Alice
- Account: Checking #1234
- Jan 12: Deposit $1,000
- Jan 12: Withdrawal $50 (ATM)
- Jan 13: Payment $200 (Online bill pay)

### Grain Option A: One Row = Daily Account Summary

```
account_id | date       | opening_balance | deposits | withdrawals | closing_balance
1234       | 2024-01-12 | 500.00         | 1000.00 | 50.00       | 1450.00
1234       | 2024-01-13 | 1450.00        | 0.00    | 200.00      | 1250.00
```

**Can Answer:**
✅ "Daily account balance?"
✅ "Total deposits this month?"

**Cannot Answer:**
❌ "How many ATM withdrawals?"
❌ "Which bills were paid?"
❌ "Transaction-by-transaction history?"

---

### Grain Option B: One Row = One Transaction (Fine Grain)

```
transaction_id | account_id | date       | time     | type        | amount   | balance_after | description
T001          | 1234       | 2024-01-12 | 09:00:00 | Deposit     | 1000.00  | 1500.00      | Payroll
T002          | 1234       | 2024-01-12 | 14:30:00 | Withdrawal  | -50.00   | 1450.00      | ATM Cash
T003          | 1234       | 2024-01-13 | 10:00:00 | Payment     | -200.00  | 1250.00      | Electric Bill
```

**Can Answer:**
✅ "How many ATM withdrawals?" (COUNT WHERE type = 'Withdrawal')
✅ "Which bills were paid?" (SELECT WHERE type = 'Payment')
✅ "Transaction-by-transaction history?" (YES!)
✅ ALL questions from Option A (SUM by date)

**Trade-off:**
⚠️ More rows (3 vs 2 in this example)
✅ But necessary for banking compliance!

---

### Grain Option C: One Row = One Transaction Line (For Complex Transactions)

```
transaction_line_id | transaction_id | account_id | amount   | account_type
TL001              | T004          | 1234       | -300.00  | Checking
TL002              | T004          | 5678       | 300.00   | Savings
```
*(Transfer between accounts = 2 lines)*

**Use When:**
- Transfers between accounts
- Double-entry bookkeeping
- Need to track both sides of transaction

---

### **Recommended for Banking: Option B (Transaction)**
**Why?** Regulatory requirements, audit trails, customer service

---

## Example 4: E-commerce Marketplace (Amazon/eBay)

### The Scenario:
A customer places an order with multiple items from different sellers

**Order Details:**
- Customer: Mike
- Order #1001 placed on Jan 12, 2024
- Item 1: iPhone from Seller A ($999)
- Item 2: Case from Seller B ($29)
- Item 3: Charger from Seller A ($35)

### Grain Option A: One Row = One Order

```
order_id | customer_name | order_date | total_amount | item_count | seller_count
1001     | Mike         | 2024-01-12 | 1063.00     | 3          | 2
1002     | Sarah        | 2024-01-13 | 499.00      | 1          | 1
```

**Can Answer:**
✅ "How many orders today?"
✅ "Total revenue today?"
✅ "Average order value?"

**Cannot Answer:**
❌ "Which products are bestsellers?"
❌ "Which sellers are top performers?"
❌ "How much did Seller A earn?"

---

### Grain Option B: One Row = One Item in Order (Medium Grain)

```
order_id | customer_name | order_date | item_name | price  | quantity | seller_name
1001     | Mike         | 2024-01-12 | iPhone   | 999.00 | 1        | Seller A
1001     | Mike         | 2024-01-12 | Case     | 29.00  | 1        | Seller B
1001     | Mike         | 2024-01-12 | Charger  | 35.00  | 1        | Seller A
1002     | Sarah        | 2024-01-13 | Laptop   | 499.00 | 1        | Seller C
```

**Can Answer:**
✅ "Which products are bestsellers?" (COUNT items by name)
✅ "Which sellers are top performers?" (SUM by seller_name)
✅ "How much did Seller A earn?" ($999 + $35 = $1,034)
✅ ALL questions from Option A (aggregate)

---

### Grain Option C: One Row = One Fulfillment Unit

```
fulfillment_id | order_id | seller_name | items                    | subtotal | shipping_status
F001          | 1001     | Seller A    | iPhone, Charger         | 1034.00  | Shipped
F002          | 1001     | Seller B    | Case                    | 29.00    | Delivered
```
*(Items from same seller ship together)*

**Use When:**
- Multi-seller marketplace
- Items ship separately by seller
- Need to track fulfillment separately

---

### **Recommended for Marketplace: Option B (Order Item)**
**Why?** Need product-level analytics and seller performance tracking

---

## Example 5: Ride-Sharing with Stops (Uber Pool)

### The Scenario:
A driver completes a shared ride with 3 passengers, picking up and dropping off at different locations

**Ride Details:**
- Driver: Dave
- Date: Jan 12, 2024
- Passenger 1: Alice (A → B) pays $10
- Passenger 2: Bob (A → C) pays $12
- Passenger 3: Carol (B → C) pays $8
- Total distance: 15 miles
- Total time: 45 minutes

### Grain Option A: One Row = One Ride Completion

```
ride_id | driver_name | ride_date  | total_fare | distance_miles | duration_mins | passenger_count
R001    | Dave       | 2024-01-12 | 30.00     | 15.0          | 45           | 3
R002    | Dave       | 2024-01-12 | 25.00     | 10.0          | 30           | 2
```

**Can Answer:**
✅ "Driver's total earnings?"
✅ "Average ride distance?"

**Cannot Answer:**
❌ "How much did each passenger pay?"
❌ "Where did each passenger go?"
❌ "Which routes are most common?"

---

### Grain Option B: One Row = One Passenger in Ride

```
ride_passenger_id | ride_id | driver | passenger | pickup_loc | dropoff_loc | fare  | pickup_seq
RP001            | R001    | Dave   | Alice     | Location A | Location B  | 10.00 | 1
RP002            | R001    | Dave   | Bob       | Location A | Location C  | 12.00 | 2
RP003            | R001    | Dave   | Carol     | Location B | Location C  | 8.00  | 3
```

**Can Answer:**
✅ "How much did each passenger pay?"
✅ "Where did each passenger go?" (pickup/dropoff locations)
✅ "Which routes are most common?" (pickup → dropoff pairs)
✅ ALL questions from Option A (SUM fare, etc.)

---

### Grain Option C: One Row = One Ride Leg (Finest)

```
leg_id | ride_id | from_location | to_location | distance | passengers_aboard
L001   | R001    | Location A    | Location B  | 5 miles  | Alice, Bob
L002   | R001    | Location B    | Location C  | 10 miles | Bob, Carol
```
*(Each segment between stops)*

**Use When:**
- Need precise distance tracking
- Calculate per-mile charges
- Analyze route efficiency

---

### **Recommended for Ride-Share: Option B (Passenger)**
**Why?** Need passenger-level billing and route analysis

---

## Example 6: Fitness Tracking App

### The Scenario:
A user goes for a run

**Workout Details:**
- User: Tom
- Date: Jan 12, 2024
- Activity: Running
- Duration: 30 minutes
- Distance: 5 km
- Calories: 350
- Route: Park Loop

### Grain Option A: One Row = One Workout Session

```
workout_id | user_name | workout_date | activity | duration_mins | distance_km | calories | route
W001       | Tom      | 2024-01-12   | Running  | 30           | 5.0        | 350     | Park Loop
W002       | Tom      | 2024-01-13   | Cycling  | 60           | 20.0       | 400     | Riverside
```

**Can Answer:**
✅ "How many workouts this week?"
✅ "Total calories burned?"
✅ "Average workout duration?"

**Cannot Answer:**
❌ "What was pace at mile 2?"
❌ "Heart rate during workout?"
❌ "Elevation changes?"

---

### Grain Option B: One Row = One Kilometer/Mile

```
segment_id | workout_id | user_name | segment_num | distance_km | time_mins | pace | heart_rate
S001       | W001      | Tom       | 1           | 1.0        | 6.0      | 6:00 | 140
S002       | W001      | Tom       | 2           | 1.0        | 5.8      | 5:48 | 145
S003       | W001      | Tom       | 3           | 1.0        | 6.2      | 6:12 | 138
S004       | W001      | Tom       | 4           | 1.0        | 5.9      | 5:54 | 142
S005       | W001      | Tom       | 5           | 1.0        | 6.1      | 6:06 | 140
```

**Can Answer:**
✅ "What was pace at km 2?" (5:48)
✅ "Heart rate during workout?" (AVG heart_rate)
✅ "Did pace improve over distance?" (Compare segments)
✅ ALL questions from Option A

---

### Grain Option C: One Row = GPS Point (Too Fine!)

```
gps_id | workout_id | timestamp           | latitude  | longitude  | elevation | heart_rate
G001   | W001      | 2024-01-12 08:00:00| 12.9716   | 77.5946   | 920m     | 140
G002   | W001      | 2024-01-12 08:00:05| 12.9717   | 77.5947   | 921m     | 141
... (360 rows for 30-minute workout with 5-second intervals!)
```

**Problems:**
❌ Massive data (360 rows per 30-min workout!)
❌ Most detail not useful for analytics

---

### **Recommended for Fitness: Option A or B**
- **Option A** for casual users (just track workouts)
- **Option B** for serious athletes (detailed performance analysis)

---

## Grain Decision Matrix

### How to Choose the Right Grain

| Business Question | Requires This Grain |
|-------------------|-------------------|
| "Daily metrics?" | Daily aggregation grain |
| "Product-level analysis?" | Product/item-level grain |
| "Hour-by-hour patterns?" | Hourly grain |
| "Individual transaction details?" | Transaction-level grain |
| "User journey analysis?" | Event-level grain |

### The Trade-off Formula

```
Finer Grain = More Detail = More Rows = More Storage = Slower Queries
                    BUT
More Analytical Power = Answer More Questions = Better Insights
```

### The Golden Rule

**Choose the finest grain that:**
1. ✅ Answers your key business questions
2. ✅ Is practical to store and query
3. ✅ Represents a meaningful business event
4. ✅ Balances detail with performance

---

## Quick Comparison Table

| Scenario | Coarse Grain | Medium Grain | Fine Grain |
|----------|-------------|--------------|------------|
| **Hotel** | One reservation | One room-night ⭐ | One hour/service |
| **Streaming** | Daily usage | One viewing session ⭐ | One minute watched |
| **Banking** | Daily summary | One transaction ⭐ | Transaction line |
| **E-commerce** | One order | One order item ⭐ | One fulfillment |
| **Ride-share** | One ride | One passenger ⭐ | One route leg |
| **Fitness** | One workout ⭐ | One km/mile | GPS point |

⭐ = Most commonly recommended grain

---

## Real-World Examples: Before and After

### Example: Hotel Changed Grain from Coarse to Fine

**Before (One Reservation):**
```
Problem: "Can't calculate daily occupancy rate"
Can't answer: "How many rooms occupied on weekends vs weekdays?"
```

**After (One Room-Night):**
```
Solution: Count rows by day of week
Now can answer: "Saturdays have 95% occupancy, Tuesdays only 60%"
Action: Implement weekend pricing strategy
Result: 15% revenue increase
```

---

### Example: Streaming Service Changed from Daily to Session

**Before (Daily Usage):**
```
Problem: "Don't know which content is popular"
Can't answer: "What do users watch after finishing 'Stranger Things'?"
```

**After (Viewing Session):**
```
Solution: Track individual viewing sessions
Now can answer: "80% of users watch 'The Crown' after 'Stranger Things'"
Action: Recommend 'The Crown' to 'Stranger Things' viewers
Result: 25% increase in user engagement
```

---

## Summary: Choosing Grain

### The Three Questions

1. **What business questions do I need to answer?**
   - List them all
   - Rank by importance

2. **What's the atomic business event?**
   - One transaction? One item? One minute?
   - Choose the meaningful unit

3. **Is it practical?**
   - Can you store the data volume?
   - Will queries run fast enough?
   - Can your ETL handle it?

### The Decision Process

```
Start with your business questions
    ↓
Identify the finest grain needed to answer them
    ↓
Check if it's practical (storage, performance)
    ↓
    ├─ Practical? → Use that grain ✅
    └─ Not practical? → Go one level coarser
```

### Remember

- You can always **aggregate UP** (fine → coarse)
- You can **NEVER break DOWN** (coarse → fine)
- **When in doubt, go finer** (easier to aggregate than to add detail later)

---

## Practice Exercise

### Your Turn!

**Scenario: Food Delivery App**

A customer orders food:
- Customer: Lisa
- Restaurant: Burger King
- Date: Jan 12, 2024
- Items ordered:
  - Whopper ($5.99)
  - Fries ($2.99)
  - Coke ($1.99)
- Delivery fee: $3.99
- Total: $14.96
- Driver: John
- Delivery time: 28 minutes

### Question: What grain options could you use?

Think about:
1. One row = One order?
2. One row = One item in order?
3. One row = One delivery?

Which would you choose and why?

---

**Think about it before looking at the answer below!**

---
---
---

### Answer:

**Option A: One Order (Coarsest)**
```
order_id | customer | restaurant  | total_amount | item_count | driver | delivery_time
1001     | Lisa     | Burger King | 14.96       | 3          | John   | 28
```
✅ Good for: Revenue reports, order count
❌ Can't answer: "Which items are popular?"

**Option B: One Order Item (Medium) ⭐**
```
order_id | customer | restaurant  | item_name | item_price | quantity | driver
1001     | Lisa     | Burger King | Whopper  | 5.99      | 1        | John
1001     | Lisa     | Burger King | Fries    | 2.99      | 1        | John
1001     | Lisa     | Burger King | Coke     | 1.99      | 1        | John
```
✅ Good for: Item popularity, restaurant performance, driver efficiency
✅ Can answer ALL business questions
⭐ **Recommended choice!**

**Option C: One Delivery Event (Different focus)**
```
delivery_id | driver | orders_delivered | total_distance | total_time | total_earned
D001        | John   | 5               | 15 miles      | 120 mins   | 45.00
```
✅ Good for: Driver performance, route optimization
❌ Different grain (driver-centric, not order-centric)

---

Good luck with your grain decisions! 🎯