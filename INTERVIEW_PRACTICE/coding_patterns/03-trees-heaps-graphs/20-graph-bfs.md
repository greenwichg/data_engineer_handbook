# 20 — Graph BFS

## 1. When to Use
- Graph is **unweighted** (or all edge weights equal) and you want the **shortest path** in edges.
- Keywords: *"minimum moves"*, *"shortest transformation"*, *"fewest steps"*, *"nearest"*, *"reachable in k steps"*, *"level by level"*, *"shortest path in a grid"*, *"multi-source distance"*, *"bipartite"*, *"word ladder"*, *"open the lock"*, *"jump game BFS"*.
- Grid problems where each cell connects to neighbours with **uniform cost** (4-directional or 8-directional moves).
- **Multi-source** problems: *"distance from each cell to the nearest X"* (rotting oranges, walls and gates, 01 matrix). BFS from all sources simultaneously is equivalent to a single BFS from a virtual super-source at distance 0.
- **Bipartite check** (2-colouring): BFS from each unvisited node assigning alternating colours.
- **Implicit graphs**: states like strings, board configurations, or tuples — neighbours generated on the fly (sliding puzzle, minimum knight moves).
- **0-1 BFS**: edge weights are only 0 or 1 — deque replaces the queue, `appendleft` for zero-weight edges.
- **Bidirectional BFS**: source and target known; expand both frontiers to halve the work.
- You need to **count** the number of shortest paths from src to dst (BFS + counting, each time we enter a node at distance `d`, accumulate path counts).

### Signals this is NOT a Graph BFS problem
- Edge weights vary arbitrarily → **Dijkstra** (heap), not BFS.
- You only need **reachability**, not distance → DFS or Union-Find is simpler.
- The graph is a DAG and you need ordering → **topological sort**.
- You need *all* shortest paths and the graph is huge → BFS + parent-map + backtrack, or `Bellman-Ford` if negative edges are possible.
- Edge weights can be negative → Bellman-Ford or SPFA.

## 2. Core Idea
BFS processes nodes in order of their **distance from the source**. Because every node at distance `d` enters the queue before any at distance `d+1`, the **first time a node is popped** is the shortest-edge-distance to it. Marking nodes as visited on **enqueue** (not dequeue) prevents duplicates from piling up in the queue — otherwise the queue can grow to `O(E)` and distance bookkeeping breaks.

The BFS skeleton is:
1. Seed the queue with the source(s), mark them visited.
2. Pop; for each unvisited neighbour, mark it visited and enqueue with distance+1.
3. Return on first pop of the target (shortest distance guaranteed), or emit all distances at the end.

### Why "mark on enqueue"
If you marked on dequeue, a node with in-degree 5 could be enqueued 5 times before being visited once. This balloons memory to `O(E)` and, worse, may pop the node multiple times — but only the first pop has the correct distance. Marking on enqueue gives each node exactly one enqueue and one pop, keeping the BFS `O(V + E)`.

### The multi-source trick
Seeding the queue with **all sources at distance 0** is equivalent to adding a virtual super-source `S` with weight-0 edges to every source. BFS from `S` gives the distance from each cell to its **nearest** source. This handles LC 994 (rotting oranges), LC 286 (walls and gates), LC 542 (01 matrix), and LC 1162 (as far from land as possible) with the same skeleton.

### State is the node
For implicit graphs, the "node" is whatever uniquely identifies a configuration:
- Word ladder: the current word string.
- Open the lock: the 4-digit combination.
- Sliding puzzle: a tuple of board positions.
- Minimum knight moves: `(x, y)` with symmetry reductions.
- Shortest path with K eliminations (LC 1293): `(r, c, k_remaining)`.

Expand state to include everything that affects future moves. The `seen` set keys on the full state.

## 3. Template

