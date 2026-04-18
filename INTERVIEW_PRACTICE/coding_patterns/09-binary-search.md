# 09 — Binary Search

## 1. When to Use
- Input is **sorted** or has a **monotonic predicate** (`False...False, True...True`).
- Keywords: *"sorted"*, *"find target"*, *"first/last occurrence"*, *"minimum X such that..."*, *"maximum X such that..."*, *"search in rotated"*, *"peak element"*.
- Input size is huge (`n <= 10^18`): `O(log n)` is the only option.
- You can **binary-search on the answer**: define a candidate answer and check feasibility in `O(n)`.
- The cost function of a decision is **monotone** in a parameter (capacity, speed, days, threshold).

## 2. Core Idea
Repeatedly halve the search space using a single bit of information per probe. Any problem reducible to "given `x`, is the answer `≤ x` or `> x`?" with a monotone truth value can be solved in `O(log range)`. The trick in non-classic problems is noticing the hidden monotonicity and writing `check(x)`.

## 3. Template
```python
# Template A — find exact target in a sorted array
def find(arr, target):
    lo, hi = 0, len(arr) - 1
    while lo <= hi:
        mid = (lo + hi) // 2
        if arr[mid] == target:
            return mid
        elif arr[mid] < target:
            lo = mid + 1
        else:
            hi = mid - 1
    return -1

# Template B — leftmost index satisfying predicate True (bisect_left style)
def lower_bound(arr, is_ok):
    lo, hi = 0, len(arr)          # half-open; hi is "past the end"
    while lo < hi:
        mid = (lo + hi) // 2
        if is_ok(arr[mid]):
            hi = mid              # keep mid as a candidate
        else:
            lo = mid + 1          # discard mid
    return lo                     # first True, or len(arr) if none

# Template C — binary search on the answer
def min_feasible(lo, hi, feasible):
    # feasible(x) is False...False, True...True; want smallest x with True.
    while lo < hi:
        mid = (lo + hi) // 2
        if feasible(mid):
            hi = mid
        else:
            lo = mid + 1
    return lo
```
Key mental tools:
- Always write `mid = lo + (hi - lo) // 2` in languages where `lo + hi` can overflow.
- Favour the **half-open** template (`hi = len(arr)`) for "first True" — fewer off-by-one bugs.
- Prove termination: each iteration must strictly shrink `[lo, hi)`.
- `bisect_left` = first index where `arr[i] >= target`; `bisect_right` = first index where `arr[i] > target`.

## 4. Classic Problems
- **LC 704 — Binary Search** (Easy): textbook template.
- **LC 33 — Search in Rotated Sorted Array** (Medium): decide which half is sorted each step.
- **LC 34 — First and Last Position of Element** (Medium): two `lower_bound` calls.
- **LC 875 — Koko Eating Bananas** (Medium): binary search on eating speed.
- **LC 4 — Median of Two Sorted Arrays** (Hard): binary search on partition index.

## 5. Worked Example — Koko Eating Bananas (LC 875)
Problem: `piles = [3, 6, 7, 11]`, hours `h = 8`. Find the minimum eating speed `k` (bananas/hour) so Koko finishes every pile within `h` hours.

Observation: define `hours_needed(k) = sum(ceil(p/k) for p in piles)`. As `k` increases, `hours_needed` decreases monotonically. We want the smallest `k` with `hours_needed(k) <= h`.

Search space: `k ∈ [1, max(piles)] = [1, 11]`. Apply Template B/C.

```python
def feasible(k):
    return sum((p + k - 1) // k for p in piles) <= h

lo, hi = 1, max(piles)
while lo < hi:
    mid = (lo + hi) // 2
    if feasible(mid):
        hi = mid
    else:
        lo = mid + 1
return lo
```

Trace with `piles = [3, 6, 7, 11]`, `h = 8`:

| step | `lo` | `hi` | `mid` | `hours_needed(mid)` | feasible? | new `[lo, hi)` |
|---|---|---|---|---|---|---|
| 1 | 1 | 11 | 6 | ⌈3/6⌉+⌈6/6⌉+⌈7/6⌉+⌈11/6⌉ = 1+1+2+2 = 6 | 6 ≤ 8 ✓ | `[1, 6]` |
| 2 | 1 | 6 | 3 | 1+2+3+4 = 10 | 10 ≤ 8 ✗ | `[4, 6]` |
| 3 | 4 | 6 | 5 | 1+2+2+3 = 8 | 8 ≤ 8 ✓ | `[4, 5]` |
| 4 | 4 | 5 | 4 | 1+2+2+3 = 8 | 8 ≤ 8 ✓ | `[4, 4]` |
| stop | 4 | 4 | — | — | — | return `4` |

Answer `k = 4`. Time `O(n * log(max(piles)))`. The whole pattern hinges on a **monotone** `feasible`, which is what you must prove (implicitly or explicitly) before reaching for this technique.

## 6. Common Variations
- **Rotated sorted** (LC 33/81): at each step one half is still sorted — use its endpoints to decide which half contains target.
- **Search in 2D matrix** (LC 74): treat as flat sorted array with index `(mid // n, mid % n)`.
- **Peak element** (LC 162): compare `arr[mid]` with `arr[mid+1]` to decide which side has a peak.
- **Floating-point binary search**: for a fixed number of iterations (e.g. 60) instead of `lo < hi`; stop on tolerance.
- **Binary search on answer**: minimum capacity (LC 1011), split array (LC 410), min days (LC 1482).
- **Lower / upper bound duality**: `upper_bound = lower_bound for >= target+1` on integers.
- **Pitfalls**: off-by-one with inclusive vs half-open, infinite loops when `mid = lo` and you set `lo = mid`, equality handling for duplicates.

## 7. Related Patterns
- **Sorting** — often the prerequisite; sometimes you search in an **implicit** sorted space (monotone predicate).
- **Two Pointers** — alternative on sorted arrays; converges from outside rather than halving.
- **Prefix Sum** — binary search over prefix values for range queries with constraints.
- **Greedy / Feasibility Check** — the inner `feasible(x)` in "binary search on the answer" is usually a greedy scan.
- **Heap + Binary Search** — merging sorted streams sometimes needs both.

Distinguishing note: if you find yourself writing a loop like `for k in range(1, max_k): if works(k): return k`, the answer is almost always **binary search on `k`** — as long as `works` is monotone.
