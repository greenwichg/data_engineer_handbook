# 21 — Graph DFS

## 1. When to Use
- You need to **explore every reachable node** or every path from a source.
- Keywords: *"connected components"*, *"cycle detection"*, *"flood fill"*, *"number of islands"*, *"path exists"*, *"all paths from source to target"*, *"strongly connected"*, *"topological sort (DFS-based)"*.
- You care about **structural properties** of the traversal: back-edges, discovery/finish times, DFS tree.
- Grid problems where you paint / explore connected regions of the same value.
- You can afford `O(V + E)` work and only need reachability, not shortest distance.

## 2. Core Idea
DFS goes as deep as possible along each branch before backtracking. The call stack naturally encodes the current path, which makes DFS the natural fit for **path-aware** problems (cycle detection, connected components, topological order, articulation points). It gives reachability and tree-edge classification but **not shortest distances** on unweighted graphs — that is BFS's territory.

## 3. Template
```python
# 1) Recursive DFS — reachability / flood fill
def dfs(u, neighbours, seen):
    if u in seen: return
    seen.add(u)
    for v in neighbours(u):
        dfs(v, neighbours, seen)

# 2) Iterative DFS (stack) — avoid recursion-depth limits
def dfs_iter(src, neighbours):
    stack = [src]; seen = set()
    while stack:
        u = stack.pop()
        if u in seen: continue
        seen.add(u)
        for v in neighbours(u):
            if v not in seen: stack.append(v)
    return seen

# 3) Cycle detection in a DIRECTED graph — three colours
def has_cycle(graph):
    WHITE, GRAY, BLACK = 0, 1, 2
    color = {u: WHITE for u in graph}
    def visit(u):
        color[u] = GRAY                  # on current path
        for v in graph[u]:
            if color[v] == GRAY: return True
            if color[v] == WHITE and visit(v): return True
        color[u] = BLACK                  # finished
        return False
    return any(visit(u) for u in graph if color[u] == WHITE)

# 4) Connected components count (undirected)
def count_components(n, edges):
    g = [[] for _ in range(n)]
    for a, b in edges: g[a].append(b); g[b].append(a)
    seen = [False] * n
    def dfs(u):
        seen[u] = True
        for v in g[u]:
            if not seen[v]: dfs(v)
    cnt = 0
    for u in range(n):
        if not seen[u]: dfs(u); cnt += 1
    return cnt
```
Key mental tools:
- **Undirected cycle detection** uses a `seen` set + tracks the parent edge.
- **Directed cycle detection** needs three states (white/gray/black) to distinguish cross-edges from back-edges.
- Build a clean `adj: dict[node, list[node]]` first — do not re-scan the edge list inside the recursion.
- On grids, "mark visited" by writing a sentinel value in place (saves a `seen` set).

## 4. Classic Problems
- **LC 200 — Number of Islands** (Medium): grid DFS / flood fill.
- **LC 133 — Clone Graph** (Medium): DFS with a `cloned` map to handle cycles.
- **LC 207 — Course Schedule** (Medium): directed cycle detection.
- **LC 547 — Number of Provinces** (Medium): connected components on an adjacency matrix.
- **LC 417 — Pacific Atlantic Water Flow** (Medium): multi-source DFS from each ocean.

## 5. Worked Example — Number of Islands (LC 200)
Problem: count connected components of `1`s in the grid (4-directional adjacency).

Input:
```
grid = [
  ['1','1','0','0','0'],
  ['1','1','0','0','0'],
  ['0','0','1','0','0'],
  ['0','0','0','1','1'],
]
```
Approach: scan cells; when a `'1'` is found, increment count and DFS-flood-fill that entire island to `'0'` so it is not counted again.

```python
def numIslands(grid):
    if not grid: return 0
    m, n = len(grid), len(grid[0])

    def dfs(r, c):
        if r < 0 or r >= m or c < 0 or c >= n: return
        if grid[r][c] != '1': return
        grid[r][c] = '0'                 # sink the cell
        dfs(r+1, c); dfs(r-1, c)
        dfs(r, c+1); dfs(r, c-1)

    islands = 0
    for r in range(m):
        for c in range(n):
            if grid[r][c] == '1':
                islands += 1
                dfs(r, c)
    return islands
```

Trace at the scan level (grid reads row-major, left-to-right):

| cell visited | is `'1'`? | `islands` after | which island gets sunk |
|---|---|---|---|
| (0,0) | yes | 1 | sinks (0,0), (0,1), (1,0), (1,1) |
| (0,1) | now `'0'` | 1 | skip |
| ... (row 0 and row 1 remaining) | all `'0'` | 1 | skip |
| (2,2) | yes | 2 | sinks (2,2) only (isolated) |
| (3,3) | yes | 3 | sinks (3,3), (3,4) |
| (3,4) | now `'0'` | 3 | skip |

Return `3`. Time `O(m*n)` (each cell is visited a constant number of times); space `O(m*n)` worst case for the recursion depth on a single solid island.

The pattern scales: LC 695 (max island area), LC 1254 (closed islands), LC 1905 (sub-islands) are all variations on "scan, DFS-flood-fill, count/measure".

## 6. Common Variations
- **Iterative DFS on grids**: replace recursion with a stack to avoid Python's 1000-frame limit on large grids.
- **DFS with accumulator**: return area / perimeter / longest path from each flood fill.
- **All paths from source to target** (LC 797): DFS with `path.append` / `path.pop` (backtracking on a DAG).
- **Strongly connected components**: Tarjan or Kosaraju — both are DFS-based with timing info.
- **Bridges / articulation points**: DFS with low-link values (Tarjan).
- **DFS-based topological sort**: finish-time reverse order (alternative to Kahn's BFS variant).
- **Colouring for bipartite**: DFS alternative to BFS.
- **Edge cases**: disconnected graph, self-loops, duplicate edges, single-node components.

## 7. Related Patterns
- **Graph BFS** — reachability peer; BFS adds shortest-path guarantee on unit edges.
- **Recursion / Backtracking** — DFS mechanics; DFS without "undo" is still DFS.
- **Topological Sort** — DFS with finish times, or Kahn's BFS.
- **Union Find** — faster for dynamic connectivity; DFS is one-shot.
- **Tree DFS** — the special case without cycles; no `visited` set needed (just avoid the parent edge).

Distinguishing note: pick DFS when you care about **structural properties of the traversal** — components, cycles, topo order, back-edges. Pick BFS when you care about **distance**. Pick Union Find when the graph is **growing online** and you only need connectivity.