### Template A — shortest distance from src to dst
```python
from collections import deque                 # deque.popleft() is O(1); list.pop(0) is O(n)

def shortest_distance(src, dst, neighbours):
    if src == dst: return 0                   # early exit — distance 0 without entering BFS loop
    q = deque([(src, 0)])                     # deque([...]) takes an iterable; double brackets build a 1-tuple iterable
    seen = {src}                              # SET literal with one element — NOT an empty dict (that's {})
    while q:                                  # `while q` is truthy when non-empty; don't write `while len(q) > 0`
        node, d = q.popleft()                 # tuple unpacking; popleft returns the leftmost element atomically
        for nxt in neighbours(node):
            if nxt == dst:
                return d + 1                  # return on first discovery — guaranteed shortest in unweighted BFS
            if nxt not in seen:               # mark-on-ENQUEUE: prevents O(E) queue blow-up from re-adding
                seen.add(nxt)                 # set.add is O(1); .append on a list would use a different structure
                q.append((nxt, d + 1))
    return -1                                 # sentinel for unreachable — caller must check
```

### Template B — all distances from src (BFS tree)
```python
def bfs_distances(src, neighbours):
    dist = {src: 0}                           # dict doubles as `seen` AND distance map — no separate set needed
    q = deque([src])
    while q:
        u = q.popleft()
        for v in neighbours(u):
            if v not in dist:                 # `in` on dict checks KEYS in O(1) — same test as `not in seen`
                dist[v] = dist[u] + 1         # read dist[u] BEFORE assigning dist[v] — u already finalized
                q.append(v)
    return dist
```

### Template C — multi-source BFS on a grid
```python
DIRS = ((1, 0), (-1, 0), (0, 1), (0, -1))     # tuple-of-tuples — immutable module-level constant; safer than list

def multi_source_grid(grid, is_source, is_passable):
    m, n = len(grid), len(grid[0])            # assumes grid non-empty; grid[0] would IndexError on [] grid
    q = deque()                               # empty deque; seed with all sources below
    dist = [[-1] * n for _ in range(m)]       # LIST COMPREHENSION — do NOT write [[-1]*n]*m (shared row trap)
    for r in range(m):
        for c in range(n):
            if is_source(grid[r][c]):
                dist[r][c] = 0                # all sources seeded at distance 0 — equivalent to virtual super-source
                q.append((r, c))              # enqueue ALL sources before the BFS loop starts
    while q:
        r, c = q.popleft()
        for dr, dc in DIRS:
            nr, nc = r + dr, c + dc
            if (0 <= nr < m and 0 <= nc < n   # chained comparison — Python evaluates 0 <= nr AND nr < m
                and dist[nr][nc] == -1        # `-1` doubles as UNVISITED sentinel AND final "unreachable" marker
                and is_passable(grid[nr][nc])):  # `and` short-circuits — bounds check MUST come first
                dist[nr][nc] = dist[r][c] + 1
                q.append((nr, nc))
    return dist
```

### Template D — layered / level-by-level BFS
```python
def levels(src, neighbours):
    q = deque([src]); seen = {src}; layers = []   # semicolons allow one-line init — style only, no semantic effect
    while q:
        layer = []
        for _ in range(len(q)):                   # SNAPSHOT len(q) BEFORE the inner loop — range is evaluated once
            u = q.popleft(); layer.append(u)
            for v in neighbours(u):
                if v not in seen:
                    seen.add(v); q.append(v)      # appending to q during iteration is safe because range was fixed
        layers.append(layer)
    return layers
```

### Template E — bipartite check via 2-colouring
```python
def is_bipartite(graph):
    n = len(graph)
    color = [0] * n                          # [0]*n is safe for immutable int — NOT for [[0]]*n which shares inner list
    for start in range(n):                   # outer loop handles DISCONNECTED components — single BFS misses them
        if color[start] != 0: continue       # `continue` skips nodes already colored by a prior BFS tree
        color[start] = 1
        q = deque([start])
        while q:
            u = q.popleft()
            for v in graph[u]:
                if color[v] == 0:
                    color[v] = -color[u]     # negate parent's color; works because colors are ±1 not 0/1
                    q.append(v)
                elif color[v] == color[u]:   # same color on an edge → odd cycle → NOT bipartite
                    return False
    return True
```

