# 22 — Union Find (Disjoint Set Union)

## 1. When to Use
- You need to track which elements are **in the same group** as edges / merges arrive online.
- Keywords: *"connected components"*, *"redundant edge"*, *"accounts merge"*, *"number of islands II"*, *"dynamic connectivity"*, *"Kruskal's MST"*, *"equations like a/b = k"*, *"smallest string with swaps"*, *"satisfiability of equality equations"*, *"remove max stones"*, *"earliest moment when everyone becomes friends"*.
- The graph **grows** by adding edges (or equivalences) over time — DFS/BFS would re-run on each query.
- You need only the **group identity** of elements, not distances or paths.
- **Cycle detection in an undirected graph**: an edge closes a cycle iff both endpoints already share a root.
- You're processing events **offline**, sorted by some key (time, weight, value), and answering group queries as you go.
- You need **Kruskal's algorithm** for MST — DSU is the natural cycle oracle.
- You need to join components based on an equivalence relation: same email, same prefix, same group id.
- You want to answer "same component?" in effectively `O(1)` per query after preprocessing.

### Signals this is NOT a Union-Find problem
- You need **shortest distance** between two nodes → BFS / Dijkstra. DSU has no notion of distance.
- The graph has **edge deletions** — classical DSU does not support deletion. Use Link-Cut Trees, Euler Tour Trees, or offline processing with rollback.
- The graph is **directed** and you care about reachability one-way → DFS / BFS / SCC, not DSU (DSU treats all edges as undirected).
- You need to enumerate nodes within a component in some order → DSU only gives the root; walk the graph or maintain a list per root.

## 2. Core Idea
Maintain a **forest** where each tree represents one group; each node points to a parent, and the root represents the set. Two operations:
- `find(x)`: walks to the root of `x`'s tree — this identifies `x`'s group.
- `union(x, y)`: finds the roots of `x` and `y`; if different, links one root under the other.

Two optimisations make this near-linear:
- **Path compression** during `find`: on the way up, point every node directly to the root (or, in the iterative two-step variant, to its grandparent). Future `find`s on this branch are `O(1)`.
- **Union by rank / size**: when linking two roots, attach the **shallower** tree under the **deeper** one (rank), or the **smaller** under the **larger** (size). This keeps tree depth `O(log n)` before compression, and `O(α(n))` after.

With both, `m` operations on `n` elements cost `O(m * α(n))` where `α` is the inverse Ackermann function — effectively `O(1)` for all practical `n` (`α(n) ≤ 4` for `n ≤ 2^65536`).

### Key invariants
- Each element has exactly one parent; the root points to itself.
- Two elements are in the same group iff `find(x) == find(y)`.
- The forest structure is **not** the original graph; it is a bookkeeping structure whose only purpose is answering "same group?".
- `union` returning `False` is a first-class signal: **the edge would create a cycle** (both endpoints already connected).

### DSU vs graph traversal
- DFS/BFS: one-shot, `O(V + E)` per query. Great when the graph is static and you need path or distance info.
- DSU: amortised `O(α(n))` per operation. Great when edges arrive online and you only need group identity.

### Weighted (relational) DSU
When the equivalence carries a **value** (ratio, offset, parity), augment each node with `weight[x] = value(x relative to parent[x])`. `find` multiplies/adds weights along the path; `union` sets the new root's weight so the known relation holds.

Examples:
- **LC 399 evaluate division**: weight = ratio `x / parent[x]`; compression multiplies weights.
- **LC 990 satisfiability of equality equations**: no weight; just equivalence.
- **LC 1202 smallest string with swaps**: components, then sort characters within each component.

## 3. Template

### Template A — canonical DSU with path compression and union-by-rank
```python
class DSU:
    def __init__(self, n):
        self.parent = list(range(n))          # list(range(n)) materializes; range(n) alone would be lazy & non-indexable into list
        self.rank = [0] * n                   # [0]*n is SAFE: int is immutable — no shared-element trap
        self.size = [1] * n
        self.components = n

    def find(self, x):
        # Iterative path compression (halving): each node points to its grandparent.
        while self.parent[x] != x:            # root's parent == itself — loop invariant
            self.parent[x] = self.parent[self.parent[x]]  # RHS fully evaluated before assignment — safe double lookup
            x = self.parent[x]
        return x

    def union(self, x, y):
        rx, ry = self.find(x), self.find(y)   # RHS tuple built first, THEN unpacked — order-independent
        if rx == ry:
            return False                      # already connected — signal that edge closes a cycle
        # Union by rank: attach shallower tree under deeper one
        if self.rank[rx] < self.rank[ry]:
            rx, ry = ry, rx                   # swap by tuple assignment — no temp variable needed
        self.parent[ry] = rx
        self.size[rx] += self.size[ry]
        if self.rank[rx] == self.rank[ry]:    # ranks equal BEFORE swap-or-rx-tall means new tree is taller by 1
            self.rank[rx] += 1
        self.components -= 1
        return True

    def connected(self, x, y):
        return self.find(x) == self.find(y)   # roots equal ↔ same component
```

