# 02 — Brute Force First

## 1. When to Use
- You are **stuck** and have not yet seen the trick — any correct answer beats a blank screen, and writing one out often reveals the structure.
- The problem statement says *"find all…"*, *"count all…"*, *"check every pair"*, *"enumerate…"* — the naive definition **is** a valid solution.
- **Small constraints** where the obvious solution already fits: `n <= 20` for subsets, `n <= 10` for permutations, `n <= 500` for triple loops.
- You need a **reference oracle** to test a faster solution against (random input + `assert fast(x) == brute(x)`).
- The interviewer says *"walk me through your thinking"* — brute force is the natural first step, and makes your optimisation story compelling.
- You need to **prove a lower bound** before attempting optimisation (if the answer list itself has `k` items, you cannot do better than `Ω(k)`).
- The problem is **output-sensitive** (e.g. generate all paths, list all valid parses) — there may be no asymptotic improvement possible.

Signal words: *"simplest"*, *"straightforward"*, *"naive"*, *"try all"*, *"enumerate"*, *"check each possibility"*.

## 2. Core Idea
The brute force mirrors the problem statement literally: enumerate the search space, check each candidate against the feasibility/scoring rule, return the best. It is almost always correct (just slow), and writing it forces you to pin down **inputs, outputs, and edge cases** — which is exactly the mental state you need to spot a speed-up. Optimisations come from identifying repeated work or redundant candidates *in* the brute force; without it you have nothing to optimise.

## 3. Template

### Generic enumerate-check-update skeleton
```python
def brute_force(inputs):
    best = None                                # use `None` when type/value of best is unknown until first valid candidate
    for candidate in generate_candidates(inputs):
        if is_valid(candidate, inputs):        # filter step: skip infeasible candidates
            score = evaluate(candidate, inputs)
            if best is None or score < best:   # GOTCHA: `best is None` short-circuits BEFORE comparing — needed since None < int raises in Py3
                best = candidate, score        # tuple packing — best is a (candidate, score) pair
    return best
```

### Common enumeration shapes
```python
# All pairs (i < j)                 -> O(n^2)
for i in range(n):
    for j in range(i + 1, n):              # i+1 (not i) avoids the (i,i) self-pair AND the (j,i) duplicate of (i,j)
        check(arr[i], arr[j])

# All triples (i < j < k)           -> O(n^3)
for i in range(n):
    for j in range(i + 1, n):
        for k in range(j + 1, n):          # nested i+1 / j+1 keeps strict ordering — no permutations of same triple
            check(arr[i], arr[j], arr[k])

# All subarrays (contiguous)        -> O(n^2) ranges
for i in range(n):
    for j in range(i, n):                  # j starts at i so single-element subarrays count
        check(arr[i:j+1])                  # GOTCHA: slice end is EXCLUSIVE, so use j+1 to include arr[j]

# All subsets via bitmask           -> O(2^n)
for mask in range(1 << n):                 # 1 << n == 2**n; range covers 0 .. 2^n - 1 (each int's bits = chosen indices)
    subset = [arr[i] for i in range(n) if mask >> i & 1]   # bit i set ⇒ include arr[i]. `>>` is shift, `&` is AND
    check(subset)

# All permutations                  -> O(n!)
from itertools import permutations
for p in permutations(arr):                # yields tuples (not lists). Convert with list(p) if mutation needed
    check(p)

# All k-combinations                -> O(C(n,k))
from itertools import combinations
for c in combinations(arr, k):             # combinations are sorted by INPUT POSITION, not value — sort arr first if value order matters
    check(c)
```

### Recursive enumeration with pruning (one small step toward backtracking)
```python
def enumerate_with_prune(partial, remaining):
    if is_goal(partial):
        record(partial[:]); return         # GOTCHA: record a COPY (partial[:]) — `partial` is mutated by caller; storing the ref shares state
    if is_infeasible(partial):
        return                             # prune — the earlier infeasibility is detected, the more branches saved
    for choice in remaining:
        partial.append(choice)             # try the choice
        enumerate_with_prune(partial, remaining - {choice})   # set difference: returns NEW set, doesn't mutate `remaining`
        partial.pop()                      # backtrack: undo append so siblings see clean state
```

### Brute force as an oracle
```python
import random
for _ in range(1000):
    arr = [random.randint(-5, 5) for _ in range(random.randint(0, 8))]   # randint is INCLUSIVE on both ends (unlike range)
    assert fast(arr) == brute(arr), arr   # the trailing `, arr` becomes the AssertionError message — prints the failing input
```

## 4. Classic Problems
- **LC 1 — Two Sum** (Easy): check every pair.
- **LC 53 — Maximum Subarray** (Medium): score every subarray, then optimise to Kadane.
- **LC 78 — Subsets** (Medium): enumerate all `2^n` subsets.
- **LC 46 — Permutations** (Medium): enumerate all `n!` orderings via backtracking.
- **LC 39 — Combination Sum** (Medium): try every combination; then prune.

## 5. Worked Example — "Maximum Subarray" as a ladder
Problem: given `nums = [-2, 1, -3, 4, -1, 2, 1, -5, 4]`, find the contiguous subarray with the largest sum.

### Step 1. The literal brute force, `O(n^3)`
Walk all `(i, j)` windows, sum them freshly each time.