### Template F — 0-1 BFS (deque, `appendleft` for weight-0 edges)
```python
def zero_one_bfs(src, dst, neighbours_with_weights):
    """Edges have weight 0 or 1 only."""
    dist = {src: 0}
    dq = deque([(0, src)])
    while dq:
        d, u = dq.popleft()                   # put distance FIRST in tuple so natural ordering would be by distance
        if u == dst: return d
        if d > dist[u]: continue              # stale entry — we found a shorter path after this was enqueued
        for v, w in neighbours_with_weights(u):
            nd = d + w
            if nd < dist.get(v, float('inf')):  # dict.get with default avoids KeyError on unseen v
                dist[v] = nd
                if w == 0:
                    dq.appendleft((nd, v))    # weight-0 edges go to FRONT — preserves distance ordering invariant
                else:
                    dq.append((nd, v))        # weight-1 edges go to BACK — processed after the current layer
    return -1
```

### Template G — bidirectional BFS (shortest path, known endpoints)
```python
def bi_bfs(src, dst, neighbours):
    if src == dst: return 0
    front, back = {src}, {dst}                # sets, not deques — we only care about membership, not order
    seen = {src, dst}                         # SET literal with two elements — safe because src != dst was checked
    steps = 0
    while front and back:                     # both must be non-empty; emptying either means no path exists
        steps += 1
        if len(front) > len(back):            # expand the smaller frontier — tuple-swap reassigns both names atomically
            front, back = back, front
        nxt_front = set()
        for u in front:
            for v in neighbours(u):
                if v in back:                 # frontiers have MET — `in` on a set is O(1)
                    return steps
                if v not in seen:
                    seen.add(v); nxt_front.add(v)
        front = nxt_front                     # replace old frontier — GC collects it if no other refs
    return -1
```

### Template H — state-augmented BFS (LC 1293 grid with k eliminations)
```python
def shortest_with_budget(grid, k):
    m, n = len(grid), len(grid[0])
    if m == n == 1: return 0                  # chained compare — equivalent to (m == n) AND (n == 1)
    # state: (r, c, remaining_eliminations)
    start = (0, 0, k)                         # tuple — HASHABLE (immutable); a list would fail as set/dict key
    q = deque([(start, 0)])
    seen = {start}
    while q:
        (r, c, rem), d = q.popleft()          # nested tuple unpacking — parens required around the inner triple
        for dr, dc in DIRS:
            nr, nc = r + dr, c + dc
            if not (0 <= nr < m and 0 <= nc < n): continue  # `not (a and b)` ≡ De Morgan's — bounds check first
            new_rem = rem - grid[nr][nc]      # obstacle cell has value 1; free cell has value 0
            if new_rem < 0: continue          # budget exhausted — skip this move
            if (nr, nc) == (m - 1, n - 1): return d + 1  # tuple equality is element-wise
            state = (nr, nc, new_rem)         # full state is the DEDUP key — NOT just (nr, nc)
            if state not in seen:
                seen.add(state); q.append((state, d + 1))
    return -1
```

Key mental tools:
- **Mark seen on enqueue**, not on dequeue — otherwise you enqueue the same node many times and the BFS grows to `O(E)`.
- Distances only work for **unit edge costs**. For non-unit weights, use Dijkstra (heap, not queue) or 0-1 BFS for binary weights.
- On grids, define `DIRS = ((1,0),(-1,0),(0,1),(0,-1))` once — saves code and bugs.
- Encode **full state** in the visited key. A cell might be worth revisiting if the other state dimension (remaining budget, last-move, keys collected) is better.
- For **multi-source**, seed all sources at distance 0 in one queue — don't loop "BFS per source".
- Return on **first dequeue of target** for shortest path; don't wait to finish the queue.
- For implicit graphs, memoise neighbour generation if it's expensive (e.g. word ladder's letter-swap loop).
- **Layered BFS** `len(q)` snapshot is identical to tree BFS; useful when you want to emit or count per-distance groups.