### Template B — recursive find with full path compression
```python
def find(self, x):
    if self.parent[x] != x:
        self.parent[x] = self.find(self.parent[x])   # recursive compress — rewrites parent to root on return
    return self.parent[x]                             # watch recursion depth — chain length can exceed 1000
```

Full compression flattens the entire path to the root in one call. Iterative halving (Template A) is cheaper in practice and avoids recursion-depth concerns; both achieve the same `α(n)` amortised bound.

### Template C — DSU with a dict (non-integer keys)
```python
class DSUDict:
    def __init__(self):
        self.parent = {}                      # dict literal — arbitrary hashable keys (str, tuple, int, ...)
        self.size = {}

    def add(self, x):
        if x not in self.parent:              # idempotent — safe to call on already-known keys
            self.parent[x] = x
            self.size[x] = 1

    def find(self, x):
        self.add(x)                           # auto-seed unknown elements — convenient for streaming inputs
        while self.parent[x] != x:
            self.parent[x] = self.parent[self.parent[x]]
            x = self.parent[x]
        return x

    def union(self, x, y):
        rx, ry = self.find(x), self.find(y)
        if rx == ry: return False
        if self.size[rx] < self.size[ry]: rx, ry = ry, rx  # always attach smaller under larger — keeps tree shallow
        self.parent[ry] = rx
        self.size[rx] += self.size[ry]
        return True
```

Useful when the universe is string emails, arbitrary object IDs, or sparse integer ranges.

### Template D — weighted DSU (ratios / offsets)
```python
class WeightedDSU:
    def __init__(self):
        self.parent = {}
        self.weight = {}                           # weight[x] = x / parent[x] — relational edge label

    def find(self, x):
        if x not in self.parent:
            self.parent[x] = x; self.weight[x] = 1.0  # 1.0 not 1 — force float arithmetic from the start
        if self.parent[x] != x:
            root = self.find(self.parent[x])       # recurse BEFORE reading weight[parent[x]] — parent now points to root
            self.weight[x] *= self.weight[self.parent[x]]  # accumulate ratio along compressed path
            self.parent[x] = root
        return self.parent[x]

    def union(self, x, y, ratio):                  # ratio = x / y
        rx, ry = self.find(x), self.find(y)
        if rx == ry: return                        # already related — could verify consistency if trust-but-verify
        self.parent[rx] = ry
        self.weight[rx] = ratio * self.weight[y] / self.weight[x]  # float divide — precision drifts over many unions

    def query(self, x, y):
        if x not in self.parent or y not in self.parent: return -1.0
        if self.find(x) != self.find(y): return -1.0  # different components → undefined ratio
        return self.weight[x] / self.weight[y]
```

### Template E — grid cell flattening `(r, c) -> r * n + c`
```python
def grid_dsu_index(r, c, cols):
    return r * cols + c                       # flatten 2D to 1D — use `cols` NOT `rows`; confuse them and indices collide

def unite_cells(dsu, r1, c1, r2, c2, cols):
    dsu.union(grid_dsu_index(r1, c1, cols), grid_dsu_index(r2, c2, cols))
```

Used for grid connectivity problems like LC 305 (Number of Islands II) or LC 827 (Making a Large Island).

### Template F — Kruskal's MST
```python
def kruskal(n, edges):
    """edges = [(weight, u, v), ...]"""
    dsu = DSU(n)
    mst_weight = 0; picked = []
    for w, u, v in sorted(edges):             # tuple sort is LEXICOGRAPHIC — weight first gives weight-ascending order
        if dsu.union(u, v):                   # union returns True only if NEW connection — rejects cycle-closing edges
            mst_weight += w
            picked.append((u, v, w))
            if dsu.components == 1: break     # early exit — MST has exactly n-1 edges
    return mst_weight, picked
```

