# 09 — Binary Search

## 1. When to Use
- Input is **sorted** or has a **monotonic predicate** (`False...False, True...True`).
- Keywords: *"sorted"*, *"find target"*, *"first/last occurrence"*, *"minimum X such that..."*, *"maximum X such that..."*, *"search in rotated"*, *"peak element"*, *"nearest"*, *"ceiling / floor"*.
- Input size is huge (`n <= 10^9`, `n <= 10^18`) — `O(log n)` is the only option.
- You can **binary-search on the answer**: pose a feasibility question `is it possible to X with parameter m?`, prove the answer is monotone in `m`, and binary search on `m`.
- A linear scan would pass but barely — `O(n log n)` via sort + binary search may still be faster than `O(n)` if inputs are small and constants matter.
- Problem shape: *"given a monotone cost function, find the smallest / largest argument that satisfies the budget."*
- Float-valued problems asking for a value to a given tolerance.

### Monotonicity is everything
The **only** requirement is that your predicate `check(x)` is monotone: there is a boundary `m` such that `check(x) == False` for `x < m` and `check(x) == True` for `x >= m` (or vice versa). Without monotonicity, binary search is unjustified and will silently return wrong answers.

## 2. Core Idea
Repeatedly halve the search space using a single bit of information per probe. Any problem reducible to "given `x`, is the answer `≤ x` or `> x`?" with a monotone truth value can be solved in `O(log range)`. The classical difficulty is not the mechanic — it is writing the template correctly (no off-by-ones, no infinite loops) and identifying the hidden monotonicity in non-obvious problems.

