# 24 — Greedy

## 1. When to Use
- The problem asks for an **optimum** (max / min / minimum number of / maximum you can fit) and a natural "best next choice" is obvious.
- Keyword smell test: *"minimum number of"*, *"maximum you can"*, *"assign to fit"*, *"intervals / meetings"*, *"schedule"*, *"coins"*, *"activity selection"*, *"jump game"*, *"burst balloons"*, *"tasks with cooldown"*, *"gas station"*, *"candy distribution"*, *"ration / fill as many as possible"*.
- There is an **exchange argument**: swapping any "better" item into the greedy solution for the one it replaced cannot hurt the objective.
- Inputs are cheaply **sortable by the greedy key** (deadline, end time, weight-to-ratio, frequency, length).
- The problem has the **greedy-choice property + optimal substructure**: the locally best move is part of some global optimum, and once made, the residual problem is the same kind of problem.
- DP would work but its state space is overkill — the subproblem shrinks monotonically after each greedy commit.
- You need to decide quickly online as items stream in (heap-based greedy, k-largest / k-smallest maintenance).

Reach for a **different pattern** when:
- You can construct a tiny counterexample breaking the local rule → switch to DP or backtracking.
- The decision at step `i` depends on *future* items in a non-monotone way → DP with memoisation.
- Multiple greedy keys tie and neither exchange argument holds → you likely need DP over (i, state).

## 2. Core Idea
At each step, pick the choice that is locally best by a fixed rule, commit to it, never revisit. Greedy is correct when **that local choice is guaranteed to participate in some global optimum** — proved either by (a) an *exchange argument* (swap the greedy pick into an arbitrary optimal solution without loss) or (b) an *inductive invariant* (after each step, the residual problem's optimum plus what we've taken equals the overall optimum).

Two canonical proof patterns you should keep in your head:

1. **Stay-ahead argument**: show that after `k` greedy picks, the greedy solution is at least as good on every measurable axis as any other feasible solution of size `k`. Classic for activity selection.
2. **Exchange (swap) argument**: take an arbitrary optimum `O`; if it disagrees with greedy `G` at the first point, swap `O`'s choice for `G`'s and show the objective does not worsen. Iterate → `O` becomes `G`. Classic for fractional knapsack, Huffman, MST (Kruskal).

When greedy fails, it is almost always because the local "best" forecloses a strictly better combination downstream. Smell for this: the choice irreversibly consumes a scarce resource, or two greedy keys give opposing rankings. When in doubt, construct a 3-element counterexample — if any ordering breaks greedy, DP is mandatory.

Complexity is usually dominated by the sort: **`O(n log n)`**. With a heap for "best remaining", operations are `O(log n)` each → still `O(n log n)` total. Space is typically `O(n)` for the sort or `O(k)` for the heap.

## 3. Templates

### Template A — Sort by greedy key, single sweep
```python
def greedy_sweep(items, key_fn, feasible, commit):
    items.sort(key=key_fn)                        # .sort() mutates in place & returns None — don't do `x = items.sort()`
    state = init_state()
    chosen = []
    for item in items:
        if feasible(state, item):
            chosen.append(item)
            state = commit(state, item)           # reassign state — don't mutate in place unless commit guarantees it
    return chosen
```
The workhorse. The art is choosing `key_fn`: earliest end, largest ratio, most-constrained first, smallest deficit.

### Template B — Activity selection (earliest-finishing interval)
```python
def max_non_overlapping(intervals):
    intervals.sort(key=lambda iv: iv[1])          # sort by END (iv[1]) — NOT iv[0]; local optimum only works with end-sort
    count, last_end = 0, float("-inf")            # float("-inf") is safe immutable sentinel; compares less than any real number
    for s, e in intervals:
        if s >= last_end:                         # >= treats touching as non-overlap (LC 435); use > for strict gap
            count += 1
            last_end = e
    return count
```
Canonical greedy. Exchange argument: among all intervals that start after `last_end`, picking the earliest-finishing one leaves the most room for subsequent intervals → never hurts.

### Template C — Canonical-coin change (largest-first)
```python
def min_coins_canonical(coins, amount):
    """Works ONLY for canonical coin systems (e.g., US coins 1/5/10/25)."""
    coins.sort(reverse=True)                      # sort descending — try largest denomination first
    used = 0
    for c in coins:
        if amount == 0:
            break
        used += amount // c                       # `//` is FLOOR div (matches math floor for positive ints)
        amount %= c                               # Python % is non-negative when operands are positive — no C-style sign surprise
    return used if amount == 0 else -1