Key mental tools:
- **Path compression alone** is usually enough for competitive inputs; union-by-rank/size seals the worst case.
- `union(x, y) → False` is a first-class signal for **"this edge would create a cycle"** — very useful.
- Track `components` inline to answer "how many groups?" in `O(1)`.
- For **weighted DSU**, store `weight[x] = relation to parent[x]` and multiply/add during `find` with compression.
- For **non-integer keys**, use a `dict`-backed DSU (Template C).
- For grids, flatten `(r, c) → r * cols + c`.
- DSU does not support **deletion**; if you need it, use offline processing (process events in reverse) or more advanced structures.
- The two failure modes if you skip both optimisations: worst-case `O(n)` per `find` (Ω(n²) total); not wrong, just slow. Always include at least path compression.

## 4. Classic Problems
- **LC 547 — Number of Provinces** (Medium): union over adjacency matrix; answer = `dsu.components` at the end.
- **LC 684 — Redundant Connection** (Medium): first edge whose `union` returns `False`.
- **LC 685 — Redundant Connection II** (Hard): directed variant; two cases to handle.
- **LC 721 — Accounts Merge** (Medium): union accounts sharing any email — canonical dict-DSU.
- **LC 1319 — Number of Operations to Make Network Connected** (Medium): extra edges ≥ `components - 1`.
- **LC 399 — Evaluate Division** (Medium): weighted DSU (Template D).
- **LC 990 — Satisfiability of Equality Equations** (Medium): DSU; first pass `==` edges, second pass check `!=`.
- **LC 305 — Number of Islands II** (Hard): online grid DSU; add land cells one at a time.
- **LC 952 — Largest Component Size by Common Factor** (Hard): DSU over indices sharing any prime factor.
- **LC 1202 — Smallest String with Swaps** (Medium): union indices that can swap; sort chars within each component.
- **LC 1584 — Min Cost to Connect All Points** (Medium): Kruskal's MST (Template F).
- **LC 1579 — Remove Max Number of Edges** (Hard): two DSUs (Alice, Bob) processed with edge-type priority.
- **LC 1319 — Number of Operations** (Medium): components - 1 extra edges required.

## 5. Worked Example — Accounts Merge (LC 721)
Problem: given a list of accounts, each with a name and a set of emails, merge accounts that share any email. Return merged accounts sorted emails-per-account.

Input:
```python
accounts = [
    ["John", "johnsmith@mail.com", "john00@mail.com"],
    ["John", "johnnybravo@mail.com"],
    ["John", "johnsmith@mail.com", "john_newyork@mail.com"],
    ["Mary", "mary@mail.com"],
]
```
Expected: three merged accounts. Account 0 and account 2 share `johnsmith@mail.com`, so they merge. Account 1 (Johnny Bravo) is separate despite same name. Mary is separate.

### Step 1. Why DSU fits
Two emails belong to the same person iff they appear in the same account **or** they are transitively linked via shared emails across accounts. This is exactly an **equivalence relation** built from pairwise equivalences — the textbook setup for DSU.

Naive approach (DFS on an email graph): build `email → set of connected emails`, then DFS. Works but requires an explicit adjacency structure.

DSU approach: for each account, pick the first email as an anchor and union every other email in the account with the anchor. After processing all accounts, emails in the same DSU component belong to the same merged person.

### Step 2. Map emails to indices (or use dict-DSU)
Since emails are strings, we either:
1. Map each email to an integer index and use integer DSU, or
2. Use a dict-based DSU (Template C).

We'll use Template C for clarity.

