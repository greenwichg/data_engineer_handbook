# 01 — Time & Space Complexity

## 1. When to Use
Apply this lens **before coding** (to pick an approach that fits the constraints) and **after coding** (to verify the solution will pass). Reach for complexity analysis whenever you see:

- **Explicit input bounds** in the prompt: `n <= 10^5`, `n <= 10^9`, `grid[m][n] with m,n <= 1000`, `|s| <= 50000`.
- **Multiple candidate solutions** and you must justify which one to submit.
- **Time / memory limits** printed alongside the problem (competitive programming).
- **Keywords**: *"efficient"*, *"fastest"*, *"optimal"*, *"compare approaches"*, *"large input"*, *"streaming"*, *"online"*, *"constant extra memory"*.
- A working brute force whose feasibility is not obvious — you need to know whether `O(n^2)` at `n = 10^5` is `10^{10}` ops (no) or `10^8` (borderline).
- Code review: any time someone writes a nested loop, ask *"what is the growth rate?"*.

Rough ceilings per second on a typical judge (~`10^8`–`10^9` simple ops/sec):

| Input size `n` | Acceptable complexity | Example algorithm |
|---|---|---|
| `n <= 12` | `O(n!)` | Held-Karp, brute permutations |
| `n <= 20` | `O(2^n)` | Bitmask DP, subset enumeration |
| `n <= 500` | `O(n^3)` | Floyd-Warshall, interval DP |
| `n <= 5_000` | `O(n^2)` | Standard DP tables |
| `n <= 10^5` | `O(n log n)` | Sort, Dijkstra |
| `n <= 10^7` | `O(n)` | Kadane, two pointers |
| `n <= 10^18` | `O(log n)` or `O(1)` | Binary search, closed form |

## 2. Core Idea
Complexity counts **how the work grows with input**, not wall-clock seconds. We drop constants and lower-order terms because the dominant term eventually swamps everything else — an `O(n log n)` algorithm with a big constant will still beat an `O(n^2)` one as `n` grows. Picking an algorithm whose growth curve matches the input size is the difference between a solution that finishes and one that TLEs, regardless of how clean the code is.

Three orthogonal resources matter: **time**, **auxiliary space** (the data structures you allocate), and **recursion stack** (implicit on every recursive call). A submission is constrained by the tightest of the three.

## 3. Template

### Mental walking-the-code recipe
```python
def analyze(arr):
    n = len(arr)                          # len() is O(1) — Python stores length, no count loop

    # O(1) — single index lookup, no loop
    first = arr[0]                        # raises IndexError if arr is empty — guard with `if arr`

    # O(n) — one linear pass over every element
    total = sum(arr)                      # built-in C loop, ~3x faster than a Python `for x in arr`

    # O(n log n) — Timsort dominates any linear work around it
    arr.sort()                            # GOTCHA: in-place, returns None. Use sorted(arr) for a new list

    # O(n^2) — two nested loops over n
    for i in range(n):
        for j in range(i + 1, n):         # i+1 avoids (i,i) self-pairs and (j,i) duplicates
            _ = arr[i] + arr[j]           # `_` = throwaway var by convention

    # O(n log n) via recursion: T(n) = 2*T(n/2) + O(n)  (merge sort)
    # O(n)     via recursion: T(n) = 2*T(n/2) + O(1)    (tree traversal)
    # O(log n) via recursion: T(n) =   T(n/2) + O(1)    (binary search)
    # O(2^n)   via recursion: T(n) = 2*T(n-1) + O(1)    (brute subsets)

    # Space:
    #   - `total`, `first` are scalars         -> O(1)
    #   - `arr.sort()` in Python               -> O(n) extra (Timsort merge buffer)
    #   - the copy below                       -> O(n) new list
    copy = arr[:]                         # slice = shallow copy. For nested lists use copy.deepcopy

    return total, copy
```

