# 08 — Prefix Sum

## 1. When to Use
- Many **range queries** over a static (or lightly-mutated) array/string/matrix.
- Keywords: *"sum of subarray from i to j"*, *"range total"*, *"number of subarrays summing to k"*, *"equal counts of 0s and 1s"*, *"subarray divisible by k"*, *"average over range"*, *"range XOR / product"*.
- Immutable input + **many queries** — `O(n)` preprocessing, `O(1)` per query.
- "Count subarrays with property X" where X is a running aggregate (sum / XOR / parity) — pair prefix with a hash map.
- **Sliding window breaks** because values can be negative — prefix sum still works.
- 2D: a matrix with many rectangle-sum or rectangle-count queries.
- Equal-count problems (0s vs 1s, vowels vs consonants, open vs close parens) — map labels to `+1`/`-1` and reuse the sum trick.
- "Minimum / maximum sum subarray of length ≥ k" — prefix sum + monotonic deque.

## 2. Core Idea
Precompute `P[i] = arr[0] + arr[1] + ... + arr[i-1]` once. Then the sum of `arr[l..r]` is `P[r+1] - P[l]` — one subtraction instead of a loop. Pairing prefix sums with a hash map counts subarrays: two indices `i < j` with `P[j] - P[i] == k` represent a subarray summing to `k`, so you only need to count prior prefix values equal to `P[j] - k`.

The conceptual generalisation: prefix sum turns **range queries** into **point queries** (over the prefix array). Any associative monoid with an inverse — addition, XOR, multiplication on non-zero reals — admits a prefix-aggregate. Sort-of inverses like `max` / `min` do not (use a sparse table or segment tree instead).

## 3. Template

### 1D prefix-sum array (range-sum query)
```python
def build_prefix(arr):
    P = [0] * (len(arr) + 1)             # KEY: size n+1 with P[0]=0 as the "empty prefix"; eliminates off-by-one in range_sum
    for i, x in enumerate(arr):
        P[i + 1] = P[i] + x              # P[i+1] = sum(arr[0..i]) inclusive
    return P

def range_sum(P, l, r):                  # sum of arr[l..r], inclusive
    return P[r + 1] - P[l]               # GOTCHA: r+1 not r, because P[r+1] includes arr[r]
```

### Count subarrays with sum = k (LC 560)
```python
from collections import defaultdict

def subarray_sum_equals_k(arr, k):
    count = 0
    running = 0
    seen = defaultdict(int)              # missing keys default to 0 — no KeyError on `seen[x]` lookup
    seen[0] = 1                          # KEY SEED: empty prefix sums to 0; without this, subarrays starting at index 0 are missed
    for x in arr:
        running += x
        count += seen[running - k]       # how many earlier prefix-sums equal (running - k)? Each one bookends a subarray summing to k
        seen[running] += 1               # GOTCHA: increment AFTER the lookup — otherwise a zero-length subarray is counted
    return count
```

### Prefix mod k — subarrays with sum divisible by k (LC 974)
```python
def subarrays_div_by_k(arr, k):
    seen = defaultdict(int)
    seen[0] = 1                          # empty prefix has mod-class 0
    running = 0
    total = 0
    for x in arr:
        running = (running + x) % k      # GOTCHA: Python `%` returns non-negative for positive k (Java/C++ may give negative — add k)
        total += seen[running]           # two prefixes with same mod-class ⇒ their difference is divisible by k
        seen[running] += 1
    return total
```

### 2D prefix sum (LC 304)
```python
def build_2d(mat):
    m, n = len(mat), len(mat[0])
    # GOTCHA: `[[0]*(n+1)]*(m+1)` would share inner lists. Use list comprehension to allocate INDEPENDENT rows.
    P = [[0] * (n + 1) for _ in range(m + 1)]
    for i in range(m):
        for j in range(n):
            # Inclusion-exclusion: top-rect + left-rect - top-left-overlap (counted twice) + this cell
            P[i+1][j+1] = (mat[i][j]
                          + P[i][j+1] + P[i+1][j]
                          - P[i][j])
    return P

def rect_sum(P, r1, c1, r2, c2):
    # Inclusion-exclusion again: full big rect minus top strip minus left strip plus the doubly-subtracted corner
    return (P[r2+1][c2+1] - P[r1][c2+1]
          - P[r2+1][c1] + P[r1][c1])
```

### Difference array — O(1) range-update, O(n) finalise
```python
def range_updates(n, updates):           # updates = [(l, r, inc)]
    diff = [0] * (n + 1)                 # KEY: size n+1 — diff[r+1] -= inc may write to index n (past last element); the extra slot prevents IndexError
    for l, r, inc in updates:
        diff[l] += inc                   # mark "+inc starting at l"
        diff[r + 1] -= inc               # mark "increment ENDS after r" (cancel from r+1 onward)
    out = [0] * n
    out[0] = diff[0]
    for i in range(1, n):
        out[i] = out[i - 1] + diff[i]    # prefix-sum the diff array → recover per-index totals
    return out
```