### Step 3. Implement
```python
class DSU:
    def __init__(self):
        self.parent = {}
    def find(self, x):
        if x not in self.parent:
            self.parent[x] = x                # auto-seed — makes it safe to find() a never-before-seen key
        while self.parent[x] != x:
            self.parent[x] = self.parent[self.parent[x]]
            x = self.parent[x]
        return x
    def union(self, x, y):
        rx, ry = self.find(x), self.find(y)
        if rx != ry: self.parent[rx] = ry     # arbitrary direction here — no rank balancing for simplicity

def accountsMerge(accounts):
    dsu = DSU()
    email_to_name = {}

    # Phase 1: union all emails within each account; record name per email
    for acc in accounts:
        name = acc[0]                         # name at index 0
        first = acc[1]                        # anchor email — assumes at least one email (no guard)
        for email in acc[1:]:                 # slice acc[1:] skips the name; end index omitted = to end
            email_to_name[email] = name       # safe to overwrite — same email must map to same name anyway
            dsu.union(first, email)

    # Phase 2: bucket emails by their DSU root
    from collections import defaultdict       # local import is legal Python; saves module-level clutter
    groups = defaultdict(list)                # defaultdict(list) — missing key auto-creates []; no KeyError
    for email in email_to_name:               # iterating a dict yields KEYS; equivalent to .keys()
        groups[dsu.find(email)].append(email)

    # Phase 3: emit [name, sorted_emails...]
    return [[email_to_name[root]] + sorted(emails)   # list + list CONCAT produces new list; don't use += on immutable
            for root, emails in groups.items()]      # .items() yields (key, value) tuples
```

### Step 4. Trace

**Phase 1 — union within accounts.**

Account 0: `["John", "johnsmith@mail.com", "john00@mail.com"]`. Anchor: `johnsmith`.
- `union(johnsmith, johnsmith)` → no-op.
- `union(johnsmith, john00)` → parent `{johnsmith: johnsmith, john00: johnsmith}`.

Account 1: `["John", "johnnybravo@mail.com"]`. Anchor: `johnnybravo`.
- `union(johnnybravo, johnnybravo)` → no-op.
- No other emails.

Account 2: `["John", "johnsmith@mail.com", "john_newyork@mail.com"]`. Anchor: `johnsmith`.
- `union(johnsmith, johnsmith)` → no-op.
- `union(johnsmith, john_newyork)` → parent `{..., john_newyork: johnsmith}`.

Account 3: `["Mary", "mary@mail.com"]`. Anchor: `mary`.
- `union(mary, mary)` → no-op.

**State after Phase 1**:
```
parent = {
    johnsmith: johnsmith,
    john00: johnsmith,
    johnnybravo: johnnybravo,
    john_newyork: johnsmith,
    mary: mary,
}
email_to_name = {
    johnsmith: John,
    john00: John,
    johnnybravo: John,
    john_newyork: John,
    mary: Mary,
}
```

**Phase 2 — bucket by root.**

| email | `find(email)` | group |
|---|---|---|
| johnsmith | johnsmith | group[johnsmith] += [johnsmith] |
| john00 | johnsmith | group[johnsmith] += [john00] |
| johnnybravo | johnnybravo | group[johnnybravo] += [johnnybravo] |
| john_newyork | johnsmith | group[johnsmith] += [john_newyork] |
| mary | mary | group[mary] += [mary] |

Groups:
- `johnsmith`: `[johnsmith, john00, john_newyork]`
- `johnnybravo`: `[johnnybravo]`
- `mary`: `[mary]`

**Phase 3 — emit.**
For each group, sort emails, prepend name:
- `["John", "john00@mail.com", "john_newyork@mail.com", "johnsmith@mail.com"]`
- `["John", "johnnybravo@mail.com"]`
- `["Mary", "mary@mail.com"]`

### Step 5. Why Account 1 (`johnnybravo`) doesn't merge
It shares no email with any other account. In Phase 1, only `johnnybravo` itself is touched. In Phase 2, its root is itself. It stays in its own group. DSU correctly identifies that shared **emails** (not names) drive the merge.

### Step 6. Complexity
Let `N` = total number of emails across all accounts.
- Phase 1: for each account with `k` emails, `k - 1` unions. Total `O(N · α(N))`.
- Phase 2: one `find` per email. `O(N · α(N))`.
- Phase 3: sorting each group. Total sort work `O(N log N)`.

Overall `O(N log N)` dominated by sorting.

### Step 7. Contrast with DFS
A DFS approach builds an adjacency list `email → set[email]` by linking every pair of emails in each account. Then DFS from each unvisited email to collect its component. Correctness is identical; the code is slightly more verbose and you lose the "is this edge redundant?" oracle. DSU is the textbook choice.

## 6. Common Variations

### Counting components / cycle detection
- **Number of provinces** (LC 547): union row-column pairs where `M[i][j] == 1`; count = `dsu.components`.
- **Number of connected components** (LC 323): same shape.
- **Redundant connection** (LC 684): first edge with failing union.
- **Graph valid tree** (LC 261): union all edges; valid iff all `V - 1` unions succeed and one component remains.
- **Earliest moment when everyone becomes friends** (LC 1101): sort by time, union, return time when components = 1.