Two templates cover 95% of problems: the **exact-target** template (find `x` equal to target or return -1) and the **leftmost-True** template (find the first index where a predicate becomes True, which equals Python's `bisect_left`). The leftmost-True template subsumes upper/lower bound, first-bad-version, and all "binary search on answer" problems.

## 3. Template

### Template A — exact target in a sorted array
```python
def find(arr, target):
    lo, hi = 0, len(arr) - 1             # both ENDS INCLUSIVE — choose convention and stick to it
    while lo <= hi:                       # `<=` matches the inclusive convention. Half-open uses `<`
        mid = (lo + hi) // 2              # GOTCHA in C++/Java: overflow risk → use `lo + (hi - lo) // 2`. Python ints don't overflow.
        if arr[mid] == target:
            return mid
        elif arr[mid] < target:
            lo = mid + 1                  # KEY: `mid + 1` (not `mid`) — must SHRINK the range or you loop forever
        else:
            hi = mid - 1                  # symmetric: `mid - 1`
    return -1
```

### Template B — leftmost-True (bisect_left style, half-open)
```python
def lower_bound(arr, is_ok):
    """Smallest i in [0, n] where is_ok(arr[i]) is True.
    If no such i exists, returns len(arr)."""
    lo, hi = 0, len(arr)                  # HALF-OPEN: hi = past-the-end. Compare with Template A's inclusive convention.
    while lo < hi:                        # `<` (strict) for half-open
        mid = (lo + hi) // 2              # `mid` is always in [lo, hi); never equals hi (so safe to set hi = mid)
        if is_ok(arr[mid]):
            hi = mid                      # KEEP mid (it might be the answer); narrow to left half [lo, mid)
        else:
            lo = mid + 1                  # discard mid (False predicate); next candidate is mid+1
    return lo                             # `lo == hi` at exit; this is the boundary
```

### Template C — binary search on the answer
```python
def min_feasible(lo, hi, feasible):
    """feasible(x) is False...False, True...True. Find smallest x with True.
    lo must be infeasible-or-feasible, hi must be feasible."""
    # CRITICAL: hi MUST satisfy feasible(hi)==True, otherwise the loop returns hi but the answer doesn't exist.
    # Choose hi as a provably-large bound (e.g., max(piles), sum(weights), 10**18).
    while lo < hi:
        mid = (lo + hi) // 2
        if feasible(mid):
            hi = mid                      # mid works; try smaller
        else:
            lo = mid + 1                  # mid fails; smallest viable is at least mid+1
    return lo                             # `lo == hi` at exit = smallest feasible value
```

### Template D — rotated sorted array
```python
def search_rotated(arr, target):
    lo, hi = 0, len(arr) - 1
    while lo <= hi:
        mid = (lo + hi) // 2
        if arr[mid] == target:
            return mid
        # KEY INSIGHT: at least one half [lo..mid] or [mid..hi] is fully sorted (rotation point lies in the OTHER half)
        if arr[lo] <= arr[mid]:           # left half [lo..mid] is sorted (no rotation pivot here)
            # Python chained compare: `a <= b < c` is `a <= b and b < c` — works on numbers
            if arr[lo] <= target < arr[mid]:
                hi = mid - 1              # target lies in the sorted left half
            else:
                lo = mid + 1              # target must be in the right half
        else:                             # right half [mid..hi] is sorted
            if arr[mid] < target <= arr[hi]:
                lo = mid + 1
            else:
                hi = mid - 1
    return -1
```

### Template E — float binary search (fixed-iteration)
```python
def find_root(f, lo, hi, iters=100):
    """f is monotone. Find x with f(x) approximately 0."""
    # KEY: use FIXED iteration count (not `lo < hi`) for floats — float subtraction never reaches exact zero
    # 100 iters halves the range 100 times → 2^-100 precision (way more than float64 can represent)
    for _ in range(iters):
        mid = (lo + hi) / 2               # `/` is float division (`//` would give int floor)
        if f(mid) > 0:
            hi = mid                      # NOT `mid - eps` — for floats we just keep narrowing, no off-by-one risk
        else:
            lo = mid
    return (lo + hi) / 2                  # return midpoint of final tight range
```

Key mental tools:
- **Never write `mid = (lo + hi) // 2` in C++/Java** without caring about overflow — use `lo + (hi - lo) // 2`.
- Prefer the **half-open** template (`hi = len(arr)`) for "first True" — fewer off-by-one bugs.
- Prove **termination**: each iteration must strictly shrink `[lo, hi)`, or shrink `(lo, hi)` by at least one.
- When the answer lives in a **range of integers**, binary-search on that range even if the array is not the search space.
- `bisect_left(arr, x)` = first index where `arr[i] >= x`; `bisect_right(arr, x)` = first index where `arr[i] > x`.

### Template choice cheat sheet
| Need | Template |
|---|---|
| Is target in the array? | A |
| First index where `arr[i] >= x` | B with `is_ok = lambda v: v >= x` |
| First index where `arr[i] > x` | B with `is_ok = lambda v: v > x` |
| Smallest `m` such that `check(m)` is True | C |
| Search in rotated sorted | D |
| Real-valued continuous | E |

## 4. Classic Problems
- **LC 704 — Binary Search** (Easy): textbook Template A.
- **LC 33 — Search in Rotated Sorted Array** (Medium): Template D.
- **LC 34 — First and Last Position of Element** (Medium): two `lower_bound` calls.
- **LC 875 — Koko Eating Bananas** (Medium): binary search on eating speed.
- **LC 4 — Median of Two Sorted Arrays** (Hard): binary search on partition index.

## 5. Worked Example — Koko Eating Bananas (LC 875)
Problem: `piles = [3, 6, 7, 11]`, `h = 8` hours. Find the **minimum eating speed `k`** (bananas/hour) so Koko finishes every pile within `h` hours.

### Step 1. Identify monotonicity
Define `hours_needed(k) = sum(ceil(p/k) for p in piles)`. As `k` increases, `hours_needed(k)` **monotonically decreases**. So the predicate `feasible(k) := hours_needed(k) <= h` is `False...False, True...True`. We want the **smallest** `k` with `feasible(k) == True` — Template C.

### Step 2. Bound the search space
- Smallest sensible `k` is `1` (eat one banana per hour).
- Largest sensible `k` is `max(piles)` — eating faster never finishes sooner (can't eat from two piles in the same hour).
- So `k ∈ [1, max(piles)] = [1, 11]`.

### Step 3. Implement

```python
from math import ceil

def minEatingSpeed(piles, h):
    def feasible(k):
        # GOTCHA: `p / k` is float division ⇒ ceil works correctly. Pure-int alternative: `(p + k - 1) // k` (avoids float)
        return sum(ceil(p / k) for p in piles) <= h

    lo, hi = 1, max(piles)                # hi = max(piles): eating faster never helps (can't split hours across piles)
    while lo < hi:                        # half-open style: at exit lo == hi == answer
        mid = (lo + hi) // 2
        if feasible(mid):
            hi = mid                      # KEEP mid as a candidate; look smaller
        else:
            lo = mid + 1                  # discard mid (too slow) and everything below
    return lo
```

### Step 4. Trace with `piles = [3, 6, 7, 11]`, `h = 8`

| step | `lo` | `hi` | `mid` | hours at mid | feasible? | new `[lo, hi)` |
|---|---|---|---|---|---|---|
| 1 | 1 | 11 | 6 | `⌈3/6⌉+⌈6/6⌉+⌈7/6⌉+⌈11/6⌉ = 1+1+2+2 = 6` | 6 ≤ 8 ✓ | `[1, 6]` |
| 2 | 1 | 6 | 3 | `1+2+3+4 = 10` | 10 ≤ 8 ✗ | `[4, 6]` |
| 3 | 4 | 6 | 5 | `1+2+2+3 = 8` | 8 ≤ 8 ✓ | `[4, 5]` |
| 4 | 4 | 5 | 4 | `1+2+2+3 = 8` | 8 ≤ 8 ✓ | `[4, 4]` |
| stop | 4 | 4 | — | — | — | return `4` |

Answer: `k = 4`. Sanity check: `k=4` → `⌈3/4⌉=1, ⌈6/4⌉=2, ⌈7/4⌉=2, ⌈11/4⌉=3`, total = 8 ≤ 8 ✓. `k=3` → `1+2+3+4=10 > 8` ✗. So 4 is indeed the minimum.

Time: `O(n · log(max(piles)))` — `log(max(piles))` iterations, each computing `hours_needed` in `O(n)`. Space `O(1)`.

The whole pattern hinges on a **monotone predicate**. If `feasible` is not monotone, Template C returns garbage silently — always justify monotonicity before trusting binary search.

## 6. Common Variations

### Exact search on sorted arrays
- **Binary search** (LC 704): Template A.
- **First / last position of element** (LC 34): two bisect calls.
- **Search insert position** (LC 35): `lower_bound(arr, target)`.
- **Count occurrences**: `upper_bound(target) - lower_bound(target)`.

### Rotated / partially-sorted
- **Search in rotated sorted array** (LC 33): one half is always sorted.
- **Search in rotated sorted array II** (LC 81): with duplicates; worst case degrades to O(n).
- **Find minimum in rotated sorted array** (LC 153): binary search on `arr[mid] vs arr[hi]`.
- **Find peak element** (LC 162): climb toward the larger neighbour.

### 2D matrices
- **Search 2D matrix** (LC 74): flatten to `mid // n, mid % n`.
- **Search 2D matrix II** (LC 240): staircase search from corner — not strictly binary search, but related.
- **Kth smallest in sorted matrix** (LC 378): binary search on value + count ≤ value.

### Binary search on the answer
- **Koko eating bananas** (LC 875): min speed.
- **Capacity to ship in D days** (LC 1011): min capacity.
- **Split array largest sum** (LC 410): min largest partition sum.
- **Minimize max distance to gas station** (LC 774): float binary search.
- **Divide chocolate** (LC 1231): max min-piece sweetness.
- **Minimum days to make m bouquets** (LC 1482): min days.
- **Find the smallest divisor given a threshold** (LC 1283).

### Float / continuous binary search
- **Sqrt(x)** (LC 69): integer sqrt via binary search.
- **Median of two sorted arrays** (LC 4): binary search on partition point.
- **Aggressive cows / minimum maximum** problems.

### Lower/upper bound library usage
- **Longest increasing subsequence** (LC 300): patience-sort with `bisect_left` — O(n log n).
- **Russian doll envelopes** (LC 354): sort + LIS on heights.
- **Find K closest elements** (LC 658): binary search the left edge of the window.

### Peak / valley finding
- **Find peak element** (LC 162): compare `arr[mid]` to `arr[mid+1]`.
- **Valid perfect square** (LC 367): binary search on √x.
- **Guess number higher or lower** (LC 374): interactive binary search.

### Edge cases & pitfalls
- **Off-by-one**: `hi = len(arr)` (half-open) vs `hi = len(arr) - 1` (inclusive). Stick to one template.
- **Infinite loop** when `mid = lo` and you set `lo = mid` — always `lo = mid + 1` when discarding mid.
- **Integer overflow**: use `lo + (hi - lo) // 2` in languages without bignum.
- **Equality handling** with duplicates: choose `lower_bound` vs `upper_bound` deliberately.
- **Predicate not monotone** — binary search returns a meaningless answer; validate with brute force on small inputs.
- **Float precision**: use a fixed number of iterations (60–100) instead of `lo < hi`; compare to an epsilon if needed.
- **Empty input**: return -1 / appropriate sentinel before entering the loop.

## 7. Related Patterns
- **Sorting** — often the prerequisite; sometimes the search happens over an **implicit** sorted space (a monotone predicate).
- **Two Pointers** — alternative on sorted arrays; converges from outside rather than halving.
- **Prefix Sum** — often paired with binary search over prefix values (e.g. LC 862, shortest subarray with sum ≥ k via sorted prefix structure).
- **Greedy / Feasibility Check** — the inner `feasible(x)` in "binary search on the answer" is usually a greedy scan.
- **Heap** — merging sorted streams sometimes needs both (median of k streams).
- **Dynamic Programming** — LIS's `O(n log n)` version embeds a binary search inside each DP transition.
- **Monotonic Deque / Stack** — alternatives when you need more than a bit of info per probe.

**Distinguishing note**: if you find yourself writing `for k in range(lo, hi): if works(k): return k`, replace it with binary search on `k` — provided `works` is monotone. If `works` is not monotone, the problem is not a binary-search problem; look for structure that makes it one (sort a key, flip a condition).
