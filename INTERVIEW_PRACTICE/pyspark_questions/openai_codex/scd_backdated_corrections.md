# PySpark Implementation: SCD Type 2 with Backdated Corrections

## Problem Statement 

Dimension updates can arrive late with past effective dates. Update SCD2 history by splitting affected intervals and preserving correct validity windows.

### Example Scenario

Current history for customer `101`:
- NYC valid `2025-01-01` to `9999-12-31`

Late correction arrives:
- Boston effective from `2025-01-20`

Expected SCD2 result:
- NYC `2025-01-01` to `2025-01-19`
- Boston `2025-01-20` to `9999-12-31`

---

## PySpark Strategy

```python
# 1) Locate current record where start_date <= correction_date <= end_date
# 2) Close existing row at correction_date - 1 day
# 3) Insert corrected row from correction_date to old end_date
# 4) Recompute is_current flags
```

Use Delta `MERGE` with staged rows (one row to expire old interval, one row to insert new interval).
