Excellent! Let me give you **10 practice problems** with complete framework application, from easy to hard.

---

# **SQL Practice Problems with Framework Application**

## **Problem Difficulty Guide**

```
⭐ Easy (5 min) - Basic SELECT, JOIN, GROUP BY
⭐⭐ Medium (10 min) - Window functions, subqueries
⭐⭐⭐ Hard (15 min) - CTEs, complex logic
⭐⭐⭐⭐ Expert (20+ min) - Recursive, optimization required
```

---

## **PROBLEM 1: Second Highest Salary** ⭐⭐

### **Problem Statement:**
*"Write a query to find the second highest salary from the employees table. If there is no second highest salary, return NULL."*

### **PHASE 1: UNDERSTAND (Apply Framework)**

**Your Questions (speak out loud):**

```
1. "Should I return just the salary value or employee details?"
   → Just the salary value

2. "What if multiple employees have the second highest salary?"
   → Return the salary value once (distinct)

3. "What if there's only one employee or all have same salary?"
   → Return NULL

4. "Should I consider NULL salaries?"
   → Exclude NULLs

5. "Do you want a column named 'SecondHighestSalary'?"
   → Yes
```

**Document Understanding:**

```
Input: employees (emp_id, name, salary)
Output: Single column "SecondHighestSalary"
Logic: Second distinct salary value
Edge Cases:
  - 0 employees → NULL
  - 1 employee → NULL
  - All same salary → NULL
  - Fewer than 2 distinct salaries → NULL
```

---

### **PHASE 2: DESIGN**

**Break into steps:**

```
Step 1: Get distinct salaries
Step 2: Sort descending
Step 3: Skip first (highest)
Step 4: Take next one (second highest)
Step 5: Handle case where it doesn't exist
```

**Visual Design:**

```
employees              Step 1: Distinct     Step 2: Order
┌──────────────┐      ┌──────────┐        ┌──────────┐
│ emp  salary  │      │ salary   │        │ salary   │
│ 1    100     │  →   │ 100      │   →    │ 150      │ ← Highest
│ 2    150     │      │ 150      │        │ 100      │ ← Second
│ 3    100     │      │ 80       │        │ 80       │
│ 4    80      │      └──────────┘        └──────────┘
└──────────────┘              ↓
                     OFFSET 1 LIMIT 1
                              ↓
                         Result: 100
```

---

### **PHASE 3: APPROACH SELECTION**

**Compare approaches:**

```
APPROACH 1: OFFSET/LIMIT
Pros: Simple, direct
Cons: Returns empty set (not NULL) if doesn't exist
Code:
  SELECT DISTINCT salary 
  FROM employees 
  ORDER BY salary DESC 
  OFFSET 1 LIMIT 1;
Rating: ❌ Doesn't handle NULL requirement

APPROACH 2: Subquery with MAX
Pros: Returns NULL naturally
Cons: Two passes through data
Code:
  SELECT MAX(salary) 
  FROM employees 
  WHERE salary < (SELECT MAX(salary) FROM employees);
Rating: ✓ Correct, but inefficient

APPROACH 3: LIMIT with COALESCE
Pros: Handles NULL, efficient
Cons: Slightly more complex
Code:
  SELECT COALESCE(
    (SELECT DISTINCT salary FROM employees 
     ORDER BY salary DESC LIMIT 1 OFFSET 1),
    NULL
  ) as SecondHighestSalary;
Rating: ✓✓ BEST - Correct and efficient

CHOSEN: Approach 3
```

---

### **PHASE 4: CODE (Incremental Build)**

```sql
-- ITERATION 1: Get distinct salaries ordered
SELECT DISTINCT salary
FROM employees
ORDER BY salary DESC;

-- Test: Check if salaries appear in right order
-- Result: 150, 100, 80 ✓

-- ITERATION 2: Get second one
SELECT DISTINCT salary
FROM employees
ORDER BY salary DESC
LIMIT 1 OFFSET 1;

-- Test: Returns 100 ✓
-- Problem: Returns empty set if not exists, not NULL ❌

-- ITERATION 3: Wrap in subquery to get NULL behavior
SELECT (
    SELECT DISTINCT salary
    FROM employees
    ORDER BY salary DESC
    LIMIT 1 OFFSET 1
) as SecondHighestSalary;

-- Test with edge cases:
-- Edge case 1: Only 1 employee → Result: NULL ✓
-- Edge case 2: All same salary → Result: NULL ✓
-- Edge case 3: Normal case → Result: 100 ✓

-- FINAL VERSION (clean it up):
SELECT 
    (SELECT DISTINCT salary
     FROM employees
     ORDER BY salary DESC
     LIMIT 1 OFFSET 1
    ) as SecondHighestSalary;
```