## 4. Classic Problems
- **LC 127 — Word Ladder** (Hard): BFS over word graph; neighbours are words differing by one letter. Bidirectional BFS is a strong optimisation.
- **LC 994 — Rotting Oranges** (Medium): multi-source BFS (Template C).
- **LC 286 — Walls and Gates** (Medium): multi-source BFS from gates.
- **LC 542 — 01 Matrix** (Medium): multi-source BFS from 0-cells.
- **LC 785 — Is Graph Bipartite?** (Medium): BFS 2-colouring (Template E).
- **LC 1091 — Shortest Path in Binary Matrix** (Medium): BFS with 8-directional moves.
- **LC 752 — Open the Lock** (Medium): BFS on 4-digit string states.
- **LC 1293 — Shortest Path with Obstacle Elimination** (Hard): state-augmented BFS (Template H).
- **LC 773 — Sliding Puzzle** (Hard): BFS on board tuples.
- **LC 433 — Minimum Genetic Mutation** (Medium): BFS on 8-character strings.
- **LC 934 — Shortest Bridge** (Medium): flood-fill one island, BFS outward.
- **LC 1162 — As Far from Land as Possible** (Medium): multi-source BFS from all land cells.

## 5. Worked Example — Word Ladder (LC 127)
Problem: given `beginWord = "hit"`, `endWord = "cog"`, and `wordList = ["hot","dot","dog","lot","log","cog"]`, return the number of words in the shortest transformation sequence. Each step changes exactly one letter and the intermediate word must be in `wordList`. Return `0` if no transformation exists.

Expected: `5`. One valid chain: `hit → hot → dot → dog → cog`.

### Step 1. Model as a graph
- **Nodes**: every word.
- **Edges**: two words are connected iff they differ by exactly one letter.
- We want the **shortest path** from `beginWord` to `endWord` in edges, then add 1 for the number of words.

### Step 2. Generate neighbours efficiently
Naive: for each word, compare against every other word — `O(N^2 * L)` where `N = |wordList|` and `L = word length`.

Better: for each word, generate all possible "pattern" keys by replacing each letter with `*`. `"hot"` maps to `{"*ot", "h*t", "ho*"}`. Two words are neighbours iff they share a pattern key. Preprocess once in `O(N * L)`; then BFS looks up neighbours in `O(L * 26)` or `O(L * N_in_bucket)`.

For this trace we'll use the "try all letter swaps" variant — simpler to explain.

```python
from collections import deque

def ladderLength(beginWord, endWord, wordList):
    word_set = set(wordList)                  # convert list → set ONCE; `in` becomes O(1) instead of O(N) per check
    if endWord not in word_set: return 0      # early exit — target unreachable by construction
    q = deque([(beginWord, 1)])               # count WORDS (nodes) not edges — hence starting at 1, not 0
    seen = {beginWord}                        # beginWord may NOT be in wordList — still a valid start
    while q:
        word, steps = q.popleft()
        if word == endWord:
            return steps
        for i in range(len(word)):            # len(str) is O(1) in CPython — cached on the string object
            for c in "abcdefghijklmnopqrstuvwxyz":  # iterating a string yields single-char strings
                if c == word[i]: continue      # skip the identity swap — no self-edge
                nxt = word[:i] + c + word[i+1:]  # slicing creates NEW strings; end index EXCLUSIVE; `word[i+1:]` is safe past end
                if nxt in word_set and nxt not in seen:  # `and` short-circuits — cheapest check first
                    seen.add(nxt)
                    q.append((nxt, steps + 1))
    return 0                                   # unreachable — problem spec says 0, not -1
```

### Step 3. BFS trace
Start: queue = `[("hit", 1)]`, `seen = {"hit"}`.

**Pop `("hit", 1)`.**
Generate neighbours by trying each letter swap:
- `*it`: `ait`, `bit`, ..., `zit` — none in `word_set`.
- `h*t`: `hat`, `hbt`, ..., `hot` — `hot ∈ word_set` ✓. Enqueue `("hot", 2)`, mark.
- `hi*`: `hia`, ..., `hiz` — none in `word_set`.

Queue = `[("hot", 2)]`, `seen = {"hit", "hot"}`.

