# 23 — Topological Sort

## 1. When to Use
- You have a **directed acyclic graph (DAG)** and need a linear order that respects every edge `u -> v` (`u` appears before `v`).
- The keyword smell test: *"course schedule"*, *"build order"*, *"task dependencies"*, *"prerequisites"*, *"compilation order"*, *"alien dictionary"*, *"parallel / minimum semesters"*, *"job pipeline"*, *"spreadsheet recalculation"*, *"Makefile"*.
- You also need to **detect whether a directed graph has a cycle** — Kahn's algorithm tells you both in the same pass: if fewer than `n` nodes come out, the residual graph contains a cycle.
- You want to **process nodes after all predecessors** (DAG DP — longest path, reachability counts, expected value propagation).
- You need a **lexicographically smallest** or otherwise prioritised valid order (swap the queue for a heap).
- You are peeling a tree / DAG from the **outside in** (LC 310 min-height trees, level-by-level "leaves" peel).
- You need to enumerate **every possible topological order** (rare — backtracking over choices of in-degree-0 nodes).

Reach for a **different pattern** when:
- The graph is undirected and you only need connectivity → Union-Find or plain BFS/DFS.
- The graph has cycles and you still need an order of SCCs → Tarjan / Kosaraju, then topo sort on the condensation DAG.
- You need shortest path on a general weighted graph → Dijkstra / Bellman-Ford, not topo sort.

## 2. Core Idea
In any DAG, **at least one node has in-degree 0** — it depends on nothing. Remove such a node, decrement the in-degrees of its successors, and repeat. The order of removal is a valid topological order. If the graph ever runs out of in-degree-0 nodes before exhausting `n`, a cycle exists in what remains.

Two equivalent formulations:

| Algorithm | Direction | Cycle detection | Natural output |
|---|---|---|---|
| **Kahn's (BFS)** | peel from sources forward | `len(order) < n` | topo order directly |
| **DFS post-order reversed** | recurse forward, append on finish | three-colour GRAY re-entry | `reversed(post_order)` |

Invariant during Kahn's: every node popped from the queue has **zero remaining incoming edges from un-popped nodes**. Put another way, the queue holds the current "sources" of the residual graph.

Invariant during DFS topo sort: when `visit(u)` returns, every descendant of `u` has already been appended to `post_order`. Reversing gives "parent before child" in the edge sense.

Complexity for both: **`O(V + E)`** time, `O(V + E)` space for the adjacency list, `O(V)` extra for the queue / colour array. Kahn's is iterative (no recursion limits); DFS is cleaner when you also need finish times, bridges, or SCCs.

## 3. Templates

### Template A — Kahn's algorithm (canonical BFS topo sort)
```python
from collections import deque, defaultdict

def topo_sort(n, edges):
    """edges: list of (u, v) meaning u must come before v."""
    indeg = [0] * n
    adj = defaultdict(list)
    for u, v in edges:
        adj[u].append(v)
        indeg[v] += 1

    q = deque(i for i in range(n) if indeg[i] == 0)
    order = []
    while q:
        u = q.popleft()
        order.append(u)
        for v in adj[u]:
            indeg[v] -= 1
            if indeg[v] == 0:
                q.append(v)

    return order if len(order) == n else None     # None ⇒ cycle
```
Mental model: the queue holds every "source" of the residual graph; popping one is safe because it has no un-emitted predecessor.

### Template B — DFS post-order (three-colour)
```python
from collections import defaultdict

def topo_sort_dfs(n, edges):
    adj = defaultdict(list)
    for u, v in edges:
        adj[u].append(v)

    WHITE, GRAY, BLACK = 0, 1, 2
    color = [WHITE] * n
    order = []

    def visit(u):
        if color[u] == GRAY:
            raise ValueError("cycle")             # back-edge ⇒ cycle
        if color[u] == BLACK:
            return
        color[u] = GRAY
        for v in adj[u]:
            visit(v)
        color[u] = BLACK
        order.append(u)                           # post-order append

    for u in range(n):
        if color[u] == WHITE:
            visit(u)

    return order[::-1]                            # reverse post-order
```
Use this when you already have a DFS skeleton or want finish times for SCC / bridges.

