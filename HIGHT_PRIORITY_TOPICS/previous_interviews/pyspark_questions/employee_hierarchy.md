## Employee Hierarchy Query

### SQL Query

```sql
WITH RECURSIVE EmployeeHierarchy AS (
    -- Base case: Top-level employees (no manager)
    SELECT 
        id, 
        employee_name, 
        manager_id, 
        0 AS level
    FROM employees
    WHERE manager_id IS NULL
    
    UNION ALL
    
    -- Recursive case: Find employees who report to current level
    SELECT 
        e.id, 
        e.employee_name, 
        e.manager_id, 
        eh.level + 1
    FROM employees e
    INNER JOIN EmployeeHierarchy eh ON e.manager_id = eh.id
)
SELECT * 
FROM EmployeeHierarchy
ORDER BY level, id;


Result

|id|employee_name|manager_id|level|
|--|-------------|----------|-----|
|1 |Alice        |NULL      |0    |
|2 |Bob          |1         |1    |
|3 |Charlie      |1         |1    |
|4 |Diana        |2         |2    |
|5 |Eve          |2         |2    |
|6 |Frank        |3         |2    |

Organizational Chart

         Alice (1)               ← Level 0 (CEO)
         /      \
        /        \
    Bob (2)    Charlie (3)       ← Level 1
    /    \          \
   /      \          \
Diana (4) Eve (5)   Frank (6)    ← Level 2

```

---

**Key Changes:**
1. ✅ Added proper SQL code block with syntax highlighting
2. ✅ Formatted result as a markdown table with proper alignment
3. ✅ Added section headers for clarity
4. ✅ Added organizational chart visualization
5. ✅ Properly indented the SQL code for readability

Would you like me to add this formatted version to your existing markdown file?​​​​​​​​​​​​​​​​

---