**Pop `("hot", 2)`.**
- `*ot`: `dot` ✓ (enqueue `("dot", 3)`), `lot` ✓ (enqueue `("lot", 3)`). Others not in set.
- `h*t`: `hit` (seen), nothing new.
- `ho*`: nothing new.

Queue = `[("dot", 3), ("lot", 3)]`, `seen = {"hit", "hot", "dot", "lot"}`.

**Pop `("dot", 3)`.**
- `*ot`: `hot` (seen), `lot` (seen).
- `d*t`: nothing.
- `do*`: `dog` ✓ (enqueue `("dog", 4)`).

Queue = `[("lot", 3), ("dog", 4)]`, `seen` adds `dog`.

**Pop `("lot", 3)`.**
- `*ot`: nothing new.
- `l*t`: nothing.
- `lo*`: `log` ✓ (enqueue `("log", 4)`).

Queue = `[("dog", 4), ("log", 4)]`, `seen` adds `log`.

**Pop `("dog", 4)`.**
- `*og`: `log` (seen), `cog` ✓ (enqueue `("cog", 5)`).
- `d*g`: nothing.
- `do*`: `dot` (seen).

Queue = `[("log", 4), ("cog", 5)]`, `seen` adds `cog`.

**Pop `("log", 4)`.**
- `*og`: `cog` (seen), `dog` (seen).
- Nothing new.

Queue = `[("cog", 5)]`.

**Pop `("cog", 5)`.**
`word == endWord` → return `5`. ✓

