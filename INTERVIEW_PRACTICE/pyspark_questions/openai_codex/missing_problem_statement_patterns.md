# Additional High-Value PySpark Interview Problem Patterns

Below are common interview problem-statement patterns that are still worth adding to this folder.

## 1) Streaming late-arrival handling with watermark + dedup
**Pattern:** Events arrive out of order and duplicated. Build a pipeline that keeps only the latest valid event per key within watermark constraints.

**Why:** Real-time data platforms frequently evaluate understanding of event-time vs processing-time semantics.

## 2) Stateful streaming with `mapGroupsWithState` / `flatMapGroupsWithState`
**Pattern:** Maintain per-user state (e.g., running risk score, inactivity alert, session lifecycle) and emit updates on timeout.

**Why:** This tests deeper Structured Streaming capability beyond basic micro-batch transformations.

## 3) CDC ingestion and idempotent upserts (bronze -> silver)
**Pattern:** Consume insert/update/delete change logs and build an idempotent target table with proper ordering and replay safety.

**Why:** Very common in Delta Lake and lakehouse interviews where reprocessing and correctness are emphasized.

## 4) SCD Type 1 vs Type 2 comparison challenge
**Pattern:** Given the same source change feed, produce both Type 1 (overwrite) and Type 2 (history-preserving) outputs and explain trade-offs.

**Why:** You already have Type 2, but interviewers often ask candidates to contrast both implementations.

## 5) Interval overlap joins at scale (range join optimization)
**Pattern:** Join large event tables to validity intervals (pricing, entitlement, campaign windows), then optimize for skew and shuffle.

**Why:** Tests both correctness and performance engineering.

## 6) Time-series anomaly detection with rolling stats
**Pattern:** Compute rolling mean/std per entity and flag z-score anomalies, then suppress repeated alerts in short windows.

**Why:** A practical extension of rolling-window questions into business monitoring.

## 7) Slowly changing dimensions with late backdated corrections
**Pattern:** Handle updates that arrive today but are effective in the past, including interval splitting and re-closing prior records.

**Why:** Advanced data warehousing edge case that appears in senior DE rounds.

## 8) Incremental backfill strategy problem
**Pattern:** Design a job that backfills historical partitions without reprocessing everything and without breaking downstream SLAs.

**Why:** Distinguishes production-oriented candidates from notebook-only solutions.

## 9) Exactly-once sink semantics across retries
**Pattern:** Write interview scenario where a job can fail and retry; guarantee no duplicates in output using deterministic keys/checkpointing.

**Why:** Reliability and idempotency are heavily tested for batch + streaming pipelines.

## 10) Robust schema evolution and malformed-record rescue
**Pattern:** Input JSON schema evolves frequently; parse known fields, preserve unknown fields, quarantine corrupt records, and continue processing.

**Why:** Common in event platforms and highlights practical resilience design.

---

## Suggested priority order to add next
1. Watermark + dedup in streaming
2. Stateful streaming with timeouts
3. CDC + idempotent upsert
4. SCD backdated correction
5. Incremental backfill design

---

## Additional advanced patterns still worth adding

## 11) Multi-hop streaming join with different watermarks
**Pattern:** Join two or three event streams (e.g., impressions, clicks, conversions) with different event-time delays and watermark policies, then compute attribution metrics.

**Why:** Interviewers use this to test event-time reasoning under realistic ad-tech and product analytics conditions.

## 12) Dynamic sessionization (user/device-specific timeout)
**Pattern:** Instead of one global 30-minute threshold, sessionize with timeout rules that vary by user segment/device/app type.

**Why:** Tests whether candidates can generalize the classic sessionization problem to production complexity.

## 13) Snapshot vs incremental reconciliation framework
**Pattern:** Reconcile a full snapshot table and incremental CDC feed while detecting late deletes, reappearing keys, and drift in counts/checksums.

**Why:** Common in data platform migrations and source-system cutovers.

## 14) Top-K heavy hitters in streaming with bounded state
**Pattern:** Continuously maintain top products/pages/queries per window while keeping memory bounded and handling late events.

**Why:** Combines streaming semantics, approximate methods, and operational constraints.

## 15) Point-in-time feature generation for ML
**Pattern:** Build features with strict point-in-time correctness (no future leakage) from historical event and dimension tables.

**Why:** Frequently asked in ML platform + DE hybrid interviews.

## 16) Slowly changing facts / retroactive fact correction
**Pattern:** Handle corrected fact records (e.g., refunded orders, changed quantities) while preserving auditability and downstream consistency.

**Why:** Distinct from SCD dimensions and often missed by candidates.

## 17) Hierarchical/graph traversal in Spark SQL
**Pattern:** Solve manager trees, bill-of-material explosion, or dependency lineage using iterative joins or GraphFrames.

**Why:** Tests recursive thinking in a framework without native recursive CTE parity in all contexts.

## 18) Data quality gates with quarantine + SLA metrics
**Pattern:** Build rule-based validation (null/range/referential checks), quarantine bad records, and publish DQ metrics as pipeline outputs.

**Why:** Senior interview loops often evaluate reliability and observability, not just transforms.

## 19) Small-file compaction and layout strategy
**Pattern:** Given many tiny files, design compaction/Z-order/partition evolution strategy that improves query performance without massive rewrite cost.

**Why:** Very common in Delta/Lakehouse performance interviews.

## 20) Safe schema evolution in nested semi-structured payloads
**Pattern:** Evolve nested arrays/structs with backward compatibility, defaults, and contract enforcement across bronze/silver/gold layers.

**Why:** Extends basic malformed-record handling into full contract-management design.


## Bonus improvement (recommended)
Beyond adding new problems, add a follow-up-variant checklist so each problem is practiced at production depth (correctness, performance, idempotency, and edge cases).