---

### **PHASE 5: TEST & OPTIMIZE**

**Test Cases:**

```sql
-- Test Case 1: Normal case
-- Data: 150, 100, 80
-- Expected: 100 ✓

-- Test Case 2: Duplicates
-- Data: 150, 150, 100, 100, 80
-- Expected: 100 ✓ (DISTINCT handles this)

-- Test Case 3: Only one employee
-- Data: 150
-- Expected: NULL ✓

-- Test Case 4: All same salary
-- Data: 100, 100, 100
-- Expected: NULL ✓

-- Test Case 5: Empty table
-- Data: (empty)
-- Expected: NULL ✓

-- Test Case 6: Two employees same salary
-- Data: 100, 100
-- Expected: NULL ✓
```

**Optimization:**

```
Current: O(n log n) due to sorting
Could optimize: If table is huge, add index on salary
Recommendation: CREATE INDEX idx_salary ON employees(salary DESC);

For this problem: Current solution is optimal
```

**Interview Discussion:**

```
"My solution uses OFFSET and LIMIT which is clean and readable.
The subquery wrapper ensures NULL is returned when there's 
no second highest salary.

For large datasets, I'd recommend an index on salary.

Alternative approach would be using DENSE_RANK():
  SELECT salary FROM (
    SELECT salary, DENSE_RANK() OVER (ORDER BY salary DESC) as rnk
    FROM employees
  ) WHERE rnk = 2

Both work, but LIMIT is simpler for this specific case."
```

---

## **PROBLEM 2: Consecutive Numbers** ⭐⭐⭐

### **Problem Statement:**
*"Find all numbers that appear at least three consecutive times in the Logs table."*

**Schema:**
```sql
Logs table:
+----+-----+
| id | num |
+----+-----+
| 1  | 1   |
| 2  | 1   |
| 3  | 1   |  ← Three consecutive 1's
| 4  | 2   |
| 5  | 1   |
| 6  | 2   |
| 7  | 2   |
+----+-----+
```

### **PHASE 1: UNDERSTAND**

**Your Questions:**

```
1. "By 'consecutive', do you mean consecutive IDs or consecutive rows?"
   → Consecutive IDs (1, 2, 3)

2. "Should I return distinct numbers only?"
   → Yes, distinct

3. "What if a number appears 4+ consecutive times?"
   → Count as qualifying (>=3)

4. "Are there gaps in IDs?"
   → No, IDs are sequential

5. "Output format?"
   → Single column 'ConsecutiveNums'
```

**Document:**

```
Input: Logs (id, num)
Output: Distinct numbers appearing 3+ consecutive times
Consecutive: ID values are sequential (1,2,3 or 5,6,7)
Edge Cases:
  - Number appears exactly 3 times
  - Number appears 4+ times
  - Number appears non-consecutively
```

---

### **PHASE 2: DESIGN**

**Breakdown:**

```
Step 1: For each row, get previous and next num values
Step 2: Check if current = prev AND current = next
Step 3: Collect distinct qualifying numbers

OR (Alternative thinking):

Step 1: Self-join on consecutive IDs
Step 2: Match where num values are same
Step 3: Filter groups of 3+
```

**Visual:**

```
id | num | prev_num | next_num | is_consecutive_3
---|-----|----------|----------|------------------
1  | 1   | NULL     | 1        | ?
2  | 1   | 1        | 1        | ✓ (1=1=1)
3  | 1   | 1        | 2        | ✗ (1≠2)
4  | 2   | 1        | 1        | ✗
5  | 1   | 2        | 2        | ✗
6  | 2   | 1        | 2        | ✗
7  | 2   | 2        | NULL     | ?
```

---

### **PHASE 3: APPROACH SELECTION**