```
Warning: for arbitrary coin sets this is **wrong** — e.g. `coins=[1,3,4]`, `amount=6` gives greedy `4+1+1=3` coins but optimum is `3+3=2`. When in doubt, use the DP from pattern 25.

### Template D — Heap-based "best remaining" (Meeting Rooms II)
```python
import heapq

def min_meeting_rooms(intervals):
    intervals.sort(key=lambda iv: iv[0])          # by start time
    heap = []                                     # plain list — heapq operates on it IN PLACE
    for s, e in intervals:
        if heap and heap[0] <= s:                 # heap[0] is smallest (min-heap); `heap and ...` short-circuits on empty
            heapq.heappop(heap)                   # returns root and re-heapifies — don't call list.pop(0)!
        heapq.heappush(heap, e)
    return len(heap)                              # peak simultaneous rooms = final heap size
```
Greedy rule: when a new meeting starts, reuse the room that frees soonest; otherwise allocate a new one. Heap answers "which room frees soonest?" in `O(log n)`.

### Template E — Reach-expansion greedy (Jump Game I / II)
```python
def can_jump(nums):
    reach = 0
    for i, x in enumerate(nums):                  # enumerate yields (index, value) tuples — cleaner than range(len(nums))
        if i > reach:
            return False                          # got stuck before reaching i — no way forward
        reach = max(reach, i + x)
    return True

def jump_game_ii(nums):
    jumps = end = farthest = 0                    # chained assignment — all three start at 0 (int is immutable, safe)
    for i in range(len(nums) - 1):                # iterate UP TO but not including last index — we don't jump FROM last
        farthest = max(farthest, i + nums[i])
        if i == end:                              # reached end of current window → must jump now
            jumps += 1
            end = farthest
    return jumps
```
The BFS-flavoured variant (`jump_game_ii`) batches every index reachable in `k` jumps as one "layer" — the `i == end` boundary triggers a new jump. This is BFS without an explicit queue.

### Template F — Frequency-first scheduling (Task Scheduler LC 621)
```python
import heapq
from collections import Counter, deque

def task_scheduler(tasks, n):
    counts = Counter(tasks)                       # Counter is a dict subclass — counts[key] defaults to 0 for missing keys
    heap = [-c for c in counts.values()]          # NEGATE to simulate max-heap on Python's min-heap-only heapq
    heapq.heapify(heap)                           # O(len) — faster than n pushes
    cooldown = deque()                            # FIFO of (ready_time, remaining_count)
    time = 0
    while heap or cooldown:                       # loop until BOTH are empty
        time += 1
        if heap:
            remaining = heapq.heappop(heap) + 1   # +1 because counts are NEGATIVE (decrementing magnitude = adding)
            if remaining != 0:                    # zero means task fully done — don't re-enqueue
                cooldown.append((time + n, remaining))
        if cooldown and cooldown[0][0] == time:
            _, c = cooldown.popleft()             # `_` = throwaway for ready_time; tuple unpacking
            heapq.heappush(heap, c)
    return time
```
Greedy: always run the task with the most copies remaining. Heap + cooldown queue enforces the gap `n`. Proof is subtle — a closed-form `(max_count-1) * (n+1) + tied_top` also works; heap simulation is safer in interviews.

### Template G — Exchange-argument template (fractional / Huffman / MST)
```python
# Fractional knapsack — sort by value-per-weight, take greedily
def fractional_knapsack(items, capacity):
    items.sort(key=lambda it: it[0] / it[1], reverse=True)   # key lambda — runs for EACH item; watch zero-weight (ZeroDivisionError)
    total = 0.0                                   # float seed — promotes arithmetic to float throughout
    for value, weight in items:
        if capacity >= weight:
            total += value
            capacity -= weight
        else:
            total += value * (capacity / weight)  # `/` is TRUE division (float); `//` would floor
            break                                 # remaining capacity fully used — stop scanning
    return total
```
Why it works: if the optimum doesn't take the highest ratio first, swap in as much of it as capacity allows and the objective strictly increases (or stays equal). Repeat → optimum = greedy.

### Template H — "Most-constrained first" / deadline scheduling
```python
import heapq

