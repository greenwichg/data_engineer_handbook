# 20 — Graph BFS

## 1. When to Use
- Graph is **unweighted** (or all edge weights equal) and you want the **shortest path** in edges.
- Keywords: *"minimum moves"*, *"shortest transformation"*, *"fewest steps"*, *"nearest"*, *"reachable in k steps"*, *"level by level"*.
- Grid problems where each cell connects to neighbours with uniform cost (4-directional or 8-directional moves).
- Multi-source problems: *"distance from each cell to nearest X"* (rotting oranges, walls and gates).
- Bipartite check (2-colouring).

## 2. Core Idea
BFS processes nodes in order of their distance from the source. Because every node at distance `d` enters the queue before any at distance `d+1`, the first time a node is popped is the shortest-edge-distance to it. Marking nodes as visited on **enqueue** (not dequeue) prevents duplicates from piling up in the queue.

## 3. Template
```python
from collections import deque

# 1) Shortest path from src to dst
def shortest(src, dst, neighbours):
    if src == dst: return 0
    q = deque([(src, 0)])
    seen = {src}
    while q:
        node, d = q.popleft()
        for nxt in neighbours(node):
            if nxt == dst: return d + 1
            if nxt not in seen:
                seen.add(nxt); q.append((nxt, d + 1))
    return -1

# 2) Multi-source BFS on a grid (e.g. rotting oranges)
def multi_source_grid(grid, sources):
    m, n = len(grid), len(grid[0])
    q = deque((r, c, 0) for r, c in sources)
    seen = {(r, c) for r, c in sources}
    last_time = 0
    while q:
        r, c, t = q.popleft()
        last_time = t
        for dr, dc in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            nr, nc = r + dr, c + dc
            if 0 <= nr < m and 0 <= nc < n and (nr, nc) not in seen and grid[nr][nc] != WALL:
                seen.add((nr, nc)); q.append((nr, nc, t + 1))
    return last_time

# 3) Level-by-level BFS (same shape as tree BFS)
def levels(src, neighbours):
    q = deque([src]); seen = {src}; out = []
    while q:
        layer = []
        for _ in range(len(q)):
            u = q.popleft(); layer.append(u)
            for v in neighbours(u):
                if v not in seen:
                    seen.add(v); q.append(v)
        out.append(layer)
    return out
```
Key mental tools:
- **Mark seen on enqueue**, not on dequeue — otherwise you enqueue the same node many times.
- Distances only work for **unit edge costs**. For weighted graphs, use Dijkstra (heap, not queue).
- On grids, define `DIRS = [(1,0),(-1,0),(0,1),(0,-1)]` once and iterate — saves code and bugs.

## 4. Classic Problems
- **LC 127 — Word Ladder** (Hard): BFS over word graph; neighbours are words differing by one letter.
- **LC 994 — Rotting Oranges** (Medium): multi-source BFS.
- **LC 286 — Walls and Gates** (Medium): multi-source BFS from gates.
- **LC 542 — 01 Matrix** (Medium): multi-source BFS from 0-cells.
- **LC 785 — Is Graph Bipartite?** (Medium): BFS 2-colouring.

## 5. Worked Example — Rotting Oranges (LC 994)
Problem: in a grid, `2 = rotten`, `1 = fresh`, `0 = empty`. Each minute, every fresh orange adjacent to a rotten one becomes rotten. Return the minimum minutes until none are fresh, or `-1` if impossible.

Input:
```
grid = [
  [2, 1, 1],
  [1, 1, 0],
  [0, 1, 1],
]
```
Approach: seed the queue with every rotten cell, BFS outward, count layers until no fresh remain.

```python
from collections import deque

def orangesRotting(grid):
    m, n = len(grid), len(grid[0])
    q = deque()
    fresh = 0
    for r in range(m):
        for c in range(n):
            if grid[r][c] == 2: q.append((r, c, 0))
            elif grid[r][c] == 1: fresh += 1

    minutes = 0
    while q:
        r, c, t = q.popleft()
        minutes = t
        for dr, dc in ((1,0),(-1,0),(0,1),(0,-1)):
            nr, nc = r + dr, c + dc
            if 0 <= nr < m and 0 <= nc < n and grid[nr][nc] == 1:
                grid[nr][nc] = 2          # rot in place = mark seen
                fresh -= 1
                q.append((nr, nc, t + 1))
    return minutes if fresh == 0 else -1
```

Trace. Initial queue: `[(0,0,0)]`, `fresh = 6`. Show `(row, col, time)`:

| pop | `fresh` after | new rots added | queue after | `minutes` |
|---|---|---|---|---|
| (0,0,0) | 5 → 4 | (0,1,1), (1,0,1) | `[(0,1,1), (1,0,1)]` | 0 |
| (0,1,1) | 3 | (0,2,2), (1,1,2) | `[(1,0,1), (0,2,2), (1,1,2)]` | 1 |
| (1,0,1) | 3 | — (neighbours already 2 or empty) | `[(0,2,2), (1,1,2)]` | 1 |
| (0,2,2) | 3 | — (right is out of bounds, down is 0) | `[(1,1,2)]` | 2 |
| (1,1,2) | 2 → 1 | (2,1,3); right is 0 | `[(2,1,3)]` | 2 |
| (2,1,3) | 0 | (2,2,4) | `[(2,2,4)]` | 3 |
| (2,2,4) | 0 | — (out of bounds / no fresh) | `[]` | 4 |

Queue empty, `fresh = 0`, return `4`. Time `O(m*n)`, space `O(m*n)`. The same skeleton — seed all sources, BFS out, count layers — solves LC 542 and LC 286.

## 6. Common Variations
- **0-1 BFS**: deque with `appendleft` for zero-weight edges, `append` for weight-1 edges — Dijkstra in `O(V+E)` for 0/1 edges (LC 1368 min path cost grid).
- **Bidirectional BFS**: expand both ends; faster on huge graphs (LC 127 word ladder).
- **BFS for bipartite** (LC 785): assign alternating colours; conflict → not bipartite.
- **Implicit graphs**: states are strings / board configurations; neighbours generated on the fly (sliding puzzle, word ladder).
- **Grid with portals / teleports**: extra edges; still BFS.
- **Shortest path with constraints** (e.g. limited turns): encode the constraint in the state tuple.
- **Edge cases**: source == target (distance 0), disconnected components, infinite graphs (need a visit budget).

## 7. Related Patterns
- **Graph DFS** — same reachability, different order; DFS does not give shortest paths.
- **Queue / Deque** — the substrate; 0-1 BFS needs the deque.
- **Dijkstra (Heap)** — weighted-edge generalisation.
- **Topological Sort** — BFS-flavoured variant (Kahn's algorithm) using in-degree queue.
- **Union Find** — answers connectivity but not distance.

Distinguishing note: any problem saying *"minimum number of steps"* on an unweighted graph is BFS. If weights vary, it is Dijkstra. If you do not care about distance (just connectivity), DFS or Union Find is fine.