### Step 4. Summary table of the BFS frontier
| layer | words at this layer | distance (# words) |
|---|---|---|
| 0 | `hit` | 1 |
| 1 | `hot` | 2 |
| 2 | `dot, lot` | 3 |
| 3 | `dog, log` | 4 |
| 4 | `cog` | 5 |

The BFS found the shortest transformation: 5 words, 4 transformations.

### Step 5. Complexity and pattern-key optimisation
Without preprocessing: each pop tries `L * 25` letter swaps — `O(N * L * 25)` work with `O(N)` nodes visited.

With pattern-key preprocessing:
```python
from collections import defaultdict
patterns = defaultdict(list)                  # missing key auto-creates an empty list — no KeyError on .append
for w in word_set | {beginWord}:              # `|` on sets = UNION — {beginWord} is a 1-element set literal
    for i in range(len(w)):
        patterns[w[:i] + "*" + w[i+1:]].append(w)  # string concat builds new str each time — OK here since L is tiny
```
Neighbours of `w` are `∪ patterns[w[:i] + "*" + w[i+1:]]` — precomputed. Shared-pattern lookup is constant.

### Step 6. Bidirectional BFS for large inputs
On word lists of 10k+ words, bidirectional BFS (Template G) halves the effective radius: two frontiers of size `b^(d/2)` meet in the middle instead of one frontier of size `b^d`. On LC 127 this often beats naive BFS by 10×.

### Step 7. Takeaway
Three BFS superpowers show up here:
1. **Graph modelling**: translate a transformation problem to nodes + edges.
2. **Neighbour generation**: pattern-key preprocessing to avoid `N^2` comparisons.
3. **Bidirectional optimisation**: when both endpoints are known, halve the work.

## 6. Common Variations

### Shortest path on grids
- **Shortest path in binary matrix** (LC 1091): 8-directional BFS.
- **Shortest bridge** (LC 934): DFS to colour one island, BFS outward to the other.
- **Walls and gates / 01 matrix / rotting oranges**: multi-source BFS.
- **As far from land as possible** (LC 1162): multi-source BFS from all land; answer = maximum distance.
- **Shortest path visiting all nodes** (LC 847): BFS on `(node, mask)` states.

### Implicit graph BFS
- **Word ladder** (LC 127): Template A + pattern keys.
- **Minimum genetic mutation** (LC 433): 4-letter strings.
- **Open the lock** (LC 752): 4-digit combinations with dead-end states.
- **Sliding puzzle** (LC 773): BFS on 2×3 board tuples.
- **Jump game III / IV** (LC 1306, 1345): BFS on index states.
- **Minimum knight moves** (LC 1197): BFS with symmetry reduction.

### State-augmented BFS
- **Shortest path with obstacle elimination** (LC 1293): `(r, c, k_remaining)`.
- **Shortest path visiting all keys** (LC 864): `(r, c, keys_mask)`.
- **Bus routes** (LC 815): two-level BFS (stops ↔ buses).
- **Water and jug problem** (LC 365): BFS on `(a_amount, b_amount)`.

### Multi-source BFS
- **Rotting oranges** (LC 994).
- **Walls and gates** (LC 286).
- **01 matrix** (LC 542).
- **Shortest path from all gates / exits**.
- **As far from land as possible** (LC 1162).

### 0-1 BFS
- **Minimum cost to make at least one valid path** (LC 1368): zero-cost for following arrows, one-cost for reversing.
- **Shortest path with alternating colours** (LC 1129): two layers (by colour), BFS with transition rules.

### Bidirectional BFS
- **Word ladder** (LC 127): classic use case on large word lists.
- **Minimum knight moves** (LC 1197): infinite board, bidirectional avoids exploring far from target.
- **Opening the lock** (LC 752): bidirectional helps when dead-ends limit target-reachability.

### Bipartite / colouring
- **Is graph bipartite?** (LC 785): Template E.
- **Possible bipartition** (LC 886): BFS colouring with "dislikes" as edges.

### Counting and tie-breaking paths
- **Number of ways to arrive at destination** (LC 1976): Dijkstra + path count; BFS version works if unweighted.
- **All shortest transformation sequences** (LC 126): BFS to build a parent-DAG, then DFS to emit all paths.

### Edge cases & pitfalls
- **Marking seen on dequeue** — allows the same node to be enqueued many times; distance bookkeeping breaks on high-fan-in graphs. Always mark on enqueue.
- **`src == dst`** — return 0 up front; don't process as a normal BFS step.
- **Unreachable target** — return `-1` or sentinel when the queue empties without finding the target.
- **Weighted edges snuck in** — vanilla BFS is wrong; look for cues like "cost", "distance", "weight".
- **Forgetting to include `beginWord`** in the reachable set (LC 127): often `beginWord` is not in `wordList`, but it's still a valid start.
- **State key mismatch** — if you add `(r, c, extra)` to `seen` but enqueue `(r, c)` without `extra`, revisits break.
- **Grid boundaries** — always bounds-check before indexing.
- **Infinite graphs** — need a visit budget or a distance bound.
- **`list.pop(0)`** — `O(n)` per pop; always `collections.deque`.
- **Revisiting with a better augmented state** — vanilla BFS assumes first-visit = best; if state has a quality dimension (remaining budget), first-visit may be worse. Use Dijkstra or state-augmented BFS.

## 7. Related Patterns
- **Graph DFS** — same reachability, different order; DFS does not give shortest paths.
- **Queue / Deque** — the substrate; 0-1 BFS needs the deque.
- **Dijkstra (Heap)** — weighted-edge generalisation.
- **A\* search** — Dijkstra + heuristic; useful for very large state spaces (sliding puzzle with millions of states).
- **Topological Sort (Kahn's)** — BFS-flavoured variant using in-degree queue; works only on DAGs.
- **Union Find** — answers connectivity but not distance; faster for pure connectivity.
- **Tree BFS / Level Order** — the tree special case.
- **Bidirectional BFS** — when both endpoints known; halves the effective radius.
- **Bellman-Ford / SPFA** — when edge weights can be negative.

**Distinguishing note**: any problem saying *"minimum number of steps"* on an unweighted graph is BFS. If weights vary but are non-negative, it is **Dijkstra**. If weights are 0 or 1 only, **0-1 BFS** with a deque. If weights can be negative, **Bellman-Ford**. If the graph is a DAG and you need an ordering, **topological sort**. If you do not care about distance (just connectivity), **DFS** or **Union Find** is fine. The state — node alone vs node + augmented info — is the single biggest design decision; getting it wrong silently returns wrong answers.