def max_jobs_before_deadline(jobs):
    """jobs: list of (deadline, profit). Each job takes 1 time unit."""
    jobs.sort(key=lambda j: j[0])                 # sort ascending by deadline — process most-constrained first
    heap = []                                     # min-heap of accepted profits; root = worst kept job
    for deadline, profit in jobs:
        heapq.heappush(heap, profit)              # TENTATIVELY accept
        if len(heap) > deadline:                  # infeasible — can only do `deadline` jobs by time `deadline`
            heapq.heappop(heap)                   # evict current WORST profit — keep cardinality at `deadline`
    return sum(heap)                              # sum of a list is O(n); works on heap because heap IS a list
```
Process jobs in deadline order; greedily accept each and kick out the least-profitable one if the schedule is now infeasible. Classic trick: "accept-and-maybe-replace" via a min-heap keyed on the regret metric (smallest profit already accepted).

## 4. Classic Problems
- **LC 55 — Jump Game** (Medium): track furthest reachable index.
- **LC 45 — Jump Game II** (Medium): BFS-flavoured layered reach expansion.
- **LC 253 — Meeting Rooms II** (Medium): heap of active end times.
- **LC 435 — Non-Overlapping Intervals** (Medium): sort by end, keep earliest-finishing.
- **LC 452 — Minimum Arrows to Burst Balloons** (Medium): sort by end, shoot at earliest end.
- **LC 621 — Task Scheduler** (Medium): frequency-max greedy with cooldown.
- **LC 763 — Partition Labels** (Medium): expand the current window to the last index of any included letter.
- **LC 134 — Gas Station** (Medium): if total gas ≥ total cost, start wherever deficit resets.
- **LC 135 — Candy** (Hard): two sweeps — left-to-right then right-to-left taking max.
- **LC 402 — Remove K Digits** (Medium): monotonic stack = greedy-keep-smallest-prefix.
- **LC 11 — Container With Most Water** (Medium): two-pointer greedy on height.
- **LC 1353 — Maximum Events You Can Attend** (Medium): heap-based deadline greedy.

## 5. Worked Example — Non-Overlapping Intervals (LC 435)
Problem: given intervals, return the **minimum** number to remove so the rest do not overlap.

Input: `intervals = [[1,2], [2,3], [3,4], [1,3]]`.

### Claim and proof
The optimum **keeps the earliest-finishing compatible intervals** and removes the rest.

> *Stay-ahead proof (sketch)*: let `G = g_1, g_2, ..., g_k` be the greedy picks (each chosen as the earliest end time among intervals starting ≥ previous end) and `O = o_1, o_2, ..., o_m` any optimum. By induction on `i`, `end(g_i) ≤ end(o_i)` — the greedy's `i`-th interval finishes no later than the optimum's `i`-th. Therefore greedy never runs out of compatible intervals before the optimum, so `k ≥ m`, hence `k = m` and greedy is optimal.

> *Exchange proof (sketch)*: take any optimum `O`. If `O`'s first interval finishes later than `G`'s, swap `g_1` in for `o_1`. The new `O'` is still non-overlapping (greedy's interval finishes earlier, so anything compatible with `o_1` is compatible with `g_1`) and has the same size. Iterate → `O` becomes `G`.

### Implementation
```python
def eraseOverlapIntervals(intervals):
    intervals.sort(key=lambda iv: iv[1])           # sort by end — stable sort keeps input order on ties
    kept, last_end = 0, float("-inf")              # tuple-unpack ASSIGNMENT — two names in one line
    for s, e in intervals:
        if s >= last_end:
            kept += 1
            last_end = e
    return len(intervals) - kept                   # min removals = total - kept
```