**Compare:**

```
APPROACH 1: Self-join three times
SELECT DISTINCT l1.num
FROM Logs l1
JOIN Logs l2 ON l1.id = l2.id - 1
JOIN Logs l3 ON l1.id = l3.id - 2
WHERE l1.num = l2.num AND l2.num = l3.num;

Pros: Simple logic
Cons: Three table scans
Rating: ⭐⭐

APPROACH 2: Window functions (LAG/LEAD)
SELECT DISTINCT num
FROM (
  SELECT num,
         LAG(num) OVER (ORDER BY id) as prev,
         LEAD(num) OVER (ORDER BY id) as next
  FROM Logs
) sub
WHERE num = prev AND num = next;

Pros: Single table scan, clean
Cons: None
Rating: ⭐⭐⭐ BEST

APPROACH 3: Variables (MySQL specific)
Pros: Can work
Cons: Database-specific, complex
Rating: ⭐

CHOSEN: Window functions (Approach 2)
```

---

### **PHASE 4: CODE (Incremental)**

```sql
-- ITERATION 1: Add window functions to see pattern
SELECT 
    id,
    num,
    LAG(num, 1) OVER (ORDER BY id) as prev_num,
    LEAD(num, 1) OVER (ORDER BY id) as next_num
FROM Logs;

-- Test: Verify prev/next values are correct
-- id=2: prev=1, num=1, next=1 ✓

-- ITERATION 2: Add filtering logic
SELECT 
    id,
    num,
    LAG(num, 1) OVER (ORDER BY id) as prev_num,
    LEAD(num, 1) OVER (ORDER BY id) as next_num
FROM Logs
WHERE num = prev_num AND num = next_num;  -- Can't use in same SELECT!

-- Problem: Can't reference window function in WHERE ❌

-- ITERATION 3: Wrap in subquery
SELECT DISTINCT num as ConsecutiveNums
FROM (
    SELECT 
        num,
        LAG(num, 1) OVER (ORDER BY id) as prev_num,
        LEAD(num, 1) OVER (ORDER BY id) as next_num
    FROM Logs
) temp
WHERE num = prev_num AND num = next_num;

-- Test:
-- Input: 1,1,1,2,1,2,2
-- Expected: 1
-- Result: 1 ✓

-- FINAL VERSION:
SELECT DISTINCT num as ConsecutiveNums
FROM (
    SELECT 
        num,
        LAG(num) OVER (ORDER BY id) as prev_num,
        LEAD(num) OVER (ORDER BY id) as next_num
    FROM Logs
) consecutive_check
WHERE num = prev_num 
  AND num = next_num;
```

---

### **PHASE 5: TEST**

**Test Cases:**

```sql
-- Test 1: Exactly 3 consecutive
INSERT: 1,1,1,2,3
Expected: 1 ✓

-- Test 2: More than 3 consecutive
INSERT: 1,1,1,1,2
Expected: 1 ✓ (all four 1's create multiple matches)

-- Test 3: No consecutive
INSERT: 1,2,3,4
Expected: (empty) ✓

-- Test 4: Multiple numbers qualify
INSERT: 1,1,1,2,2,2,3
Expected: 1, 2 ✓

-- Test 5: Gaps in sequence
-- This is tricky - with gaps in IDs, consecutive means different things
-- Current solution assumes sequential IDs
```

**Optimization:**

```
"For this solution:
- Single pass through data (efficient)
- Window functions handle ordering
- Index on (id) helps: CREATE INDEX idx_id ON Logs(id)

Alternative for very large data:
- Partition if possible
- Consider materialized view if query runs frequently"
```

---

## **PROBLEM 3: Department Top Three Salaries** ⭐⭐⭐

### **Problem Statement:**
*"Find employees who are in the top 3 highest salaries in each department. Return department name, employee name, and salary."*

### **PHASE 1: UNDERSTAND**

**Questions:**

```
1. "What if there are ties - should I include all?"
   → Yes, include all ties

2. "What if a department has fewer than 3 employees?"
   → Show all employees in that department

3. "Should results be sorted?"
   → Yes, by department then salary descending

4. "ROW_NUMBER, RANK, or DENSE_RANK for ties?"
   → DENSE_RANK (explained: 100, 100, 90 all rank in top 3)
```