```python
best = float('-inf')                       # sentinel: any real sum beats -inf on first compare
for i in range(n):
    for j in range(i, n):
        s = sum(nums[i:j+1])               # GOTCHA: nums[i:j+1] creates a NEW list each time (O(n) memory + time hidden here)
        best = max(best, s)
```

Trace of the first few `(i, j)` windows:

| `i` | `j` | `nums[i..j]` | `s` | `best` |
|---|---|---|---|---|
| 0 | 0 | `[-2]` | -2 | -2 |
| 0 | 1 | `[-2, 1]` | -1 | -1 |
| 0 | 2 | `[-2, 1, -3]` | -4 | -1 |
| 3 | 3 | `[4]` | 4 | 4 |
| 3 | 4 | `[4, -1]` | 3 | 4 |
| 3 | 5 | `[4, -1, 2]` | 5 | 5 |
| 3 | 6 | `[4, -1, 2, 1]` | 6 | 6 |

Answer `= 6`, window `[4, -1, 2, 1]`. Correct, but `O(n^3)`.

### Step 2. Spot the repeated work
`sum(nums[i:j+1])` recomputes from scratch. Keep a running total instead:

```python
for i in range(n):
    s = 0                                  # reset rolling sum at each new start index i
    for j in range(i, n):
        s += nums[j]                       # extend the previous sum by ONE element instead of re-summing the slice
        best = max(best, s)
```

Now `O(n^2)`. What changed: the inner work dropped from `O(j - i + 1)` to `O(1)`.

### Step 3. Spot the deeper redundancy
Every outer `i` restarts `s` at `0`. But if the running sum ever goes negative, restarting is strictly better than continuing — no matter what comes next. That observation, visible *only* because the brute force exposed the running-sum structure, is Kadane's algorithm:

```python
cur = best = nums[0]                       # chained assignment: both names bound to nums[0] (safe — int is immutable)
for x in nums[1:]:                         # nums[1:] copies the tail; for huge inputs use indexed loop to avoid the copy
    cur = max(x, cur + x)                  # KEY INSIGHT: if cur turned negative, cur+x < x — restart at x
    best = max(best, cur)                  # `best` only ever grows
```

`O(n)`, answer still `6`. The brute force was the ladder to the insight; it was never a throwaway.

### Step 4. Use the brute force as your oracle
While writing Kadane, keep the `O(n^2)` version around and randomly test:

```python
import random
for _ in range(1000):
    arr = [random.randint(-5, 5) for _ in range(random.randint(1, 12))]   # min length 1 — Kadane crashes on empty input
    assert kadane(arr) == brute_n2(arr), arr   # `, arr` makes the failing input visible in the AssertionError
```

If Kadane breaks on an edge case, the oracle will tell you the exact input.

## 6. Common Variations
- **Generate-and-test with pruning**: start brute, add `if is_infeasible(partial): continue` — smooths into backtracking (n-queens, sudoku).
- **Bitmask brute force**: for `n <= 20`, iterate `mask in range(1 << n)` to enumerate subsets in `O(2^n · n)` — often the cleanest form.
- **Permutation brute force**: `itertools.permutations(arr)` for `n <= 10`; pairs naturally with TSP / assignment problems.
- **Random sampling**: when the search space is astronomical, sampling a few million candidates can reveal structure (Monte Carlo).
- **Meet in the middle**: brute both halves separately and combine, turning `O(2^n)` into `O(2^{n/2})` — LC 1755, subset-sum variants.
- **Brute force as oracle**: keep the slow version in the test harness forever; `assert fast(x) == brute(x)` on random inputs is the single highest-leverage debugging tool.
- **Brute force as a correctness anchor**: when stuck on a complex optimisation, solve the problem two ways and ensure they agree — if they disagree, at least one is wrong.
- **Brute force for small cases, pattern-match to formula**: run brute for `n = 1..10`, eyeball the sequence, look it up on OEIS — sometimes reveals a closed form (`2^n`, `n!`, Catalan, etc.).
- **Brute force submissions**: for easy problems under loose constraints, the `O(n^2)` solution is the answer — do not over-engineer.
- **Edge cases surfaced by brute force**: empty input, single element, all equal, sorted/reverse sorted, all negatives, integer overflow — enumerate these explicitly in your brute-force tests.

### When brute force IS the final answer
- Constraints are small (`n ≤ 20`, `grid ≤ 10x10`, `len(s) ≤ 12`).
- The problem asks you to **list** all configurations (subsets, permutations, paths) — you cannot produce them faster than they exist.
- Output-sensitive problems where answer size equals work.
- "Generate the lexicographically smallest..." — brute + sort can beat an attempt at a clever constructive algorithm.

## 7. Related Patterns
- **Backtracking** — brute force + pruning on a decision tree.
- **Dynamic Programming** — brute force recursion + memoisation on overlapping subproblems.
- **Sliding Window / Two Pointers** — almost always the `O(n)` upgrade of an `O(n^2)` subarray brute force.
- **Hashing** — the typical way to kill the inner loop of an `O(n^2)` pair-search brute force.
- **Greedy** — when brute force reveals that the locally-best choice is always part of the global optimum.
- **Binary Search on Answer** — when brute search over a parameter is monotone in feasibility.
- **Time & Space Complexity** — brute force is the baseline you measure optimisations against.

**Distinguishing note**: brute force is not a destination, it is a **launchpad**. Its job is to (a) give you a correct answer, (b) expose the redundant work, and (c) anchor test cases for the optimised version. If you cannot write the brute force for a problem, you do not understand the problem yet.
