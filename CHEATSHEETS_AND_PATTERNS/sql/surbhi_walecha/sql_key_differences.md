# SQL Must Know Differences

## 🔰 RANK vs DENSE_RANK

**RANK:** Provides a ranking with gaps if there are ties.

**DENSE_RANK:** Provides a ranking without gaps, even in the case of ties.

## 🔰 HAVING vs WHERE Clause

**WHERE:** Filters rows before grouping.

**HAVING:** Filters groups after the GROUP BY clause.

## 🔰 UNION vs UNION ALL

**UNION:** Removes duplicates and combines results.

**UNION ALL:** Combines results without removing duplicates.

## 🔰 JOIN vs UNION

**JOIN:** Combines columns from multiple tables.

**UNION:** Combines rows from multiple tables with similar structure.

## 🔰 DELETE vs DROP vs TRUNCATE

**DELETE:** Removes rows, with the option to filter.

**DROP:** Removes the entire table or database.

**TRUNCATE:** Deletes all rows but keeps the table structure.

## 🔰 CTE vs TEMP TABLE

**CTE:** Temporary result set used within a single query.

**TEMP TABLE:** Physical temporary table that persists for the session.

## 🔰 SUBQUERIES vs CTE

**SUBQUERIES:** Nested queries inside the main query.

**CTE:** Can be more readable and used multiple times in a query.

## 🔰 ISNULL vs COALESCE

**ISNULL:** Replaces NULL with a specified value, accepts two parameters.

**COALESCE:** Returns the first non-NULL value from a list of expressions, accepting multiple parameters.

## 🔰 INTERSECT vs INNER JOIN

**INTERSECT:** Returns common rows from two queries.

**INNER JOIN:** Combines matching rows from two tables based on a condition.

## 🔰 EXCEPT vs NOT IN

**EXCEPT:** Returns rows in the first query but not in the second.

**NOT IN:** Filters rows where a column's value is not in a given list.