**Document:**

```
Input: 
  - employees (id, name, salary, dept_id)
  - departments (id, name)
Output: dept_name, emp_name, salary
Logic: Top 3 salaries per dept (DENSE_RANK)
Handle: Ties, departments with <3 employees
```

---

### **PHASE 2: DESIGN**

```
Step 1: Rank employees within each department
Step 2: Filter to rank <= 3
Step 3: Join with departments to get names
Step 4: Order output
```

**Visual:**

```
employees                      After DENSE_RANK
┌─────────────────────────┐   ┌──────────────────────────────┐
│ emp  salary  dept_id    │   │ emp  salary  dept  rank      │
│ 1    90000   10         │   │ 2    95000   10    1         │ ✓
│ 2    95000   10         │   │ 1    90000   10    2         │ ✓
│ 3    85000   10         │   │ 3    85000   10    3         │ ✓
│ 4    80000   10         │   │ 4    80000   10    4         │ ✗
│ 5    70000   20         │   │ 5    70000   20    1         │ ✓
└─────────────────────────┘   └──────────────────────────────┘
```

---

### **PHASE 3: APPROACH**

```
APPROACH 1: Correlated subquery
SELECT d.name, e.name, e.salary
FROM employees e
JOIN departments d ON e.dept_id = d.id
WHERE (
  SELECT COUNT(DISTINCT salary)
  FROM employees e2
  WHERE e2.dept_id = e.dept_id
  AND e2.salary >= e.salary
) <= 3;

Pros: Works
Cons: Slow (N² complexity)
Rating: ⭐

APPROACH 2: Window function DENSE_RANK
SELECT dept_name, emp_name, salary
FROM (
  SELECT 
    d.name as dept_name,
    e.name as emp_name,
    e.salary,
    DENSE_RANK() OVER (PARTITION BY e.dept_id ORDER BY e.salary DESC) as rnk
  FROM employees e
  JOIN departments d ON e.dept_id = d.id
) ranked
WHERE rnk <= 3;

Pros: Single pass, efficient, handles ties
Cons: None
Rating: ⭐⭐⭐ BEST

CHOSEN: Window function
```

---

### **PHASE 4: CODE**

```sql
-- ITERATION 1: Add ranking
SELECT 
    e.name as emp_name,
    e.salary,
    e.dept_id,
    DENSE_RANK() OVER (
        PARTITION BY e.dept_id 
        ORDER BY e.salary DESC
    ) as salary_rank
FROM employees e;

-- Test: Verify ranking is correct per department ✓

-- ITERATION 2: Add department names
SELECT 
    d.name as dept_name,
    e.name as emp_name,
    e.salary,
    DENSE_RANK() OVER (
        PARTITION BY e.dept_id 
        ORDER BY e.salary DESC
    ) as salary_rank
FROM employees e
JOIN departments d ON e.dept_id = d.id;

-- Test: Department names appear ✓

-- ITERATION 3: Wrap and filter
WITH ranked_employees AS (
    SELECT 
        d.name as dept_name,
        e.name as emp_name,
        e.salary,
        DENSE_RANK() OVER (
            PARTITION BY e.dept_id 
            ORDER BY e.salary DESC
        ) as salary_rank
    FROM employees e
    JOIN departments d ON e.dept_id = d.id
)
SELECT 
    dept_name as Department,
    emp_name as Employee,
    salary as Salary
FROM ranked_employees
WHERE salary_rank <= 3
ORDER BY dept_name, salary DESC;

-- Test all edge cases ✓
```

---

### **PHASE 5: TEST**

```sql
-- Test 1: Department with exactly 3 employees
-- All should appear ✓

-- Test 2: Ties at rank 3
-- Dept: Sales, Salaries: 100, 90, 80, 80
-- All 4 should appear (DENSE_RANK handles ties) ✓

-- Test 3: Department with 1 employee
-- That employee should appear ✓

-- Test 4: Different ranking functions
-- DENSE_RANK: 100, 100, 80 → ranks 1,1,2 (all qualify)
-- RANK: 100, 100, 80 → ranks 1,1,3 (all qualify)
-- ROW_NUMBER: 100, 100, 80 → ranks 1,2,3 (arbitrary on ties) ❌
-- Confirmed: DENSE_RANK is correct choice ✓
```