### Prefix XOR — count subarrays with XOR = k
```python
def subarrays_xor_k(arr, k):
    count = 0; running = 0
    seen = defaultdict(int); seen[0] = 1   # empty prefix has XOR 0
    for x in arr:
        running ^= x                     # `^=` XOR-assign; XOR is its OWN inverse (a ^ a == 0)
        count += seen[running ^ k]       # need earlier prefix p such that p ^ running == k ⇒ p == running ^ k
        seen[running] += 1
    return count
```

### Equal-count trick — map labels to +1 / -1
```python
def longest_equal_01(arr):               # LC 525
    first_seen = {0: -1}                 # KEY SEED: balance 0 at "index -1" — so a prefix [0..i] with balance 0 gives length i - (-1) = i+1
    running = 0; best = 0
    for i, x in enumerate(arr):
        running += 1 if x == 1 else -1   # ternary inside expression; equivalent to: 1 if x==1 else -1
        if running in first_seen:
            best = max(best, i - first_seen[running])   # same balance seen before ⇒ subarray between has equal +/- ⇒ equal 0/1 count
        else:
            first_seen[running] = i      # KEY: only record FIRST occurrence to maximise length (later occurrences give shorter windows)
    return best
```

Key mental tools:
- Always **pad with a leading 0** so `P[r+1] - P[l]` covers inclusive `[l..r]` without off-by-one.
- The seed entry `seen[0] = 1` (or `{0: -1}`) is what lets subarrays starting at index 0 be counted.
- For **equal-count** problems, `+1 / -1` mapping converts "equal count" to "prefix sum == 0".
- For **modular** problems, key the hash map on `running % k`.
- `P` can be computed inline (one running variable) if you only scan left-to-right — you rarely need the full array.

## 4. Classic Problems
- **LC 303 — Range Sum Query — Immutable** (Easy): canonical 1D prefix.
- **LC 560 — Subarray Sum Equals K** (Medium): prefix + hashmap.
- **LC 974 — Subarray Sums Divisible by K** (Medium): prefix mod k.
- **LC 525 — Contiguous Array** (Medium): +1/-1 mapping + earliest-seen.
- **LC 304 — Range Sum Query 2D — Immutable** (Medium): 2D prefix.

## 5. Worked Example — Subarray Sum Equals K (LC 560)
Problem: how many contiguous subarrays of `nums = [1, 2, 3, -2, 2]` sum to `k = 3`?

Brute force is `O(n^2)`. With prefix + hashmap we do it in `O(n)`, **and it works with negative numbers** — where sliding window would fail.

### Key identity
Let `P[j] = nums[0] + ... + nums[j-1]`. Subarray `nums[i..j-1]` sums to `k` iff `P[j] - P[i] == k` iff `P[i] == P[j] - k`. So while scanning `P[j]`, count how many earlier `P[i]` equal `P[j] - k`.

```python
def subarraySum(nums, k):
    seen = {0: 1}                        # SEED: empty prefix sums to 0; needed so subarrays starting at index 0 are countable
    running = 0
    count = 0
    for x in nums:
        running += x
        count += seen.get(running - k, 0)   # `.get(key, 0)` avoids KeyError on missing prefix sums
        seen[running] = seen.get(running, 0) + 1   # GOTCHA: count BEFORE incrementing, else a zero-length subarray gets counted
    return count
```

### Trace with `k = 3`
Enumerate step-by-step; column `complement = running - k`, column `matches = seen[complement]`:

| step | `x` | `running` after | `complement` | `seen` before | `matches` | `count` after | `seen` after |
|---|---|---|---|---|---|---|---|
| 1 | 1 | 1 | -2 | `{0: 1}` | 0 | 0 | `{0: 1, 1: 1}` |
| 2 | 2 | 3 | 0 | `{0: 1, 1: 1}` | 1 | 1 | `{0: 1, 1: 1, 3: 1}` |
| 3 | 3 | 6 | 3 | `{0: 1, 1: 1, 3: 1}` | 1 | 2 | `{0: 1, 1: 1, 3: 1, 6: 1}` |
| 4 | -2 | 4 | 1 | `{..., 6: 1}` | 1 | 3 | add `4: 1` |
| 5 | 2 | 6 | 3 | `{..., 6: 1, 4: 1}` | 1 | 4 | `{..., 6: 2}` |

