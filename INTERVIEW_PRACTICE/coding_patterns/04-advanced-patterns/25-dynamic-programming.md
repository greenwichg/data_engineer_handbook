# 25 — Dynamic Programming

## 1. When to Use
- The problem asks for a **count, an optimum (max/min), or feasibility** — not for the configurations themselves.
- Keyword smell test: *"number of ways"*, *"minimum cost"*, *"maximum value"*, *"longest"*, *"shortest"*, *"edit distance"*, *"can you partition"*, *"knapsack"*, *"how many distinct"*, *"best subsequence"*, *"fewest operations"*, *"minimum path sum"*.
- A **naive recursion** exists but has **overlapping subproblems** — the same `go(state)` recurses on the same arguments many times.
- The problem has **optimal substructure** — the optimum for `(i, j, …)` is assembled from optima on strictly smaller states.
- **Greedy fails** on a small counterexample (coins `[1,3,4]`, amount `6`) — that's your signal the local-best rule doesn't hold and you need a table of past optima.
- The state space `S` is **polynomial** and each transition costs `T` — DP runtime is roughly `|S| * T`, which you should estimate up front.
- You can reduce the problem to "for each prefix / interval / subset / position, best of …".

Reach for a **different pattern** when:
- Subproblems don't overlap → plain divide-and-conquer is enough.
- You must **enumerate** actual configurations (all permutations, all partitions) → backtracking, not DP.
- A provable greedy-choice property exists → greedy (cheaper and simpler).
- State explodes exponentially (e.g. need to remember a multiset of size `n` in full) → redesign the state, add bitmask, or accept that DP isn't the right tool.

## 2. Core Idea
Dynamic programming is **brute-force recursion + memoisation** (top-down) or the same recurrence filled **bottom-up** into a table. You turn exponential work into polynomial by computing each subproblem once and reusing it.

The art is choosing a **state** `(i, j, k, …)` that is simultaneously:
- **Small enough to tabulate** — product of ranges must be polynomial.
- **Rich enough to capture everything** the transition depends on — if the transition needs information not in the state, the state is under-specified.
- **Orderable** — there must be a topological ordering of subproblem dependencies so each is computable once all its dependents are ready.

