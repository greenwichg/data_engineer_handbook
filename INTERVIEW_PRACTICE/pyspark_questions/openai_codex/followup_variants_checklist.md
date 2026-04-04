# PySpark Interview Follow-up Variants Checklist

## Why this file 

Most interview rounds do not stop at the base problem statement. After a candidate solves the initial question, interviewers usually ask **follow-up variants** to test production readiness, correctness under edge cases, and performance trade-offs.

Use this checklist with each problem file in this folder.

---

## 1) Correctness Follow-ups (always ask)

1. What happens with **null keys** or **null timestamps**?
2. How do you handle **duplicate rows** with conflicting payloads?
3. Is your logic deterministic when there are **tie timestamps**?
4. How do you verify no **double counting** across joins/windows?
5. Which columns define business uniqueness vs technical uniqueness?

---

## 2) Performance Follow-ups

1. Where will this query shuffle and how would you reduce it?
2. What partitioning strategy fits this data shape?
3. Would you use broadcast, salting, bucketing, or AQE here?
4. How do you mitigate skewed keys?
5. How do you detect regressions (Spark UI metrics, stage time, spill)?

---

## 3) Streaming-specific Follow-ups

1. Event time vs processing time: what breaks if you choose wrong?
2. Why this watermark value? What are data-loss vs latency trade-offs?
3. How do you ensure idempotency on retries?
4. What state is kept and when is it cleaned up?
5. How do output modes (`append`, `update`, `complete`) affect sink behavior?

---

## 4) Data Modeling + Table Design Follow-ups

1. Why Type 1 vs Type 2 SCD for this use case?
2. How do you manage schema evolution safely?
3. What should be the partition columns and why?
4. How do you avoid tiny files and optimize read performance?
5. What retention/vacuum policies would you set?

---

## 5) Reliability + Operations Follow-ups

1. How do you rerun/backfill safely without full reprocessing?
2. What checkpoint and recovery strategy do you use?
3. Which data quality gates block publish vs quarantine records?
4. What SLA/SLO and freshness metrics do you publish?
5. How do you alert on silent failures and partial writes?

---

## 6) Interview-ready “Edge Case Add-ons” by topic

### Watermark + Dedup
- Late duplicate arrives beyond watermark.
- Same event_id with updated payload.
- Clock skew across sources.

### CDC Upserts
- Out-of-order `U` after `D`.
- Multiple updates with same `updated_at`.
- Replay of a full CDC batch.

### SCD2 / Backdated corrections
- Correction splits an existing interval into two pieces.
- Multiple backdated updates for same key in one batch.
- End-date overlap validation.

### Range/Interval joins
- Overlapping intervals in dimension table.
- No matching interval.
- Large skew on a few join keys.

### Incremental backfills
- Missing partitions discovered mid-run.
- Backfill overlaps with daily production run.
- Idempotent writes for already-processed partitions.

---

## 7) Scoring rubric for mock interviews

Score each answer 1–5 on:

1. Correctness of transformation logic.
2. Handling of edge cases.
3. Performance reasoning.
4. Reliability/idempotency thinking.
5. Clarity of communication.

**Interpretation**
- **22–25:** Strong senior-level answer.
- **17–21:** Good core solution, needs production depth.
- **12–16:** Works for toy data, lacks scale/reliability perspective.
- **<12:** Requires fundamentals review.

---

## Suggested usage

For each markdown problem in this folder:
1. Solve base statement.
2. Pick 3 correctness follow-ups + 2 performance follow-ups.
3. Add 1 streaming/reliability constraint.
4. Re-solve and explain trade-offs aloud in under 5 minutes.