Final `count = 4`. The four subarrays are:
- step 2: `complement = 0` matched the empty prefix → subarray is `nums[0..1] = [1, 2]` summing to 3. ✓
- step 3: `complement = 3` matched `P[2] = 3` → subarray `nums[2..2] = [3]`. ✓
- step 4: `complement = 1` matched `P[1] = 1` → subarray `nums[1..3] = [2, 3, -2]` summing to 3. ✓
- step 5: `complement = 3` matched `P[2] = 3` → subarray `nums[2..4] = [3, -2, 2]` summing to 3. ✓

Total 4 — correct. Time `O(n)`, space `O(n)`.

### Sliding-window comparison
Try to solve this with a sliding window (grow `r`, shrink `l` while sum > k): on `nums = [1, -1, 1]`, `k = 1`, the window "misses" valid answers because the sum is non-monotone when values can be negative. Prefix sum + hashmap is robust to negatives.

## 6. Common Variations

### 1D sum queries
- **Range sum immutable** (LC 303): single prefix array.
- **Product except self** (LC 238): left-prefix + right-prefix, no division.
- **Number of subarrays with sum = k** (LC 560): prefix + hashmap.
- **Count subarrays with sum in [L, R]** (LC 1292-ish): extend with a sorted list / Fenwick.
- **Find pivot index** (LC 724): prefix[i] == total − prefix[i] − arr[i].

### Modular arithmetic on sums
- **Subarray sums divisible by k** (LC 974): bucket `running % k`.
- **Continuous subarray sum** (LC 523): index-of-first-occurrence of each mod class.
- **Make sum divisible by p** (LC 1590): shortest subarray to remove.

### Equal-count (map labels to ±1)
- **Contiguous array** (LC 525): 0/1 → −1/+1, longest zero-balance window.
- **Longest well-balanced parens**: `(` → +1, `)` → −1.
- **Number of vowels = consonants**: `+1` / `-1` mapping.

### XOR prefix
- **Subarrays with XOR = k**: prefix-XOR + hashmap.
- **Longest subarray with XOR divisible by k**: same trick with mod.
- **Parity / bit-count** problems reduce via XOR.

### Prefix + suffix pass (two-pass combine)
- **Product of array except self** (LC 238): left-product × right-product.
- **Trapping rain water** (LC 42): left-max and right-max arrays; or two-pointer.
- **Candy distribution** (LC 135): two passes (left-to-right, right-to-left).
- **Best time to buy and sell stock III** (LC 123): prefix max profit + suffix max profit.

### 2D prefix sum
- **Range sum 2D immutable** (LC 304): build once, query O(1).
- **Matrix block sum** (LC 1314): 2D prefix + clamp to bounds.
- **Maximum side length of a square with sum ≤ threshold** (LC 1292): 2D prefix + binary-search side.
- **Count submatrices with sum = target** (LC 1074): reduce to 1D LC 560 by fixing row pair.

### Difference array (inverse)
- **Range increments, then read once** (LC 370 / LC 1109): O(1) per update, O(n) final pass.
- **Car pooling** (LC 1094): event-style difference array.
- **Corporate flight bookings** (LC 1109): textbook example.

### Prefix of other aggregates
- **Prefix GCD**: range-GCD by noting `gcd(range) = gcd(prefix_gcd[j], suffix_gcd[i])`. (Or use sparse table.)
- **Prefix OR**: bit accumulation.
- **Prefix max** — does NOT admit the subtraction trick (no inverse); for range-max use sparse table or segment tree.

### Edge cases & pitfalls
- Forgetting the empty-prefix seed (`seen[0] = 1` or `{0: -1}`) — misses subarrays starting at index 0.
- Off-by-one: `P` is length `n + 1`; `range_sum(l, r)` uses `P[r+1] - P[l]`.
- **Integer overflow**: Python fine; Java/C++ use `long`.
- Mutable array + many queries → use Fenwick / BIT instead; plain prefix gets invalidated.
- Negative numbers in a sliding-window solution — switch to prefix-sum.
- Modular arithmetic: Python `%` gives non-negative; other languages may give negatives.

## 7. Related Patterns
- **Sliding Window** — handles contiguous ranges when values are non-negative; prefix-sum generalises to negatives.
- **Hashing** — the partner for "count subarrays with property X".
- **Binary Indexed Tree / Segment Tree** — mutable generalisations of prefix sum.
- **Two Pointers** — competing approach when monotonicity holds.
- **Difference Array** — dual of prefix sum; pick based on whether queries or updates dominate.
- **Monotonic Deque** — used with prefix sums to find shortest subarray with sum ≥ k when negatives are allowed (LC 862).
- **DP** — some DP states look like prefix aggregates; reducing them to prefix sums is a frequent optimisation.

**Distinguishing note**: if you are **reading** many ranges on static data → prefix sum. If you are **writing** many ranges then reading once → difference array. If both happen **online** → Fenwick tree. If values can be negative and you still want subarrays with a property → prefix + hashmap, not sliding window.