The **five-step DP recipe** (practice it until it's automatic):
1. **Define the state** — what arguments uniquely identify a subproblem?
2. **Base case** — what states have trivial answers?
3. **Transition** — how does the state reduce to smaller states?
4. **Order of computation** — pick an iteration order such that each state's dependencies are already filled.
5. **Answer** — which state (or aggregation of states) gives the final result?

Memoisation vs tabulation: same asymptotic complexity, different trade-offs. **Top-down** (memoised recursion) is easier to write when transitions are sparse or the state space is hard to enumerate explicitly. **Bottom-up** (tabulation) is easier to space-optimise — often collapsing `dp[i]` into rolling variables when only the last one or two rows are needed.

Complexity shape: **states × transition cost**. A 1D DP with constant-time transition is `O(n)`; a 2D DP with linear transition is `O(n² × m)`. Space is the product of the active state dimensions after rolling-array optimisation.

## 3. Templates

### Template A — Top-down memoisation (recursion + cache)
```python
from functools import lru_cache

def solve(inputs):
    @lru_cache(maxsize=None)
    def go(*state):
        if is_base(state):
            return base_answer(state)
        best = neutral()
        for choice in choices(state):
            best = combine(best, go(*next_state(state, choice)))
        return best
    return go(*start_state(inputs))
```
Use when transitions are sparse or when you want the cleanest translation from a recursive brute-force. Trade-off: Python's recursion limit caps depth around 1000 — add `sys.setrecursionlimit(10_000)` for deep DPs.

### Template B — Bottom-up 1D DP (rolling variables)
```python
# Climbing stairs / Fibonacci / House Robber shape
def climb_stairs(n):
    if n <= 1:
        return 1
    a, b = 1, 1
    for _ in range(2, n + 1):
        a, b = b, a + b
    return b

def rob(nums):
    prev2, prev1 = 0, 0
    for x in nums:
        prev2, prev1 = prev1, max(prev1, prev2 + x)
    return prev1
```
When `dp[i]` depends only on the previous one or two entries, collapse to `O(1)` variables.

### Template C — Bottom-up 2D DP (edit distance / LCS shape)
```python
def edit_distance(a, b):
    m, n = len(a), len(b)
    dp = [[0] * (n + 1) for _ in range(m + 1)]
    for i in range(m + 1): dp[i][0] = i                    # delete all of a[:i]
    for j in range(n + 1): dp[0][j] = j                    # insert all of b[:j]
    for i in range(1, m + 1):
        for j in range(1, n + 1):
            if a[i - 1] == b[j - 1]:
                dp[i][j] = dp[i - 1][j - 1]
            else:
                dp[i][j] = 1 + min(
                    dp[i - 1][j],                          # delete
                    dp[i][j - 1],                          # insert
                    dp[i - 1][j - 1],                      # replace
                )
    return dp[m][n]
```
Two sequences ⇒ two indices. Direction of iteration must satisfy dependency (`i-1`, `j-1` ⇒ outer `i` ascending, inner `j` ascending).

### Template D — 0/1 Knapsack (each item once)
```python
def knapsack_01(weights, values, W):
    dp = [0] * (W + 1)
    for wt, val in zip(weights, values):
        for w in range(W, wt - 1, -1):                     # REVERSE to avoid reuse
            dp[w] = max(dp[w], dp[w - wt] + val)
    return dp[W]
```
Reverse iteration on `w` is the crux: forward iteration would let the same item be counted twice. Contrast with unbounded knapsack (Template E).

### Template E — Unbounded knapsack (unlimited copies; coin change)
```python
def coin_change_min(coins, amount):
    INF = float("inf")
    dp = [INF] * (amount + 1)
    dp[0] = 0
    for x in range(1, amount + 1):
        for c in coins:
            if c <= x and dp[x - c] + 1 < dp[x]:
                dp[x] = dp[x - c] + 1
    return dp[amount] if dp[amount] != INF else -1

def coin_change_ways(coins, amount):
    dp = [0] * (amount + 1)
    dp[0] = 1
    for c in coins:                                         # outer: coins → combinations
        for x in range(c, amount + 1):
            dp[x] += dp[x - c]
    return dp[amount]
```
Watch the loop order for counting problems. **Coins outside / amount inside** counts *combinations* (order doesn't matter). **Amount outside / coins inside** counts *permutations*. LC 322 (min coins) is order-insensitive; LC 518 (number of ways) is combinations; LC 377 (combination sum IV) is actually *permutations*.

### Template F — Longest Increasing Subsequence (O(n log n) patience sorting)
```python
from bisect import bisect_left

def length_of_lis(nums):
    tails = []                                              # tails[i] = smallest tail of an LIS of length i+1
    for x in nums:
        idx = bisect_left(tails, x)
        if idx == len(tails):
            tails.append(x)
        else:
            tails[idx] = x
    return len(tails)
```
Classic trick: DP + binary search. `tails` isn't the LIS itself — it's the invariant "best possible tails by length". The `O(n²)` DP `dp[i] = 1 + max(dp[j] for j<i if a[j]<a[i])` is also useful to know (clearer but slower).

### Template G — Interval DP (matrix-chain, burst balloons)
```python
def min_matrix_chain(dims):
    n = len(dims) - 1                                       # number of matrices
    dp = [[0] * n for _ in range(n)]
    for length in range(2, n + 1):                          # length of the chain
        for i in range(n - length + 1):
            j = i + length - 1
            dp[i][j] = float("inf")
            for k in range(i, j):                           # split point
                cost = dp[i][k] + dp[k + 1][j] + dims[i] * dims[k + 1] * dims[j + 1]
                if cost < dp[i][j]:
                    dp[i][j] = cost
    return dp[0][n - 1]
```
`dp[i][j]` over intervals. Outer loop on **length** so every smaller interval is ready before you need it. Used for matrix-chain multiplication, palindromic-substring counts, burst-balloons (LC 312), optimal BST.

### Template H — Bitmask DP (`n ≤ 20`; TSP, assignment)
```python
def tsp(dist):
    n = len(dist)
    INF = float("inf")
    dp = [[INF] * n for _ in range(1 << n)]
    dp[1][0] = 0                                            # start at city 0
    for mask in range(1 << n):
        for u in range(n):
            if not (mask >> u) & 1 or dp[mask][u] == INF:
                continue
            for v in range(n):
                if (mask >> v) & 1:
                    continue
                new_mask = mask | (1 << v)
                cand = dp[mask][u] + dist[u][v]
                if cand < dp[new_mask][v]:
                    dp[new_mask][v] = cand
    return min(dp[(1 << n) - 1][u] + dist[u][0] for u in range(1, n))
```
State: (visited subset, current position). `2^n * n` states × `O(n)` transition = `O(n² 2^n)`. Works up to ~20 nodes. Use for TSP, assignment, small covering problems.

### Template I — Tree DP (post-order DFS with tuple return)
```python
def rob_tree(root):
    def go(node):
        if node is None:
            return (0, 0)                                   # (rob_here, skip_here)
        l_rob, l_skip = go(node.left)
        r_rob, r_skip = go(node.right)
        rob_here = node.val + l_skip + r_skip
        skip_here = max(l_rob, l_skip) + max(r_rob, r_skip)
        return (rob_here, skip_here)
    return max(go(root))
```
Post-order DFS returning a tuple packs "taken vs not taken" (or any binary choice) per subtree. Covers LC 337 (House Robber III), LC 968 (cameras), tree diameter.

### Template J — Digit DP (count numbers with property)
```python
from functools import lru_cache

def count_digits_with_property(N):
    s = str(N)
    @lru_cache(maxsize=None)
    def go(pos, tight, leading_zero, property_state):
        if pos == len(s):
            return 1 if accepting(property_state) else 0
        limit = int(s[pos]) if tight else 9
        total = 0
        for d in range(0 if leading_zero else 0, limit + 1):
            total += go(pos + 1,
                        tight and d == limit,
                        leading_zero and d == 0,
                        update(property_state, d))
        return total
    return go(0, True, True, initial_property_state())
```
State: `(position, tight-against-N, still-leading-zero, property-state)`. Covers "count numbers ≤ N divisible by k / with digit sum / with no two adjacent equal digits".

## 4. Classic Problems
- **LC 70 — Climbing Stairs** (Easy): `dp[i] = dp[i-1] + dp[i-2]`.
- **LC 198 — House Robber** (Medium): take-or-skip linear DP.
- **LC 300 — Longest Increasing Subsequence** (Medium): `O(n²)` DP or `O(n log n)` patience-sort.
- **LC 322 — Coin Change** (Medium): unbounded-knapsack minimum.
- **LC 416 — Partition Equal Subset Sum** (Medium): subset-sum 0/1 knapsack.
- **LC 518 — Coin Change II** (Medium): unbounded-knapsack combination count.
- **LC 1143 — Longest Common Subsequence** (Medium): 2D suffix DP.
- **LC 72 — Edit Distance** (Hard): 2D DP, three transitions.
- **LC 10 / 44 — Regex / Wildcard Matching** (Hard): 2D DP with `*` as 0-or-more transition.
- **LC 312 — Burst Balloons** (Hard): interval DP, think "last balloon to burst".
- **LC 337 — House Robber III** (Medium): tree DP with pair return.
- **LC 647 / 5 — Palindromic Substrings / Longest Palindromic Substring** (Medium): interval-length DP.
- **LC 53 — Maximum Subarray** (Medium): Kadane = 1D DP with `dp[i] = max(a[i], dp[i-1] + a[i])`.
- **LC 1155 — Number of Dice Rolls With Target Sum** (Medium): classic (dice, faces, target) knapsack.
- **LC 877 — Stone Game** (Medium): game-theory DP over intervals.

## 5. Worked Example — Coin Change (LC 322)
Problem: `coins = [1, 2, 5]`, `amount = 11`. Return the fewest coins summing exactly to `amount`, or `-1` if impossible.

### Step 1 — Define the state
`dp[x]` = minimum number of coins that sum exactly to `x`. Target = `dp[amount]`.

### Step 2 — Base case
`dp[0] = 0` (zero coins make zero). All other `dp[x]` start as `∞` (unreachable).

### Step 3 — Transition
For each amount `x` from 1 upward, try every coin `c ≤ x`:
```
dp[x] = min over c ≤ x of (dp[x - c] + 1)
```
If no coin fits or every predecessor is `∞`, `dp[x]` stays `∞` ⇒ unreachable.

### Step 4 — Order
Iterate `x` from `1` to `amount`. By the time we compute `dp[x]`, every `dp[x - c]` with `c ≤ x` is already final.

### Step 5 — Answer
`dp[amount]` if finite, else `-1`.

### Implementation
```python
def coinChange(coins, amount):
    INF = float("inf")
    dp = [INF] * (amount + 1)
    dp[0] = 0
    for x in range(1, amount + 1):
        for c in coins:
            if c <= x and dp[x - c] + 1 < dp[x]:
                dp[x] = dp[x - c] + 1
    return dp[amount] if dp[amount] != INF else -1
```

### Full trace, `coins = [1, 2, 5]`, `amount = 11`

| `x` | candidates considered (`dp[x - c] + 1` for c in 1, 2, 5) | `dp[x]` | best path |
|---|---|---|---|
| 0  | — (base) | 0 | `∅` |
| 1  | `dp[0] + 1 = 1` | 1 | `1` |
| 2  | `dp[1] + 1 = 2`, `dp[0] + 1 = 1` | 1 | `2` |
| 3  | `dp[2] + 1 = 2`, `dp[1] + 1 = 2` | 2 | `1 + 2` |
| 4  | `dp[3] + 1 = 3`, `dp[2] + 1 = 2` | 2 | `2 + 2` |
| 5  | `dp[4] + 1 = 3`, `dp[3] + 1 = 3`, `dp[0] + 1 = 1` | 1 | `5` |
| 6  | `dp[5] + 1 = 2`, `dp[4] + 1 = 3`, `dp[1] + 1 = 2` | 2 | `5 + 1` or `2 + 2 + 2`? → 2 coins via `5 + 1` |
| 7  | `dp[6] + 1 = 3`, `dp[5] + 1 = 2`, `dp[2] + 1 = 2` | 2 | `5 + 2` |
| 8  | `dp[7] + 1 = 3`, `dp[6] + 1 = 3`, `dp[3] + 1 = 3` | 3 | `5 + 2 + 1` |
| 9  | `dp[8] + 1 = 4`, `dp[7] + 1 = 3`, `dp[4] + 1 = 3` | 3 | `5 + 2 + 2` |
| 10 | `dp[9] + 1 = 4`, `dp[8] + 1 = 4`, `dp[5] + 1 = 2` | 2 | `5 + 5` |
| 11 | `dp[10] + 1 = 3`, `dp[9] + 1 = 4`, `dp[6] + 1 = 3` | 3 | `5 + 5 + 1` (from `dp[10]`) |

Answer `dp[11] = 3` (e.g. `5 + 5 + 1`). Time `O(amount × |coins|) = O(11 × 3)`, space `O(amount)`.

### Why DP and not greedy?
Greedy "take largest coin first" would give `5 + 5 + 1 = 3 coins` on this input — coincidentally optimal. But flip to `coins = [1, 3, 4]`, `amount = 6`:
- **Greedy**: `4 + 1 + 1 = 3 coins`.
- **DP**: `3 + 3 = 2 coins`.
Greedy is wrong in general because the "largest coin" rule ignores the combinatorial structure of smaller coins. The DP table remembers every reachable sub-amount's optimum, so it never gets trapped.

### Why the inner-outer loop order doesn't matter for LC 322
LC 322 asks for a **minimum**, and `min` is commutative. Whether you iterate `x` outer / `c` inner or vice-versa, every `(x, c)` pair is still considered. It *does* matter for **LC 518** (count of combinations) where outer `c` / inner `x` counts combinations and outer `x` / inner `c` counts permutations.

### Top-down rewrite for comparison
```python
from functools import lru_cache

def coinChange(coins, amount):
    @lru_cache(maxsize=None)
    def go(x):
        if x == 0: return 0
        if x < 0: return float("inf")
        best = float("inf")
        for c in coins:
            best = min(best, go(x - c) + 1)
        return best
    ans = go(amount)
    return ans if ans != float("inf") else -1
```
Same recurrence, recursive flavour. Use this when translating from a brute-force solution in an interview — the cache turns exponential into linear.

### Space optimisation
`dp[x]` depends only on `dp[x - c]` for `c ∈ coins`, all at smaller indices. No rolling trick beyond `O(amount)` is possible without redesigning the state (e.g. meet-in-the-middle for very large amounts).

### Edge cases
- `amount = 0` → `dp[0] = 0`, return 0.
- `coins` contains only large denominations and `amount < min(coins)` → `dp[amount] = ∞`, return `-1`.
- Duplicate coins in input → harmless (just redundant loop iterations).
- Very large `amount` (e.g. `10⁹`) → `O(amount)` memory is infeasible; this problem variant needs a completely different approach (mathematical / BFS on residues).

## 6. Common Variations
### By state shape
- **1D DP**: climbing stairs, house robber, maximum subarray (Kadane), LIS (`O(n²)`), decode ways, min-cost climbing stairs.
- **2D DP over two sequences**: LCS, edit distance, distinct subsequences, regex/wildcard matching, interleaving strings.
- **2D DP over a grid**: unique paths, minimum path sum, dungeon game, cherry pickup (3D actually, `(i1, j1, i2)` trick).
- **Interval DP**: `dp[i][j]` with outer loop over interval length — burst balloons, matrix chain, palindrome partitioning, optimal BST, stone game.
- **Tree DP**: post-order recursion returning a tuple of states per subtree — robber III, binary tree cameras, tree diameter.
- **Bitmask DP**: TSP, assignment, covering, "find minimum subsets", any `n ≤ 20` with a subset-indexed state.
- **Digit DP**: count numbers with digit-level property ≤ N.
- **Probability / expected-value DP**: `dp[state]` = expected value from state, transitions weighted by probabilities (dice roll, random walk).

### By knapsack pattern
- **0/1 knapsack** — each item used at most once; reverse-iterate capacity.
- **Unbounded knapsack** — unlimited copies; forward-iterate capacity (coin change min).
- **Bounded knapsack** — at most `k[i]` copies; binary-expand counts (split `13` into `1 + 2 + 4 + 6`) and treat as 0/1.
- **Multi-dimensional knapsack** — capacity has multiple dimensions (weight + volume + …) → inner loops per dimension.

### By objective
- **Min / max / feasibility** (standard).
- **Count of ways** — transitions are sums, not max/min. Modulo arithmetic if counts overflow.
- **Existence of path meeting a constraint** — booleans instead of integers.
- **Actual configuration** — store parent pointers or re-derive by backtracking through the `dp` table.

### By transition trick
- **DP + binary search** — LIS `O(n log n)`; split-array-largest-sum (LC 410).
- **DP + monotonic deque** — sliding-window maximum DP (LC 1696 jump game VI).
- **DP + prefix sums** — sum-over-ranges transitions collapse to `O(1)` with a prefix array.
- **Meet-in-the-middle** — split state space in two, combine via hash or sort.
- **DP on graph SCCs / condensation DAG** — when the graph isn't a DAG, condense first.

### Edge cases to check
- Impossible target → sentinel (`inf` / `-1`) instead of 0.
- Empty input → base case answer, not a crash.
- Counts that overflow → use the problem's modulus at every `+=`.
- Negative edge weights → DP may not apply; use shortest-path algorithms instead.
- Recursion depth > 1000 in Python for top-down → `sys.setrecursionlimit` or switch to bottom-up.

## 7. Related Patterns
- **Recursion / Backtracking** — DP is memoised recursion; always write the brute-force recurrence first, then cache. Backtracking *enumerates* configurations; DP *counts or optimises* over them.
- **Greedy (24)** — strictly more efficient than DP when the greedy-choice property holds. DP is the fallback when greedy breaks on a small counterexample.
- **Divide and Conquer** — disjoint subproblems with no overlap → no memoisation needed. If you see the same subproblem twice, it's DP.
- **Graph Algorithms on DAGs (23 topological sort)** — DAG shortest/longest path is "DP in topological order". Topo sort gives the legal iteration order.
- **Tree DFS (16)** — tree DP is post-order DFS with state aggregation; the tree is the subproblem DAG.
- **Binary Search + DP** — LIS `O(n log n)`, capacity feasibility (LC 410 split-array-largest-sum), Koko eating bananas.
- **Two Pointers / Sliding Window (3, 4)** — sometimes a DP collapses to a window when the transition only depends on a bounded range.
- **Heap / Priority Queue (19)** — Dijkstra is a "DP over shortest paths" with a priority queue guiding evaluation order.
- **Union-Find (22)** — not DP, but useful when a DP would need connectivity info on a dynamic graph.
- **Hashing** — `lru_cache` is a hash-backed memo table; tabulation replaces it with an array when the state is integer-indexed.

Distinguishing note: the single best filter is *"does the same subproblem reappear?"* If yes → DP. If each subproblem is unique → divide-and-conquer. If the local best always wins → greedy. If you must list configurations → backtracking. When two apply, prefer the cheapest: greedy > DP > backtracking. When designing a DP, always write the recurrence first (the *what*) and pick the representation second (the *how*) — a clean recurrence turns into a clean table automatically, but a rushed table with no recurrence behind it rarely survives the first edge case.
