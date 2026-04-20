# 21 — Graph DFS

## 1. When to Use
- You need to **explore every reachable node** or every path from a source.
- Keywords: *"connected components"*, *"cycle detection"*, *"flood fill"*, *"number of islands"*, *"path exists"*, *"all paths from source to target"*, *"strongly connected components"*, *"topological sort (DFS-based)"*, *"bridges"*, *"articulation points"*, *"biconnected components"*, *"Eulerian path"*, *"clone graph"*.
- You care about **structural properties** of the traversal: back-edges, tree-edges, forward-edges, cross-edges, discovery/finish times, DFS tree.
- Grid problems where you paint / explore connected regions of the same value (flood fill, islands, paint filling).
- You can afford `O(V + E)` work and only need **reachability**, not shortest distance.
- You need to enumerate **all simple paths** between two nodes in a DAG (LC 797).
- The graph is implicit (states of a problem) and you want depth-first exhaustive search — not shortest-path.

### Signals this is NOT a Graph DFS problem
- You need the **shortest** path in an unweighted graph → BFS.
- You need shortest path with weights → Dijkstra / Bellman-Ford.
- You only need connectivity over a stream of edges → Union-Find.
- You need to process a DAG in dependency order → topological sort (either DFS finish-time or Kahn's BFS).

## 2. Core Idea
DFS goes **as deep as possible along each branch before backtracking**. The call stack naturally encodes the current path — the set of ancestors of the currently-visited node. This makes DFS the natural fit for **path-aware** problems: cycle detection (a back-edge to an ancestor is a cycle), connected components (each DFS tree = one component), topological order (reverse finish-time), articulation points and bridges (low-link DFS). It gives reachability and edge classification but **not shortest distances** on unweighted graphs — that is BFS's territory.

### The three-colour invariant (directed cycle detection)
Mark each node **WHITE** (unvisited), **GRAY** (on the current DFS path), or **BLACK** (finished). When exploring `u → v`:
- `v == WHITE` → tree edge; recurse.
- `v == GRAY` → **back edge** → cycle detected.
- `v == BLACK` → cross / forward edge; no cycle, skip.

This is the canonical way to detect cycles in **directed** graphs. Plain `seen` (two-colour) is insufficient because it confuses cross edges with back edges.

### Undirected cycle detection
For undirected graphs, a simple `seen` set works if you **track the parent**: if you encounter an already-visited neighbour that is not your immediate parent, you've found a cycle. Alternative: Union-Find.

### Edge classification (DFS tree)
A DFS on a directed graph partitions edges into:
- **Tree edges**: produced by the DFS recursion.
- **Back edges**: `u → v` where `v` is an ancestor of `u` in the DFS tree (cycle).
- **Forward edges**: `u → v` where `v` is a descendant of `u` but not via a tree edge.
- **Cross edges**: `u → v` where `v` is neither ancestor nor descendant (e.g. in another subtree or component).

Back-edge presence ↔ cycle existence. DFS finish-times give the topological order (reverse of finish order on a DAG).

### Strong vs weak connectivity
- **Undirected**: "connected" = every pair reachable. DFS from any start covers the component.
- **Directed**:
  - **Weakly connected**: connected when edges are treated as undirected.
  - **Strongly connected**: every pair mutually reachable. Found via Tarjan's or Kosaraju's algorithm — both are DFS-based.

## 3. Template

### Template A — recursive DFS (reachability / flood fill)
```python
def dfs(u, neighbours, seen):
    if u in seen: return                      # base case — no explicit return value means returns None
    seen.add(u)                               # MUTATE caller's set in place — no need to return it
    for v in neighbours(u):
        dfs(v, neighbours, seen)              # Python default recursion limit is 1000 — deep graphs need sys.setrecursionlimit
```

### Template B — iterative DFS (stack; avoids recursion-depth limits)
```python
def dfs_iter(src, neighbours):
    seen = set()                              # empty set — `set()`, NOT `{}` (which is an empty DICT)
    stack = [src]                             # Python list doubles as a stack — .pop() defaults to last element
    while stack:
        u = stack.pop()                       # pop() from list is O(1); pop(0) would be O(n) — use deque if popping left
        if u in seen: continue                # re-check on POP — we may have pushed u multiple times before marking it
        seen.add(u)
        for v in neighbours(u):
            if v not in seen:                 # pre-check on PUSH shrinks stack but doesn't guarantee dedup
                stack.append(v)
    return seen
```

### Template C — connected components count (undirected)
```python
def count_components(n, edges):
    g = [[] for _ in range(n)]                # LIST COMP — do NOT write [[]]*n (all rows alias the same list)
    for a, b in edges:
        g[a].append(b); g[b].append(a)        # undirected — add both directions
    seen = [False] * n                        # [False]*n is SAFE: bool is immutable, no alias problem
    def dfs(u):                               # closure captures `g` and `seen` from enclosing scope
        seen[u] = True
        for v in g[u]:
            if not seen[v]:
                dfs(v)
    components = 0
    for u in range(n):                        # MUST iterate every node — graph may be disconnected
        if not seen[u]:
            dfs(u); components += 1           # each unvisited root discovers exactly one new component
    return components
```

### Template D — directed cycle detection (three colours)
```python
def has_cycle(graph):
    WHITE, GRAY, BLACK = 0, 1, 2              # tuple-unpack ASSIGNMENT — three constants in one line
    color = {u: WHITE for u in graph}         # dict comp — keys are the nodes

    def visit(u):
        color[u] = GRAY                       # mark as ON CURRENT PATH before recursion
        for v in graph[u]:
            if color[v] == GRAY:              # back edge → cycle; GRAY means ancestor on the recursion stack
                return True
            if color[v] == WHITE and visit(v):  # short-circuit: recurse only if unvisited; early-exit on sub-cycle
                return True
        color[u] = BLACK                      # fully processed — LEAVES the current path
        return False

    return any(color[u] == WHITE and visit(u) for u in graph)  # `any` short-circuits at first True — skips BLACK nodes
```

### Template E — grid DFS / flood fill
```python
DIRS = ((1, 0), (-1, 0), (0, 1), (0, -1))     # tuple of tuples — immutable; hoist out of function

def flood_fill(grid, r, c, target, replacement):
    m, n = len(grid), len(grid[0])
    if grid[r][c] != target or target == replacement:
        return                                # second check guards against infinite recursion on no-op fill
    def dfs(r, c):
        if not (0 <= r < m and 0 <= c < n): return  # bounds first — short-circuit protects grid[r][c] from IndexError
        if grid[r][c] != target: return       # `!=` check doubles as visited check (replacement != target)
        grid[r][c] = replacement              # MUTATE grid as the "seen" marker — no separate set needed
        for dr, dc in DIRS:
            dfs(r + dr, c + dc)               # Python int add is arbitrary-precision — never overflows
    dfs(r, c)
```

### Template F — DFS-based topological sort (finish-time reverse)
```python
def topo_sort(graph):
    WHITE, GRAY, BLACK = 0, 1, 2
    color = {u: WHITE for u in graph}
    order = []                                # will hold POST-ORDER finish sequence

    def visit(u):
        color[u] = GRAY
        for v in graph[u]:
            if color[v] == GRAY: raise ValueError("cycle")  # exceptions propagate out of recursion automatically
            if color[v] == WHITE: visit(v)    # if-guard, not elif — BLACK nodes are silently skipped
        color[u] = BLACK
        order.append(u)                       # post-order append — u is added AFTER its descendants

    for u in graph:                           # iteration over dict yields KEYS (same as .keys())
        if color[u] == WHITE: visit(u)
    return order[::-1]                        # `[::-1]` creates a REVERSED COPY — the original `order` is not mutated
```

### Template G — all simple paths source → target (DAG; backtracking)
```python
def all_paths(graph, src, dst):
    res = []
    path = [src]                              # single SHARED list — mutated as we walk; must COPY on record
    def dfs(u):
        if u == dst:
            res.append(path.copy()); return   # .copy() = shallow copy; `path[:]` works identically
        for v in graph[u]:
            path.append(v)                    # push — THIS is backtracking
            dfs(v)
            path.pop()                        # pop — MUST pair with append exactly; missing it corrupts siblings
    dfs(src)
    return res
```

### Template H — Tarjan's bridge-finding (low-link DFS)
```python
def find_bridges(n, edges):
    g = [[] for _ in range(n)]
    for a, b in edges:
        g[a].append(b); g[b].append(a)
    disc = [-1] * n                           # discovery time — -1 sentinel for unvisited
    low = [-1] * n                            # lowest disc reachable from subtree (low-link)
    bridges = []
    timer = [0]                               # one-element LIST — mutable box; lets closure REBIND without `nonlocal`

    def dfs(u, parent):
        disc[u] = low[u] = timer[0]; timer[0] += 1  # chained assignment — both names point to same int value
        for v in g[u]:
            if disc[v] == -1:
                dfs(v, u)
                low[u] = min(low[u], low[v])   # propagate child's low-link upward after recursion returns
                if low[v] > disc[u]:
                    bridges.append((u, v))    # bridge: no back-edge bypasses this edge
            elif v != parent:                 # ignore the edge we came in on — avoids false back-edge on undirected
                low[u] = min(low[u], disc[v])
    for u in range(n):
        if disc[u] == -1: dfs(u, -1)          # -1 as parent sentinel for roots — any non-node value works
    return bridges
```

Key mental tools:
- **Undirected cycle detection** uses a `seen` set + tracks the parent edge. If a neighbour is already seen and it's **not** the parent, that's a cycle.
- **Directed cycle detection** needs three colours (white/gray/black) to distinguish back-edges from cross/forward-edges.
- Build a clean `adj: dict[node, list[node]]` or `list[list[int]]` first — do not re-scan the edge list inside the recursion.
- On grids, "mark visited" by **writing a sentinel value in place** (saves a `seen` set and halves the constant factor). Restore if the caller needs the grid intact.
- For large grids (10^5 cells along a snake), Python's default recursion limit of 1000 is too low — use iterative DFS or `sys.setrecursionlimit(10**6)`.
- **DFS returns values when you need aggregates** (area, depth, component size). Void DFS only marks visited.
- **Post-order vs pre-order** is the same choice as with trees: post-order for subtree aggregates (island area, SCC), pre-order for distributing state.

## 4. Classic Problems
- **LC 200 — Number of Islands** (Medium): grid DFS / flood fill (Template E).
- **LC 695 — Max Area of Island** (Medium): same scan + DFS returning size.
- **LC 547 — Number of Provinces** (Medium): connected components on an adjacency matrix (Template C).
- **LC 133 — Clone Graph** (Medium): DFS with a `cloned` map to handle cycles.
- **LC 207 — Course Schedule** (Medium): directed cycle detection (Template D).
- **LC 210 — Course Schedule II** (Medium): DFS topological sort (Template F).
- **LC 417 — Pacific Atlantic Water Flow** (Medium): multi-source DFS from each ocean's boundary.
- **LC 130 — Surrounded Regions** (Medium): DFS from edges to mark "escape" regions.
- **LC 797 — All Paths From Source to Target** (Medium): DAG enumeration (Template G).
- **LC 261 — Graph Valid Tree** (Medium): exactly `n - 1` edges + no cycle.
- **LC 802 — Find Eventual Safe States** (Medium): DFS with three colours, safe = not on any cycle.
- **LC 1192 — Critical Connections in a Network** (Hard): Tarjan's bridges (Template H).

## 5. Worked Example — Course Schedule (LC 207)
Problem: you are given `numCourses` and `prerequisites`, a list of `[a, b]` meaning "to take course `a` you must first take `b`" (i.e. edge `b → a`). Return `True` if all courses can be finished — equivalently, if the prerequisite graph is a DAG (no cycle).

This is the canonical **directed cycle detection** problem. Two textbook approaches:
1. **DFS + three colours** (this walkthrough).
2. **Kahn's algorithm** (BFS on in-degrees) — file 23.

Input: `numCourses = 4`, `prerequisites = [[1, 0], [2, 1], [3, 2], [1, 3]]`. Build graph `b → a` for each `[a, b]`:
- `0 → 1`, `1 → 2`, `2 → 3`, `3 → 1`.

Visual:
```
0 → 1 → 2 → 3
        ↑    ↓
        └────┘        (3 → 1 creates a cycle 1 → 2 → 3 → 1)
```
Expected: `False` (cycle exists).

### Step 1. Why two-colour DFS fails here
A naive `seen` set based DFS would mark `0, 1, 2, 3` as visited on the first traversal from `0`. When we reach `3 → 1`, `1` is already in `seen` — but that doesn't tell us whether `1` is on the **current path** or merely visited earlier. Plain `seen` conflates:
- **Back edges** (to an ancestor in the DFS tree) — these indicate cycles.
- **Cross/forward edges** (to a different subtree or a descendant not on the path) — these are fine.

We need **three colours** to disambiguate.

### Step 2. Three-colour invariant
- **WHITE**: never visited.
- **GRAY**: currently on the recursion stack (ancestor of the current DFS frame).
- **BLACK**: fully explored; its entire subtree has been processed.

When exploring `u → v`:
- `v == WHITE` → recurse (tree edge).
- `v == GRAY` → **back edge** → cycle found; return `True`.
- `v == BLACK` → cross / forward edge → skip (no cycle implied).

On exiting `u`, set `color[u] = BLACK`.

### Step 3. Implement
```python
def canFinish(numCourses, prerequisites):
    graph = [[] for _ in range(numCourses)]   # LIST COMP (not [[]]*n which shares the same inner list!)
    for a, b in prerequisites:
        graph[b].append(a)                    # edge b → a — "to take a, first take b" means b points to a

    WHITE, GRAY, BLACK = 0, 1, 2              # tuple unpacking — readable constants
    color = [WHITE] * numCourses              # [0]*n safe — int is immutable

    def visit(u):
        color[u] = GRAY
        for v in graph[u]:
            if color[v] == GRAY: return True  # back edge → cycle → return TRUE meaning "cycle found"
            if color[v] == WHITE and visit(v): return True  # short-circuit: recurse then propagate early
        color[u] = BLACK
        return False

    for u in range(numCourses):
        if color[u] == WHITE and visit(u):    # `and` short-circuits — visit() only called on WHITE nodes
            return False                      # cycle means we CAN'T finish → return False to caller
    return True
```

### Step 4. Trace
Graph (adj list):
```
0: [1]
1: [2]
2: [3]
3: [1]
```

Start with `color = [W, W, W, W]`.

**Call `visit(0)`:** set `color[0] = GRAY`. `color = [G, W, W, W]`. Explore `graph[0] = [1]`.

  **Call `visit(1)`:** set `color[1] = GRAY`. `color = [G, G, W, W]`. Explore `graph[1] = [2]`.

    **Call `visit(2)`:** set `color[2] = GRAY`. `color = [G, G, G, W]`. Explore `graph[2] = [3]`.

      **Call `visit(3)`:** set `color[3] = GRAY`. `color = [G, G, G, G]`. Explore `graph[3] = [1]`.
      - `color[1] == GRAY` → **back edge detected** → return `True` (cycle).

    `visit(3)` returned `True`; `visit(2)` returns `True`.

  `visit(1)` returns `True`; `visit(0)` returns `True`.

Top-level: `visit(0)` returned `True` → cycle exists → return `False` (cannot finish courses).

### Step 5. Trace on a valid case (no cycle)
Consider `prerequisites = [[1, 0], [2, 1], [3, 2]]`:
- `0 → 1 → 2 → 3`, no back edge.

Trace visit(0) → visit(1) → visit(2) → visit(3). At 3, `graph[3]` is empty. Set `color[3] = BLACK`, return False. Back up to 2 → set `color[2] = BLACK`, return False. Back up through 1 → 0. All nodes black at the end. No cycle → function returns `True`.

### Step 6. Why GRAY is essential
If we used just a `seen` set instead, when DFS revisits node 1 via `3 → 1`:
- In the 4-course cyclic example, 1 is "seen" because it's an ancestor — correct cycle detection.
- But consider a DAG `0 → 1, 0 → 2, 2 → 1`. When we DFS from 0, we visit 1 (mark seen), backtrack, then visit 2, and from 2 try to visit 1. With plain `seen`, 1 is already seen — but it's a **cross edge**, not a back edge! Plain `seen` would flag this as a cycle when it isn't. Three colours distinguishes: at the moment `2 → 1` is explored, `color[1] == BLACK` (finished, not on path) → not a cycle.

### Step 7. Complexity
Time `O(V + E)` — each node goes WHITE → GRAY → BLACK once; each edge explored once. Space `O(V)` for colours + recursion stack.

### Step 8. Alternative — Kahn's BFS
Kahn's algorithm (file 23) achieves the same goal via in-degree BFS: repeatedly remove nodes with in-degree 0. If you can remove all `V` nodes, the graph is a DAG; if some remain, those are on cycles. Trade: BFS is iterative (no recursion limit), DFS produces a topological order "for free" as the reverse finish order.

## 6. Common Variations

### Grid DFS / flood fill
- **Number of islands** (LC 200): Template E.
- **Max area of island** (LC 695): return size from DFS.
- **Island perimeter** (LC 463): count water-adjacent edges during flood fill.
- **Surrounded regions** (LC 130): DFS from boundary 'O's; remaining 'O's get captured.
- **Pacific Atlantic water flow** (LC 417): DFS from each ocean's boundary.
- **Number of closed islands** (LC 1254): like 200 but discard boundary-touching islands.
- **Number of sub-islands** (LC 1905): flood-fill grid2, ensuring every cell lies in grid1.
- **Making a large island** (LC 827): label islands by id, then for each water cell compute merged-area.
- **Flood fill** (LC 733): exactly Template E.

### Connected components
- **Number of provinces** (LC 547): adjacency-matrix DFS.
- **Friend circles** (older name for LC 547).
- **Number of connected components in undirected graph** (LC 323): same shape.
- **Graph valid tree** (LC 261): exactly `n - 1` edges + connected + no cycle.

### Cycle detection / DAG validation
- **Course schedule** (LC 207): Template D.
- **Course schedule II** (LC 210): Template F to emit a valid order.
- **Find eventual safe states** (LC 802): node is safe iff not on any cycle.
- **Detect cycles in 2D grid** (LC 1559): undirected grid cycle detection.
- **Parallel courses** (LC 1136): topological sort; answer = longest path.

### DFS tree properties
- **Bridges / critical connections** (LC 1192): Tarjan's low-link DFS (Template H).
- **Articulation points**: similar low-link logic with a root-special-case.
- **Strongly connected components**: Tarjan's (stack + low-link) or Kosaraju's (2-pass DFS).
- **Biconnected components**: stack of edges + articulation points.
- **Eulerian path / circuit**: Hierholzer's algorithm — DFS emitting edges.

### Path enumeration / search
- **All paths source → target** (LC 797): Template G (DAG; for general graphs needs visited-on-path).
- **Keys and rooms** (LC 841): DFS with discovered keys unlocking new nodes.
- **Cheapest flights with k stops** (LC 787): DFS + memoisation — but BFS/Dijkstra is usually simpler.
- **Reconstruct itinerary** (LC 332): Hierholzer on Eulerian path (lexicographically smallest).

### DFS + memoisation (DP on DAG)
- **Longest increasing path in matrix** (LC 329): DFS with memo on each cell.
- **Largest colour value in DAG** (LC 1857): DFS with `(node, colour)` memo.
- **Unique paths III** (LC 980): DFS counting Hamiltonian paths on grid.

### Clone / deep-copy via DFS
- **Clone graph** (LC 133): map `original → clone`, DFS to copy structure.
- **Copy list with random pointer** (LC 138): also works via DFS/hash.

### Edge cases & pitfalls
- **Recursion depth** — for `V > 1000`, default Python limit breaks; use iterative (Template B) or raise the limit.
- **Self-loops** — `u → u` is a 1-cycle; three-colour DFS catches it because on entering `u` we set GRAY, then explore the self-loop and find `color[u] == GRAY`.
- **Multiple edges** — usually harmless for reachability, but duplicates the work; depending on the problem, consider deduplication.
- **Disconnected graphs** — always iterate starting points (e.g. `for u in range(n): if not seen[u]: dfs(u)`).
- **Directed vs undirected cycle detection** — different invariants; pick the right one.
- **Mutating the grid** for visited-marking — fine for one-shot; bad if caller expects grid unchanged. Restore or copy.
- **Wrong edge direction** — LC 207 gotcha: `[a, b]` means "a requires b"; edge is `b → a`. Miswire the direction and the entire algorithm is backwards.
- **Forgetting to advance past BLACK** — when `v == BLACK`, just skip; don't recurse and don't error.

## 7. Related Patterns
- **Graph BFS** — reachability peer; BFS adds shortest-path guarantee on unit edges.
- **Recursion / Backtracking** — DFS mechanics; DFS without "undo" is still DFS. Backtracking adds undo on the way out to enumerate configurations.
- **Topological Sort** — DFS with finish times, or Kahn's BFS.
- **Union Find** — faster for dynamic connectivity; DFS is one-shot.
- **Tree DFS** — the special case without cycles; no `visited` set needed (just avoid the parent edge).
- **Tarjan's / Kosaraju's SCC** — DFS-based; classic graph-theoretic output.
- **Dynamic Programming on DAG** — DFS + memoisation, or topological order + iteration.
- **Flood fill (image processing)** — DFS or BFS; same shape as Template E.
- **Iterative deepening DFS** — bounded-depth DFS repeated; used in games.

**Distinguishing note**: pick DFS when you care about **structural properties of the traversal** — components, cycles, topo order, back-edges, SCC, articulation points, enumerating paths. Pick BFS when you care about **distance** or **level-by-level** exploration. Pick **Union Find** when the graph is **growing online** and you only need connectivity. DFS's superpower is that the recursion stack **is** the current path — any algorithm that needs to know "am I on a cycle?" or "what ancestors got me here?" is a DFS algorithm.