### Trace
Sort by end: `[[1,2], [2,3], [1,3], [3,4]]` (note `[2,3]` and `[1,3]` tie on end = 3; Python's stable sort keeps input order).

| step | interval | `s` | `e` | `last_end` before | `s >= last_end`? | decision | `kept` after | `last_end` after |
|---|---|---|---|---|---|---|---|---|
| 1 | `[1,2]` | 1 | 2 | −∞ | yes | keep | 1 | 2 |
| 2 | `[2,3]` | 2 | 3 | 2 | `2 >= 2` ✔ | keep | 2 | 3 |
| 3 | `[1,3]` | 1 | 3 | 3 | `1 >= 3` ✘ | **remove** | 2 | 3 |
| 4 | `[3,4]` | 3 | 4 | 3 | `3 >= 3` ✔ | keep | 3 | 4 |

`kept = 3`, total = 4 → return `4 − 3 = 1` (remove `[1,3]`).

### Why *earliest end* and not *earliest start*?
Consider `[[1,100], [2,3], [3,4]]`:
- Sorted by start: greedy picks `[1,100]`, blocks everything → keeps 1.
- Sorted by end: greedy picks `[2,3]` then `[3,4]` → keeps 2.
The earliest-start rule has no stay-ahead guarantee; a long interval starting first monopolises the timeline. Earliest-end maximises leftover room for subsequent intervals.

### Why not DP?
A DP solution exists: sort by end, let `dp[i]` = max non-overlapping intervals ending at or before index `i`; transition by binary-searching the last compatible interval. That is `O(n log n)` too but with extra bookkeeping. The greedy sweep matches its complexity with a single linear pass — no array, no binary search.

Complexity: sort `O(n log n)` + sweep `O(n)` = **`O(n log n)`** total, `O(1)` auxiliary (ignoring sort).

### Edge cases
- Empty input → `kept = 0`, return 0.
- All intervals identical → keep one, remove the rest.
- All pairwise disjoint → keep all, remove 0.
- Interval touching endpoints (`[1,2]` vs `[2,3]`): depends on "touch ⇒ overlap?" — for LC 435, `s >= last_end` (equality allowed) is correct; for "meetings" semantics use `>`.

## 6. Common Variations
- **Interval scheduling maximisation** — same algorithm; report `kept` instead of `n - kept`.
- **Minimum arrows to burst balloons** (LC 452) — sort by end, shoot at `end`, skip balloons already hit by that shot; count distinct shots.
- **Meeting rooms II** (LC 253) — sort by start, heap of end times; room count = final heap size.
- **Partition labels** (LC 763) — sweep once to find last-seen index of each letter, then expand current partition's right boundary as you walk.
- **Jump game I** (LC 55) — maintain `reach = max(reach, i + nums[i])`; fail if `i > reach`.
- **Jump game II** (LC 45) — layered expansion: increment `jumps` when `i` reaches current window end.
- **Gas station** (LC 134) — if total supply ≥ total demand, the unique starting station is where the running deficit resets to 0.
- **Candy distribution** (LC 135) — two-pass greedy: left-to-right ensures increasing neighbour gets +1, right-to-left takes max.
- **Task scheduler** (LC 621) — frequency-max greedy with cooldown queue; closed form `max((max_count-1)*(n+1) + ties, len(tasks))`.
- **Remove K digits** (LC 402) — monotonic-stack greedy: pop larger digits off the stack while budget remains.
- **Huffman coding** — repeatedly merge two smallest-frequency nodes (min-heap of frequencies).
- **Kruskal's MST** — sort edges by weight, add if endpoints are in different DSU components (pattern 22).
- **Fractional knapsack** — sort by value-per-weight ratio; take full items greedily, split the last.
- **Deadline scheduling** (earliest deadline first, EDF) — process jobs in deadline order; heap of accepted jobs lets you replace the lowest-profit job when capacity is exceeded.
- **Counter-examples that break naive greedy**: 0/1 knapsack (must DP — ratio-greedy can be arbitrarily bad), general coin change, weighted activity selection (profit-weighted activities require DP).

## 7. Related Patterns
- **Sorting** — nearly every greedy starts with a sort by the greedy key.
- **Heap / Priority Queue (19)** — when "best remaining" changes after each commit.
- **Monotonic Stack / Queue** — a kind of online greedy that maintains a stack invariant (pop dominated items).
- **Intervals** — many greedy problems are interval problems (activity selection, meeting rooms, burst balloons).
- **Two Pointers** — same family (sort + sweep), but two pointers converges from both ends; greedy accumulates linearly.
- **Dynamic Programming (25)** — fallback when greedy-choice property fails; DP over the sorted order is a frequent pattern (weighted activity selection, edit distance, 0/1 knapsack).
- **Union-Find (22)** — Kruskal's MST is greedy + DSU for cycle prevention.
- **Graph BFS (20)** — Jump Game II, 0-1 BFS, and Dijkstra are greedy BFS variants that always expand the best frontier first.

Distinguishing note: whenever you propose a greedy rule, **try to break it** with a 2- or 3-element counterexample before trusting it. If no counterexample surfaces, also sketch an exchange or stay-ahead argument. A greedy that "feels right" with no proof is how wrong submissions pass sample tests and fail hidden ones; a greedy that provably swaps-in is how you walk out of an interview with the `O(n log n)` solution the interviewer was hoping for. If you cannot do either, drop to DP — two polynomial solutions in hand beat one unverified heuristic.
