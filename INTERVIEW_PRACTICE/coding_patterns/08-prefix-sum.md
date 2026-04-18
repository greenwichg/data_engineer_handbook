# 08 — Prefix Sum

## 1. When to Use
- Many **range queries** over a static (or lightly mutated) array.
- Keywords: *"sum of subarray from i to j"*, *"range total"*, *"number of subarrays summing to k"*, *"equal counts of 0s and 1s"*, *"average over range"*.
- Immutable input + many queries → `O(n)` preprocessing + `O(1)` per query.
- Problem looks like "count subarrays with property X" where X is a running aggregate.
- 2D: a matrix with many rectangle-sum or rectangle-count queries.

## 2. Core Idea
Precompute `P[i] = arr[0] + arr[1] + ... + arr[i-1]`. Then the sum of `arr[l..r]` is `P[r+1] - P[l]` — one subtraction instead of a loop. Pairing prefix sums with a hash map counts subarrays: two indices `i < j` with `P[j] - P[i] == k` represent a subarray summing to `k`, so you just need to count prior prefix values equal to `P[j] - k`.

## 3. Template
```python
# 1) Classic prefix array for range-sum queries
def prefix(arr):
    P = [0] * (len(arr) + 1)
    for i, x in enumerate(arr):
        P[i + 1] = P[i] + x
    return P                      # range sum [l..r] = P[r+1] - P[l]

# 2) Count subarrays summing to k (LC 560)
from collections import defaultdict
def subarraySum(arr, k):
    count = 0
    running = 0
    seen = defaultdict(int)
    seen[0] = 1                   # empty prefix
    for x in arr:
        running += x
        count += seen[running - k]
        seen[running] += 1
    return count

# 3) 2D prefix sum (LC 304)
def build_2d(mat):
    m, n = len(mat), len(mat[0])
    P = [[0] * (n + 1) for _ in range(m + 1)]
    for i in range(m):
        for j in range(n):
            P[i+1][j+1] = mat[i][j] + P[i][j+1] + P[i+1][j] - P[i][j]
    return P
# rect (r1,c1)-(r2,c2) = P[r2+1][c2+1] - P[r1][c2+1] - P[r2+1][c1] + P[r1][c1]
```
Key mental tools:
- Always pad with a leading `0` so that `P[r+1] - P[l]` covers the inclusive range `[l..r]` with no off-by-one.
- The "seed" entry `seen[0] = 1` is what lets a subarray starting at index 0 be counted.
- For **equal-count** problems (0s/1s, vowels/consonants), map one label to `+1` and the other to `-1`, then reuse the hashed-prefix trick.

## 4. Classic Problems
- **LC 303 — Range Sum Query — Immutable** (Easy): canonical 1D prefix.
- **LC 560 — Subarray Sum Equals K** (Medium): prefix + hashmap.
- **LC 974 — Subarray Sums Divisible by K** (Medium): prefix mod `k`.
- **LC 525 — Contiguous Array** (Medium): map 0→-1 then find earliest repeat of prefix.
- **LC 304 — Range Sum Query 2D — Immutable** (Medium): 2D prefix.

## 5. Worked Example — Subarray Sum Equals K (LC 560)
Problem: how many contiguous subarrays of `nums = [1, 2, 3, -2, 2]` sum to `k = 3`?

Brute force is `O(n^2)`. With prefix + hashmap we do it in `O(n)`.

Idea: let `P[j] = nums[0] + ... + nums[j-1]` be the running prefix. A subarray `nums[i..j-1]` sums to `k` iff `P[j] - P[i] == k` iff `P[i] == P[j] - k`. So while scanning `P[j]`, count how many earlier `P[i]` equal `P[j] - k`.

```python
seen = {0: 1}    # empty prefix count = 1
running = 0
count = 0
for x in nums:
    running += x
    count += seen.get(running - k, 0)
    seen[running] = seen.get(running, 0) + 1
```

Trace with `k = 3`:

| `x` | `running` after | `running - k` | `seen` before | matches found | `count` | `seen` after |
|---|---|---|---|---|---|---|
| 1 | 1 | -2 | `{0:1}` | 0 | 0 | `{0:1, 1:1}` |
| 2 | 3 | 0 | `{0:1, 1:1}` | 1 (match `P=0`) | 1 | `{0:1, 1:1, 3:1}` |
| 3 | 6 | 3 | `{0:1, 1:1, 3:1}` | 1 (match `P=3`) | 2 | `{0:1, 1:1, 3:1, 6:1}` |
| -2 | 4 | 1 | `{0:1, 1:1, 3:1, 6:1}` | 1 (match `P=1`) | 3 | add `4:1` |
| 2 | 6 | 3 | `{..., 6:1}` | 1 (match `P=3`) | 4 | `{..., 6:2}` |

Final count `= 4`. The four subarrays are `[1,2]`, `[3]`, `[1,2,3,-2,2]`? Let's verify:
- indices [0..1] = `1+2 = 3` ✓
- indices [2..2] = `3` ✓
- indices [2..4] = `3-2+2 = 3` ✓
- indices [0..4] = `1+2+3-2+2 = 6` ✗ ... actually the fourth is [0..4] which is 6, so which four? Let me re-enumerate:
  - [0..1] `1+2=3`
  - [2..2] `3`
  - [2..4] `3-2+2=3`
  - [3..4] `-2+2=0` ✗
  - full [0..4] `=6` ✗
- Fourth comes from the final step (matching `P=3`): when running became 6 again at index 4 (prefix length 5), there were two earlier prefixes equal to `6 - 3 = 3` — those are `P[2]=3` (prefix of first two elements) and `P[5]=6`? No — the earlier `P = 3` entries were `P[2]` and... actually `seen[3] = 1` at that step. Let me retrace which *pairs*:
  - pair `(P[0]=0, P[2]=3)` → subarray indices [0..1] = `[1,2]` ✓
  - pair `(P[0]=0, P[?]=3)` via later 3: running was 3 after element index 1, i.e. prefix `P[2]`. That matched earlier `P[0]=0`.
  - When `running = 6` the first time (after index 2), `running - k = 3` matched `P[2]=3` → subarray [2..2] = `[3]`.
  - When `running = 4` (after index 3), `running - k = 1` matched `P[1]=1` → subarray [1..3] = `[2,3,-2]` ✓.
  - When `running = 6` the second time (after index 4), `running - k = 3` matched `P[2]=3` → subarray [2..4] = `[3,-2,2]` ✓.

So the four subarrays are `[1,2]`, `[3]`, `[2,3,-2]`, `[3,-2,2]`. Time `O(n)`, space `O(n)`.

## 6. Common Variations
- **Prefix XOR**: same trick, `XOR` replacing `+` for parity / equal-XOR problems.
- **Prefix product / prefix max / prefix GCD**: use a monoid other than addition.
- **Prefix + suffix pass** (LC 238, LC 42): compute left-pass and right-pass aggregates, combine at each index.
- **Difference array**: the inverse — `O(1)` range updates, `O(n)` final read (event counting, range increment).
- **Prefix modulo k**: count subarrays with sum divisible by `k` by bucketing `running % k`.
- **Fenwick / BIT**: when the array mutates between queries, swap flat prefix for a tree.
- **Edge cases**: negative numbers (window techniques break, prefix still works), empty subarrays, overflow in large-sum languages.

## 7. Related Patterns
- **Sliding Window** — handles contiguous ranges when values are non-negative; prefix-sum generalises to negatives.
- **Hashing** — the usual partner for "count subarrays with property X".
- **Binary Indexed Tree / Segment Tree** — generalise prefix sum to mutable data.
- **Two Pointers** — competing approach when monotonicity is available.
- **Difference Array** — dual of prefix sum; pick based on whether queries or updates dominate.

Distinguishing note: if you are **reading** many ranges on static data → prefix sum. If you are **writing** many ranges then reading once → difference array. If both happen online → Fenwick tree.