### Counting rules of thumb
- **Sequential** sections **add** → `O(f) + O(g) = O(max(f, g))`.
- **Nested** loops **multiply** → outer `n` × inner `n` = `O(n^2)`.
- **Recursion**: solve the recurrence, or apply the Master Theorem for `T(n) = aT(n/b) + O(n^d)`.
- **Amortised**: `list.append` is `O(1)` amortised (the occasional `O(n)` resize averages out).
- **Hash map op** is average `O(1)`; treat as `O(n)` only under adversarial keys.
- **Python-specific**: `in list` is `O(n)`; `in set/dict` is `O(1)` avg; `list.pop(0)` is `O(n)` — use `deque`.

### The Master Theorem, pragmatic form
For `T(n) = a · T(n/b) + O(n^d)`:
- `d > log_b a` → `O(n^d)` (work dominated by the top level).
- `d = log_b a` → `O(n^d log n)` (work balanced across levels).
- `d < log_b a` → `O(n^{log_b a})` (work dominated by leaves).

Example: merge sort has `a = 2, b = 2, d = 1`; `log_b a = 1 = d` → `O(n log n)`.

## 4. Classic Problems
- **LC 1 — Two Sum** (Easy): brute `O(n^2)` vs hash `O(n)`.
- **LC 53 — Maximum Subarray** (Medium): `O(n^3)` → `O(n^2)` → Kadane `O(n)`.
- **LC 74 — Search a 2D Matrix** (Medium): `O(m·n)` vs `O(log(m·n))`.
- **LC 215 — Kth Largest Element** (Medium): full sort `O(n log n)` vs heap `O(n log k)` vs quickselect `O(n)` avg.
- **LC 300 — Longest Increasing Subsequence** (Medium): DP `O(n^2)` vs patience sort `O(n log n)`.

## 5. Worked Example — Three takes on "Maximum Subarray" (LC 53)
Problem: find the contiguous subarray of `nums = [-2, 1, -3, 4, -1, 2, 1, -5, 4]` with the maximum sum.

We'll compute complexity at each refinement.

### Attempt A — `O(n^3)` brute
```python
best = float('-inf')                       # sentinel: any real sum will beat -inf on first compare
for i in range(n):
    for j in range(i, n):                  # j starts at i so single-element subarrays count
        s = sum(nums[i:j+1])               # GOTCHA: nums[i:j+1] makes a NEW list every iteration (O(n) work + O(n) memory)
        best = max(best, s)                # equivalent to: if s > best: best = s
```
Work count: `∑_{i=0}^{n-1} ∑_{j=i}^{n-1} (j - i + 1)` ≈ `n^3 / 6`. At `n = 10^5`, that is `~10^{14}` — decades of runtime.

### Attempt B — `O(n^2)` rolling sum
```python
for i in range(n):
    s = 0                                  # reset rolling sum at each new start index i
    for j in range(i, n):
        s += nums[j]                       # KEY TRICK: extend previous sum instead of re-summing slice
        best = max(best, s)                # compare every prefix sum starting at i
```
Work count: `∑_{i=0}^{n-1} (n - i)` ≈ `n^2 / 2`. At `n = 10^5`, that is `~5·10^9` — still TLE.

Trace of inner state for `i = 3`, `nums = [-2, 1, -3, 4, -1, 2, 1, -5, 4]`:

| `j` | `nums[j]` | running `s` | `best` |
|---|---|---|---|
| 3 | 4 | 4 | 4 |
| 4 | -1 | 3 | 4 |
| 5 | 2 | 5 | 5 |
| 6 | 1 | 6 | 6 |
| 7 | -5 | 1 | 6 |
| 8 | 4 | 5 | 6 |

### Attempt C — `O(n)` Kadane
```python
cur = best = nums[0]                       # chained assignment: both bound to nums[0]. Safe here because int is immutable
for x in nums[1:]:                         # nums[1:] copies; for huge inputs use `for i in range(1, len(nums)): x = nums[i]`
    cur = max(x, cur + x)                  # KEY INSIGHT: if cur+x < x, drop the prefix and restart at x
    best = max(best, cur)                  # `best` only ever grows
```
Work: single pass, constant work per element → `O(n)`. Space: `O(1)`.

