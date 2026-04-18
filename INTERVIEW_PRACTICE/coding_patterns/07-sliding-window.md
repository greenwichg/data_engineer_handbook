# 07 — Sliding Window

## 1. When to Use
- You are asked about a **contiguous subarray / substring** of an array or string.
- Keywords: *"longest"*, *"shortest"*, *"smallest"*, *"exactly k"*, *"at most k"*, *"contains all of"*, *"max sum of size k"*.
- A brute force would enumerate every `[i..j]` range — `O(n^2)` — and you need `O(n)`.
- The condition is **monotonic**: once a window becomes invalid by growing, it stays invalid; once valid, shrinking preserves the property until you drop the critical element.
- Window state is cheap to update on add/remove (sum, counter, max via monotonic deque).

## 2. Core Idea
A sliding window maintains a contiguous range `[l, r]` and amortises work across overlapping ranges. Instead of recomputing over each `[i..j]` from scratch, you update incrementally: extend `r` to **grow** the window, advance `l` to **shrink** it until the invariant holds again. Each element enters and leaves at most once → `O(n)` total.

## 3. Template
```python
# Template A — variable-size window with a validity predicate
def shortest_window(arr, is_valid_after_add, on_add, on_remove):
    l = 0
    best = float('inf')
    for r, x in enumerate(arr):
        on_add(x)
        while is_valid():                 # shrink while still valid
            best = min(best, r - l + 1)
            on_remove(arr[l]); l += 1
    return best if best != float('inf') else 0

# Template B — fixed-size window of length k
def max_sum_k(arr, k):
    s = sum(arr[:k])
    best = s
    for r in range(k, len(arr)):
        s += arr[r] - arr[r - k]          # slide by one
        best = max(best, s)
    return best

# Template C — "at most k" trick for counting problems
def subarrays_at_most_k_distinct(arr, k):
    from collections import Counter
    cnt = Counter(); l = 0; total = 0
    for r, x in enumerate(arr):
        cnt[x] += 1
        while len(cnt) > k:
            cnt[arr[l]] -= 1
            if cnt[arr[l]] == 0: del cnt[arr[l]]
            l += 1
        total += r - l + 1                # new subarrays ending at r
    return total
# exactly k  =  atMost(k) - atMost(k-1)
```
Key mental tools:
- State = a small aggregate over `arr[l..r]`: sum, counter, distinct count, max (monotonic deque).
- Always answer: *"what do I add when `r` advances?"* and *"what do I remove when `l` advances?"*
- `exactly k = atMost(k) - atMost(k-1)` converts counting problems with equality to two inequality passes.

## 4. Classic Problems
- **LC 3 — Longest Substring Without Repeating Characters** (Medium): shrink on duplicate.
- **LC 76 — Minimum Window Substring** (Hard): shrink while cover-count holds.
- **LC 209 — Minimum Size Subarray Sum** (Medium): shrink while sum ≥ target.
- **LC 239 — Sliding Window Maximum** (Hard): monotonic deque of indices.
- **LC 904 — Fruit Into Baskets** (Medium): "longest subarray with at most 2 distinct".

## 5. Worked Example — Longest Substring Without Repeating Characters (LC 3)
Problem: given `s = "abcabcbb"`, return the length of the longest substring with all distinct characters.

Approach: sliding window with a `last_seen` dict. When `s[r]` has appeared at some index `≥ l`, jump `l` to `last_seen[s[r]] + 1`.

```python
last_seen = {}
l = 0
best = 0
for r, ch in enumerate(s):
    if ch in last_seen and last_seen[ch] >= l:
        l = last_seen[ch] + 1
    last_seen[ch] = r
    best = max(best, r - l + 1)
```

Step-by-step (window = `s[l..r]`):

| `r` | `ch` | `last_seen` before | `l` before | jump? | `l` after | window | length | `best` |
|---|---|---|---|---|---|---|---|---|
| 0 | a | {} | 0 | no | 0 | `a` | 1 | 1 |
| 1 | b | {a:0} | 0 | no | 0 | `ab` | 2 | 2 |
| 2 | c | {a:0,b:1} | 0 | no | 0 | `abc` | 3 | 3 |
| 3 | a | {a:0,b:1,c:2} | 0 | yes, `l=1` | 1 | `bca` | 3 | 3 |
| 4 | b | {a:3,b:1,c:2} | 1 | yes, `l=2` | 2 | `cab` | 3 | 3 |
| 5 | c | {a:3,b:4,c:2} | 2 | yes, `l=3` | 3 | `abc` | 3 | 3 |
| 6 | b | {a:3,b:4,c:5} | 3 | yes, `l=5` | 5 | `cb` | 2 | 3 |
| 7 | b | {a:3,b:6,c:5} | 5 | yes, `l=7` | 7 | `b` | 1 | 3 |

Answer = `3`. Each character is touched O(1) times → `O(n)` time, `O(min(n, alphabet))` space.

## 6. Common Variations
- **Fixed-size window** (Template B): `max_sum` over size `k`, averages, `k`-distinct counts.
- **At-most-k / exactly-k** (Template C): subarrays with exactly `k` odd numbers (LC 1248), exactly `k` distinct (LC 992).
- **Count-of-needed** (LC 76): use a `need` Counter and a `formed` integer; only shrink when `formed == len(need)`.
- **Monotonic deque**: sliding window max/min in `O(n)` (LC 239).
- **Two pointers vs sliding window**: two pointers converge once; sliding window sweeps forward and may shrink repeatedly.
- **Edge cases**: `k > n`, all same elements, target never reachable (return `0` / `-1` per spec), empty input.

## 7. Related Patterns
- **Two Pointers** — sliding window is a same-direction two-pointer with window *state*.
- **Prefix Sum** — alternative for contiguous-range sums when the window grows both ways or is offline.
- **Hashing** — almost every variable window keeps a Counter/dict as its state.
- **Monotonic Deque / Stack** — sliding max/min, nearest-greater-element.
- **Binary Search on Answer** — when the "is there a window of length L satisfying X?" predicate is monotone in `L`, you can binary-search `L` and check with a window pass.

Distinguishing note: if the problem is about **contiguous** slices and the aggregate updates in `O(1)` per step, it is sliding window. If the slices may be **non-contiguous** (subsequences), it is DP, not windowing.