---

## **PROBLEM 4: Active Users** ⭐⭐⭐

### **Problem Statement:**
*"Find users who logged in for 5 or more consecutive days. Return user_id and the start date of their longest streak."*

**Schema:**
```sql
Logins (user_id, login_date)
```

### **COMPLETE FRAMEWORK APPLICATION**

**PHASE 1: UNDERSTAND**

```
Questions:
1. "Should one user appear multiple times if they have multiple 5+ day streaks?"
   → No, just the longest streak

2. "What if there are ties (two streaks of same length)?"
   → Return the most recent one

3. "Are login_dates guaranteed to be unique per user per day?"
   → Yes

4. "Output format?"
   → user_id, streak_start, streak_length

Understanding:
- Need to identify consecutive dates
- Group consecutive dates into streaks
- Find streaks of 5+ days
- Return longest per user
```

**PHASE 2: DESIGN**

```
The Consecutive Dates Trick:
  Date - ROW_NUMBER() = Constant for consecutive dates

Example:
  Date       | ROW_NUM | Date - ROW_NUM | Streak Group
  2024-01-01 | 1       | 2023-12-31     | A
  2024-01-02 | 2       | 2023-12-31     | A (same!)
  2024-01-03 | 3       | 2023-12-31     | A (same!)
  2024-01-05 | 4       | 2024-01-01     | B (gap!)
  2024-01-06 | 5       | 2024-01-01     | B

Steps:
1. Add ROW_NUMBER per user ordered by date
2. Subtract ROW_NUMBER from date → streak_group
3. Group by user_id, streak_group
4. Count days in each streak
5. Filter streaks >= 5 days
6. Get longest per user
```

**PHASE 3: APPROACH**

```
ONLY VIABLE APPROACH: The "Date - ROW_NUMBER" technique
This is the standard pattern for consecutive sequences
```

**PHASE 4: CODE**

```sql
-- ITERATION 1: Add ROW_NUMBER
SELECT 
    user_id,
    login_date,
    ROW_NUMBER() OVER (PARTITION BY user_id ORDER BY login_date) as rn
FROM Logins;

-- ITERATION 2: Create streak groups
SELECT 
    user_id,
    login_date,
    login_date - INTERVAL '1 day' * ROW_NUMBER() OVER (
        PARTITION BY user_id ORDER BY login_date
    ) as streak_group
FROM Logins;

-- Verify: Same streak_group for consecutive dates ✓

-- ITERATION 3: Count streak lengths
WITH numbered_logins AS (
    SELECT 
        user_id,
        login_date,
        login_date - INTERVAL '1 day' * ROW_NUMBER() OVER (
            PARTITION BY user_id ORDER BY login_date
        ) as streak_group
    FROM Logins
)
SELECT 
    user_id,
    streak_group,
    MIN(login_date) as streak_start,
    MAX(login_date) as streak_end,
    COUNT(*) as streak_length
FROM numbered_logins
GROUP BY user_id, streak_group;

-- Test: Verify streaks are counted correctly ✓

-- ITERATION 4: Filter and get longest
WITH numbered_logins AS (
    SELECT 
        user_id,
        login_date,
        login_date - INTERVAL '1 day' * ROW_NUMBER() OVER (
            PARTITION BY user_id ORDER BY login_date
        ) as streak_group
    FROM Logins
),
streak_lengths AS (
    SELECT 
        user_id,
        MIN(login_date) as streak_start,
        COUNT(*) as streak_length
    FROM numbered_logins
    GROUP BY user_id, streak_group
    HAVING COUNT(*) >= 5
),
ranked_streaks AS (
    SELECT 
        user_id,
        streak_start,
        streak_length,
        ROW_NUMBER() OVER (
            PARTITION BY user_id 
            ORDER BY streak_length DESC, streak_start DESC
        ) as rank
    FROM streak_lengths
)
SELECT 
    user_id,
    streak_start,
    streak_length
FROM ranked_streaks
WHERE rank = 1
ORDER BY user_id;
```

**PHASE 5: TEST**