Full trace:

| step | `x` | `cur + x` | `max(x, cur+x)` → new `cur` | `best` |
|---|---|---|---|---|
| init | −2 | — | −2 | −2 |
| 1 | 1 | −1 | 1 | 1 |
| 2 | −3 | −2 | −2 | 1 |
| 3 | 4 | 2 | 4 | 4 |
| 4 | −1 | 3 | 3 | 4 |
| 5 | 2 | 5 | 5 | 5 |
| 6 | 1 | 6 | 6 | 6 |
| 7 | −5 | 1 | 1 | 6 |
| 8 | 4 | 5 | 5 | 6 |

Answer: `best = 6` (subarray `[4, -1, 2, 1]`). Kadane shaves a factor of `n` by recognising that the inner loop only needed the best sum ending at `j` — not every pair.

### Table: what each version can handle
| Version | Complexity | Max `n` in 1s |
|---|---|---|
| A | `O(n^3)` | `n ≤ 500` |
| B | `O(n^2)` | `n ≤ 5_000` |
| C | `O(n)` | `n ≤ 10^8` |

## 6. Common Variations
- **Best vs worst vs average**: quickselect is `O(n)` expected but `O(n^2)` worst; dict ops are `O(1)` average, `O(n)` worst.
- **Amortised analysis**: Python `list.append` is `O(1)` amortised; `string += c` inside a loop is `O(n^2)` — always `"".join(parts)` instead.
- **Output-sensitive complexity**: enumerating all pairs summing to `k` is at least `Ω(k)` where `k` is the answer count; "fast" depends on output size.
- **Input-shape sensitive**: graphs are `O(V + E)`, not `O(V)` or `O(V^2)` — measure in the right variable.
- **Space class**: distinguish **auxiliary** space (you allocated) from **input** space (given to you).
- **Recursion stack**: recursive solutions carry `O(depth)` stack space even when they look `O(1)` in data.
- **Amortised vs online**: some structures (Splay tree, dynamic array) are only fast when averaged over many ops.
- **Bit-level detail**: `O(1)` on fixed-width ints becomes `O(word)` on arbitrary-precision; relevant for big-int crypto problems.
- **Cache effects**: `O(n)` linear scan outperforms `O(n log n)` tree walk even on bigger inputs because of memory locality.
- **Hidden constants**: an `O(n log^2 n)` segment tree can lose to an `O(n·sqrt(n))` sqrt-decomp in practice.

### Complexity sniff tests
- Two nested loops over `n` → `O(n^2)`. Ok for `n ≤ 5000`.
- Outer loop `n`, inner loop `log n` (e.g. binary search) → `O(n log n)`.
- Recursion that branches to 2 calls with `n - 1` → `O(2^n)`.
- Recursion that branches to 2 calls with `n/2` and does `O(n)` work → `O(n log n)` (merge sort).
- "For each pair of elements" → instant `O(n^2)` unless you avoid it with hashing / sorting / two pointers.

## 7. Related Patterns
- **Brute Force First** — complexity analysis is how you decide the brute force needs replacing.
- **Binary Search** — canonical `O(n) → O(log n)` upgrade on sorted/monotonic inputs.
- **Sorting** — a common `O(n log n)` preprocessing step that unlocks later `O(n)` scans.
- **Hashing** — canonical `O(n^2) → O(n)` upgrade by trading space for time.
- **DP vs Backtracking** — memoisation collapses exponential recursion to polynomial.
- **Sliding Window / Two Pointers** — same trade: amortise repeated inner work across overlapping ranges.

**Distinguishing note**: complexity is not a pattern you *apply* — it is the scoreboard you use to **pick** which pattern to apply. Read every other file in this series with complexity as the lens: "what did this pattern just save me?"