### Online grid / island problems
- **Number of islands II** (LC 305): land cells arrive online; unite with neighbouring land cells.
- **Surrounded regions** (LC 130): unite all "O"s touching the boundary to a dummy root; remaining "O"s get captured.
- **Making a large island** (LC 827): label islands via DSU, then for each water cell compute the max merged size from its 4 neighbours.
- **Bricks falling** (LC 803): process in reverse time; union bricks to a virtual ceiling node.

### Weighted / relational DSU
- **Evaluate division** (LC 399): Template D.
- **Satisfiability of equality equations** (LC 990): equalities first, then inequalities.
- **Regions cut by slashes** (LC 959): subdivide each cell into 4 triangles; union by geometry.
- **Similar string groups** (LC 839): union strings within Hamming distance 2.

### Kruskal's MST and variants
- **Min cost to connect all points** (LC 1584): Template F on dense graphs.
- **Min cost to connect two groups**: MST with bipartite constraint.
- **Remove max edges to keep graph traversable** (LC 1579): two DSUs (Alice, Bob) processed with "type 3" edges first.
- **Swim in rising water** (LC 778): alternative to Dijkstra — Kruskal-like DSU.

### Offline / sorted events
- **Earliest time to reach target**: sort edges by time, union until target connects.
- **Minimum similarity after removals**: process removals in reverse (as additions).
- **Hit counter with DSU** (Next-available-slot trick): union `i` with `i+1` when slot `i` is used; LC 1396.

### Non-standard keys
- **Accounts merge** (LC 721): email strings — dict-DSU.
- **Largest component size by common factor** (LC 952): indices share a component if they share a prime factor.
- **Minimize malware spread** (LC 924, LC 928): component analysis with "infected" nodes.
- **Rank transform of a matrix** (LC 1632): complex DSU with auxiliary per-row/col state.

### Edge cases & pitfalls
- **Self-loops** (`union(x, x)`): find returns same root; `union` returns `False`. Often harmless.
- **Parallel edges**: second one signals "redundant"; first union may already have joined them.
- **Forgetting `rank`/`size`**: without balancing, worst-case chains appear on adversarial inputs.
- **Using plain find without compression**: on skewed inputs, `find` goes `O(n)` per call → `O(nm)` overall.
- **Integer overflow in weighted DSU**: compression multiplies floats; precision drift over many unions.
- **Wrong assumption of symmetry for directed graphs**: DSU is inherently undirected. For directed cycle detection use three-colour DFS.
- **Removing edges**: DSU can't undo `union` (without rollback). For dynamic connectivity with deletions, process offline in reverse or use Euler Tour Trees.
- **Iterating components after unions**: the `parent` array alone doesn't let you enumerate members; maintain `{root: [members]}` or re-scan after all unions.
- **Array vs dict sizing**: for integer keys ≤ 10^5, array DSU is faster. For sparse or string keys, dict DSU is cleaner.

## 7. Related Patterns
- **Graph DFS / BFS** — alternatives for **static** component counts; DSU wins when the graph is built online.
- **Kruskal's Algorithm** — MST using DSU as the cycle oracle.
- **Topological Sort** — does not use DSU; directed acyclicity is a different invariant.
- **Hashing** — often the first step before DSU: map arbitrary keys (emails, strings) to integer indices.
- **Tarjan's Offline LCA / Offline Range Queries** — DSU with rollback or persistent DSU.
- **Link-Cut Trees / Euler Tour Trees** — support edge deletions; strictly more powerful than DSU but far more complex.
- **Segment Tree Beats / Persistent Data Structures** — orthogonal; used when you need history.
- **Strongly Connected Components** — DSU doesn't give SCC (directed); Tarjan/Kosaraju do.

**Distinguishing note**: reach for DSU when the input arrives as a **stream of equivalences** and you must answer "same group?" queries online, or when you need a cycle oracle for Kruskal's MST. Reach for BFS/DFS when the graph is static and you need **distance** or **path** information, not just connectivity. Reach for **Tarjan/Kosaraju** for directed strongly-connected structure. The clearest tell for DSU is a problem statement that mentions edges or equivalences arriving over time, or a grouping structure derived from transitivity.