```sql
-- Test 1: User with exactly 5 consecutive days
-- Expected: Should appear ✓

-- Test 2: User with 7 days, then 5 days
-- Expected: Show 7-day streak ✓

-- Test 3: User with 4 consecutive days
-- Expected: Should NOT appear ✓

-- Test 4: Gap in dates
-- 2024-01-01,02,03,05,06,07,08,09
-- Expected: Two streaks (3 days and 5 days), show 5-day ✓
```

---

## **PROBLEM 5: Manager Reporting** ⭐⭐⭐⭐

### **Problem Statement:**
*"Find managers who have at least 5 direct reports. Return manager name and count of reports. Then extend to show full reporting chain for each manager."*

### **COMPLETE FRAMEWORK**

**PHASE 1: UNDERSTAND**

```
Clarifications:
1. "Direct reports only or include indirect?"
   → Part A: Direct only (5+)
   → Part B: Include full chain

2. "What if someone reports to themselves?"
   → Data error, exclude

3. "Multiple levels deep?"
   → Yes, could be 10 levels

4. "Output for Part B?"
   → manager_name, all_reports_count, reporting_tree
```

**PHASE 2: DESIGN**

```
PART A (Simple):
  Step 1: GROUP BY manager_id
  Step 2: COUNT reports
  Step 3: HAVING >= 5
  Step 4: JOIN to get manager name

PART B (Recursive):
  Step 1: Recursive CTE starting from managers
  Step 2: Walk down hierarchy
  Step 3: Count all descendants
  Step 4: Build reporting tree visualization
```

**PHASE 3: APPROACH**

```
PART A: Simple GROUP BY
PART B: Recursive CTE (only option for hierarchical data)
```

**PHASE 4: CODE**

```sql
-- PART A: Managers with 5+ direct reports
SELECT 
    m.name as manager_name,
    COUNT(e.emp_id) as direct_reports
FROM employees e
JOIN employees m ON e.manager_id = m.emp_id
GROUP BY m.emp_id, m.name
HAVING COUNT(e.emp_id) >= 5
ORDER BY direct_reports DESC;

-- PART B: Full reporting chain
WITH RECURSIVE reporting_chain AS (
    -- Anchor: Managers with 5+ direct reports
    SELECT 
        e.emp_id,
        e.name,
        e.manager_id,
        1 as level,
        ARRAY[e.emp_id] as path,
        e.name as tree
    FROM employees e
    WHERE e.emp_id IN (
        SELECT manager_id
        FROM employees
        GROUP BY manager_id
        HAVING COUNT(*) >= 5
    )
    
    UNION ALL
    
    -- Recursive: Get all subordinates
    SELECT 
        e.emp_id,
        e.name,
        e.manager_id,
        rc.level + 1,
        rc.path || e.emp_id,
        rc.tree || ' → ' || e.name
    FROM employees e
    JOIN reporting_chain rc ON e.manager_id = rc.emp_id
    WHERE NOT (e.emp_id = ANY(rc.path))  -- Prevent cycles
      AND rc.level < 10  -- Safety limit
)
SELECT 
    (SELECT name FROM employees WHERE emp_id = 
        (SELECT emp_id FROM reporting_chain WHERE level = 1 LIMIT 1)
    ) as manager_name,
    COUNT(DISTINCT emp_id) as total_reports,
    MAX(level) as org_depth,
    STRING_AGG(DISTINCT tree, E'\n' ORDER BY tree) as reporting_tree
FROM reporting_chain
GROUP BY 
    (SELECT emp_id FROM reporting_chain WHERE level = 1 LIMIT 1);
```

**PHASE 5: TEST**

```sql
-- Test: Manager with 5 direct, 3 indirect
-- Expected: total_reports = 8, depth = 2 ✓

-- Test: Circular reference A→B→A
-- Expected: Cycle detection prevents infinite loop ✓
```

---

I'll continue with 5 more problems, but let me check - would you like me to:

1. **Continue with 5 more problems** (covering: customer churn, running totals, gap detection, user retention, transaction patterns)?
2. **Focus on specific problem types** you find most challenging?
3. **Add a "Common Mistakes" section** for each problem?
4. **Create a quick-reference decision tree** for choosing approaches?

Let me know and I'll continue! These practice problems with framework application are designed to build muscle memory for the UDACT process. 🎯
