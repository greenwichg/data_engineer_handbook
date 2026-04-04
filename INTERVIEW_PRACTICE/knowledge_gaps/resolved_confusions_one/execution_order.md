# Complete SQL Query Execution Order

This guide explains the **full logical order** that SQL processes queries, step by step.

## The Complete Order

```sql
SELECT column_list
FROM table_name
JOIN other_table ON condition
WHERE row_filter
GROUP BY grouping_columns
HAVING group_filter
ORDER BY sorting_columns
LIMIT number
```

**Actual execution order:**

1. **FROM** - Get the table(s)
2. **JOIN** - Combine tables if needed
3. **WHERE** - Filter individual rows
4. **GROUP BY** - Group rows together
5. **HAVING** - Filter groups
6. **SELECT** - Pick and calculate columns
7. **DISTINCT** - Remove duplicates
8. **ORDER BY** - Sort the results
9. **LIMIT/OFFSET** - Take only some rows

---

## Step-by-Step Example

Let's use this employees table:

| id | name  | department | salary |
|----|-------|------------|--------|
| 1  | Alice | Sales      | 60000  |
| 2  | Bob   | Sales      | 40000  |
| 3  | Carol | IT         | 70000  |
| 4  | Dave  | IT         | 80000  |
| 5  | Eve   | Sales      | 45000  |

### Query:
```sql
SELECT department, AVG(salary) AS avg_salary
FROM employees
WHERE salary > 40000
GROUP BY department
HAVING AVG(salary) > 50000
ORDER BY avg_salary DESC
LIMIT 1
```

### Execution Steps:

#### 1. FROM employees
Start with all 5 rows

#### 2. WHERE salary > 40000
Filter out Bob (40000). Remaining: Alice, Carol, Dave, Eve

| name  | department | salary |
|-------|------------|--------|
| Alice | Sales      | 60000  |
| Carol | IT         | 70000  |
| Dave  | IT         | 80000  |
| Eve   | Sales      | 45000  |

#### 3. GROUP BY department
Group rows by department:
- Sales group: Alice (60000), Eve (45000)
- IT group: Carol (70000), Dave (80000)

#### 4. HAVING AVG(salary) > 50000
Calculate average for each group:
- Sales: (60000 + 45000) / 2 = 52500 ✓
- IT: (70000 + 80000) / 2 = 75000 ✓
- Both groups pass the filter

#### 5. SELECT department, AVG(salary) AS avg_salary
Now create the final columns

| department | avg_salary |
|------------|------------|
| Sales      | 52500      |
| IT         | 75000      |

#### 6. ORDER BY avg_salary DESC
Sort by average salary, highest first

| department | avg_salary |
|------------|------------|
| IT         | 75000      |
| Sales      | 52500      |

#### 7. LIMIT 1
Take only the first row

**Final Result:**

| department | avg_salary |
|------------|------------|
| IT         | 75000      |

---

## Key Differences: WHERE vs HAVING

**WHERE** filters individual rows (before grouping):
```sql
WHERE salary > 40000  -- Filters individual employees
```

**HAVING** filters groups (after grouping):
```sql
HAVING AVG(salary) > 50000  -- Filters entire departments
```

---

## Important Rules

### ❌ Cannot reference SELECT aliases in WHERE:
```sql
SELECT salary * 2 AS double_sal
WHERE double_sal > 100000  -- ERROR! double_sal doesn't exist yet
```

### ✓ Can reference SELECT aliases in ORDER BY:
```sql
SELECT salary * 2 AS double_sal
ORDER BY double_sal  -- Works! ORDER BY comes after SELECT
```

### ❌ Cannot use aggregate functions in WHERE:
```sql
WHERE AVG(salary) > 50000  -- ERROR! Use HAVING instead
```

### ✓ Can use aggregate functions in HAVING:
```sql
HAVING AVG(salary) > 50000  -- Works!
```

---

## Quick Reference Table

| Clause | Purpose | When It Runs |
|--------|---------|--------------|
| FROM | Get table | First |
| JOIN | Combine tables | 2nd |
| WHERE | Filter rows | 3rd (before grouping) |
| GROUP BY | Make groups | 4th |
| HAVING | Filter groups | 5th (after grouping) |
| SELECT | Pick columns | 6th |
| DISTINCT | Remove duplicates | 7th |
| ORDER BY | Sort results | 8th |
| LIMIT | Limit rows | Last |

---

## Summary

The key takeaway is that **WHERE filters rows FIRST, then SELECT picks what to show**. Understanding this execution order helps you:

- Write correct queries
- Understand why certain syntax works or fails
- Optimize query performance
- Use the right clause for filtering (WHERE for rows, HAVING for groups)