### Template C — Lexicographically smallest order (heap Kahn's)
```python
import heapq
from collections import defaultdict

def topo_sort_lex(n, edges):
    indeg = [0] * n
    adj = defaultdict(list)
    for u, v in edges:
        adj[u].append(v)
        indeg[v] += 1

    heap = [i for i in range(n) if indeg[i] == 0]
    heapq.heapify(heap)
    order = []
    while heap:
        u = heapq.heappop(heap)
        order.append(u)
        for v in adj[u]:
            indeg[v] -= 1
            if indeg[v] == 0:
                heapq.heappush(heap, v)

    return order if len(order) == n else None
```
Every time several nodes are simultaneously "ready", pick the smallest. Used in build systems for deterministic output or in problems asking *"return the smallest topological order"*.

### Template D — Parallel / minimum semesters (layered Kahn's, LC 1136)
```python
from collections import deque, defaultdict

def min_semesters(n, edges):
    indeg = [0] * (n + 1)                         # 1-indexed
    adj = defaultdict(list)
    for u, v in edges:
        adj[u].append(v)
        indeg[v] += 1

    q = deque(i for i in range(1, n + 1) if indeg[i] == 0)
    semesters = 0
    processed = 0
    while q:
        semesters += 1
        for _ in range(len(q)):                   # freeze current layer
            u = q.popleft()
            processed += 1
            for v in adj[u]:
                indeg[v] -= 1
                if indeg[v] == 0:
                    q.append(v)

    return semesters if processed == n else -1
```
The trick is the `for _ in range(len(q))` layer freeze — identical to level-order tree BFS. Each layer is a "semester" in which every in-degree-0 node can be taken simultaneously.

### Template E — DAG DP via topo order (longest path / count paths)
```python
def longest_path_dag(n, edges):
    order = topo_sort(n, edges)                   # from Template A
    adj = defaultdict(list)
    for u, v in edges:
        adj[u].append(v)

    dp = [0] * n                                  # longest path ending at each node
    for u in order:
        for v in adj[u]:
            if dp[u] + 1 > dp[v]:
                dp[v] = dp[u] + 1

    return max(dp)
```
The whole point of a topo sort is that when you reach `u`, every predecessor's `dp` is final. This is the same shape as counting paths, computing reachability, propagating expected values, or any other forward DAG DP.

### Template F — Cycle detection only (Kahn's with counter)
```python
def has_cycle_directed(n, edges):
    indeg = [0] * n
    adj = defaultdict(list)
    for u, v in edges:
        adj[u].append(v)
        indeg[v] += 1

    q = deque(i for i in range(n) if indeg[i] == 0)
    seen = 0
    while q:
        u = q.popleft()
        seen += 1
        for v in adj[u]:
            indeg[v] -= 1
            if indeg[v] == 0:
                q.append(v)

    return seen != n
```
Strip out the `order` list when you only care *is the graph a DAG?*. Often faster to reason about than three-colour DFS on large inputs.

### Template G — Alien Dictionary (LC 269): derive edges, then topo sort
```python
from collections import defaultdict, deque

def alienOrder(words):
    adj = defaultdict(set)
    indeg = {c: 0 for w in words for c in w}

    for a, b in zip(words, words[1:]):
        if len(a) > len(b) and a.startswith(b):
            return ""                             # invalid: prefix after full word
        for x, y in zip(a, b):
            if x != y:
                if y not in adj[x]:
                    adj[x].add(y)
                    indeg[y] += 1
                break                             # only first differing pair matters

    q = deque([c for c, d in indeg.items() if d == 0])
    out = []
    while q:
        c = q.popleft()
        out.append(c)
        for nxt in adj[c]:
            indeg[nxt] -= 1
            if indeg[nxt] == 0:
                q.append(nxt)

    return "".join(out) if len(out) == len(indeg) else ""
```
Two-phase problems: **build the graph from problem-specific rules, then run Kahn's**. The prefix-validity check on the invalid case is the standard subtle edge.

### Template H — Minimum Height Trees (LC 310): leaf-peeling
```python
from collections import defaultdict, deque

def findMinHeightTrees(n, edges):
    if n <= 2:
        return list(range(n))

    adj = defaultdict(set)
    for u, v in edges:
        adj[u].add(v)
        adj[v].add(u)

    leaves = deque(i for i in range(n) if len(adj[i]) == 1)
    remaining = n
    while remaining > 2:
        layer_size = len(leaves)
        remaining -= layer_size
        for _ in range(layer_size):
            leaf = leaves.popleft()
            neighbour = adj[leaf].pop()           # leaf has exactly one neighbour
            adj[neighbour].remove(leaf)
            if len(adj[neighbour]) == 1:
                leaves.append(neighbour)

    return list(leaves)
```
Undirected "topological" peel: leaves are the in-degree-1 nodes. Peel them in layers; whatever remains after all but 1-2 nodes are gone are the centroids.

## 4. Classic Problems
- **LC 207 — Course Schedule** (Medium): DAG check (can-we-finish?).
- **LC 210 — Course Schedule II** (Medium): return any valid order — canonical Kahn's.
- **LC 269 — Alien Dictionary** (Hard): derive letter order from adjacent word comparisons, then topo sort.
- **LC 310 — Minimum Height Trees** (Medium): topological-style leaf peeling on an undirected tree.
- **LC 329 — Longest Increasing Path in a Matrix** (Hard): DAG of cells → memoised DFS (implicit topo order).
- **LC 444 — Sequence Reconstruction** (Medium): is the unique topo order equal to the given sequence?
- **LC 802 — Find Eventual Safe States** (Medium): reverse-graph topo sort.
- **LC 1136 — Parallel Courses** (Medium): BFS layer count = minimum semesters.
- **LC 2192 — All Ancestors of a Node in a DAG** (Medium): topo-order + DP over predecessors.

## 5. Worked Example — Course Schedule II (LC 210)
Problem: `numCourses = 4`, `prerequisites = [[1,0],[2,0],[3,1],[3,2]]`. Return any valid order.

> LC convention: `[a, b]` means "to take `a` you must first take `b`", i.e. the directed edge is `b -> a`.

Edges as `prereq -> course`:
- `0 -> 1`
- `0 -> 2`
- `1 -> 3`
- `2 -> 3`

Graph (arrows point from prereq to course):
```
      0
     / \
    v   v
    1   2
     \ /
      v
      3
```
Initial in-degrees: `[0, 1, 1, 2]`.

Implementation:
```python
from collections import deque, defaultdict

def findOrder(numCourses, prerequisites):
    indeg = [0] * numCourses
    adj = defaultdict(list)
    for a, b in prerequisites:
        adj[b].append(a)                          # b -> a
        indeg[a] += 1

    q = deque(i for i in range(numCourses) if indeg[i] == 0)
    order = []
    while q:
        u = q.popleft()
        order.append(u)
        for v in adj[u]:
            indeg[v] -= 1
            if indeg[v] == 0:
                q.append(v)

    return order if len(order) == numCourses else []
```

Step-by-step trace:

| step | queue before | popped `u` | successors of `u` | in-degree updates | queue after | `order` |
|---|---|---|---|---|---|---|
| init | `[0]` | — | — | `[0, 1, 1, 2]` | `[0]` | `[]` |
| 1 | `[0]` | 0 | `1, 2` | `1: 1→0` (enq), `2: 1→0` (enq) | `[1, 2]` | `[0]` |
| 2 | `[1, 2]` | 1 | `3` | `3: 2→1` | `[2]` | `[0, 1]` |
| 3 | `[2]` | 2 | `3` | `3: 1→0` (enq) | `[3]` | `[0, 1, 2]` |
| 4 | `[3]` | 3 | — | — | `[]` | `[0, 1, 2, 3]` |

All four courses processed → return `[0, 1, 2, 3]`. Any order that places `0` before `{1, 2}` and `{1, 2}` before `3` is valid; for example `[0, 2, 1, 3]` would also pass the grader. Time `O(V + E)`, space `O(V + E)`.

### What if there were a cycle?
Add the extra edge `3 -> 0`:
- `indeg = [1, 1, 1, 2]` — nothing starts at zero.
- Queue begins empty, loop never runs, `order = []`.
- `len(order) != numCourses` → return `[]` (no valid order, cycle detected).

### What if we wanted the lexicographically smallest valid order?
Swap `deque` for a min-heap (Template C). Trace under the original edges:
1. Heap `[0]`; pop `0`; push `1, 2` → heap `[1, 2]`.
2. Pop `1` (smaller); decrement `3` to `1` (not zero) → heap `[2]`.
3. Pop `2`; decrement `3` to `0`, push → heap `[3]`.
4. Pop `3`; done → `[0, 1, 2, 3]`.

The two orders coincide here; they diverge when two zero-in-degree nodes compete (e.g. adding a disjoint course `4` would be interleaved by BFS insertion order but placed strictly after `3` by the heap if `3 < 4`).

### What about "minimum semesters" framing?
Under LC 1136 semantics (`1`-indexed, same edges), Template D gives:
- Layer 1 (`semesters = 1`): queue has `{0}` → process → reveals `{1, 2}`.
- Layer 2 (`semesters = 2`): queue has `{1, 2}` → process both → reveals `{3}`.
- Layer 3 (`semesters = 3`): queue has `{3}` → process → done.
Answer: **3 semesters**. Same DAG, same edges, different question — the pattern bends without rewriting.

## 6. Common Variations
- **Cycle-only check** (LC 207): skip the `order` list; `seen == n` is the answer.
- **Lexicographically smallest order** (LC 269, LC 1203): min-heap instead of deque in Kahn's.
- **All valid orders**: Kahn's with backtracking — at each step, branch on *every* zero-in-degree node, undo the removal, continue. Exponential but necessary for enumeration problems.
- **Longest / shortest path on DAG**: topo-order once, relax edges in order. Beats Bellman-Ford's `O(VE)` to `O(V + E)`.
- **Counting paths / DAG DP**: replace `max` with `sum` for path-counts; replace with custom merge for e.g. expected-value propagation.
- **Parallel layered** (LC 1136): freeze queue length per iteration — identical to tree level-order BFS.
- **Reverse-graph topo** (LC 802 Find Eventual Safe States): flip every edge, run Kahn's on the reversed graph — safe nodes are the ones that get emitted.
- **Unique-sequence verification** (LC 444): at each step the queue must contain **exactly one** candidate, and it must match the given sequence's next element.
- **Alien Dictionary** (LC 269): build edges from pairwise word comparisons; beware the invalid case where a longer word appears before its prefix.
- **Undirected leaf-peel** (LC 310 MHT): symmetric to Kahn's but on in-degree-1 nodes; at most two centroids remain.
- **Memoised DFS as implicit topo** (LC 329 longest increasing path in matrix): no explicit topo sort needed — the recursion stack itself follows DAG edges because `@lru_cache` guarantees each cell is computed once.
- **Dynamic / streaming DAG**: if edges are inserted online, recomputing the full topo sort is `O(V + E)`; for single-edge updates, specialised algorithms (Pearce-Kelly) run in sub-linear amortised time.
- **Edge cases**: no edges (any permutation is a valid order), duplicate edges (increment in-degree each time — Kahn's self-corrects), self-loop (`u -> u` is an immediate cycle), disconnected components (Kahn's seeds every zero-in-degree node — all components are processed).

## 7. Related Patterns
- **Graph BFS (20)** — Kahn's is literally a BFS whose frontier is "currently in-degree-0 nodes".
- **Graph DFS (21)** — alternative topo sort via reverse post-order; shares the three-colour cycle detector.
- **Tree BFS / Level Order (17)** — the layered variant of Kahn's is tree level-order in disguise.
- **Dynamic Programming on DAGs (25)** — topological sort is the ordering you DP over.
- **Union-Find (22)** — for *undirected* connectivity, not directed ordering; no concept of "before / after".
- **Shortest / Longest Path** — in a DAG, topo-ordering the vertices lets you relax edges in `O(V + E)` instead of Dijkstra's `O(E log V)`.
- **SCC (Tarjan / Kosaraju)** — if cycles exist, condense the graph into its SCCs first; the condensation is a DAG and then topo sorts normally.

Distinguishing note: any problem framed as directed **dependencies** ("X must happen before Y") without cycles is a topological-sort problem. If the graph might have cycles, Kahn's is your *detector* as well as your solution — `len(order) != n` fires exactly when a cycle lurks in what remains. Reach for the DFS post-order variant when you also need finish times, bridges, or SCCs; reach for the heap variant when order ties must break deterministically; reach for the layered variant when the question asks *"how many rounds?"* instead of *"what order?"*.
