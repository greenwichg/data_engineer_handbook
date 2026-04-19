# 19 — Heap / Priority Queue

## 1. When to Use
- You need fast access to the **smallest** or **largest** element of a dynamic collection, with cheap insert and extract.
- Keywords: *"top k"*, *"kth largest / smallest"*, *"k closest"*, *"merge k sorted"*, *"scheduler"*, *"median of stream"*, *"shortest path with weights"* (Dijkstra), *"meeting rooms"*, *"task cooldown"*, *"k pairs with smallest sums"*, *"ugly numbers"*, *"super ugly"*, *"reorganise string"*.
- You are **streaming** data and must not sort it all at once.
- You want `O(n log k)` rather than `O(n log n)` because only the top `k` matter.
- You need repeated `extract_min` / `extract_max` with occasional inserts; a sorted array would be `O(n)` per insert.
- You need to **merge many sorted streams** or a **k-way merge** where a single sort would be too memory-heavy.
- You need a **priority-aware event loop** — running whichever task is "most urgent right now" — in schedulers, simulations, and pathfinding.
- You need a **two-heap balance** for running-median queries.

### Signals this is NOT a heap problem
- You want the `k`-th element in `O(n)` average without needing the others sorted → **quickselect** beats heap asymptotically (but heap is simpler).
- You need *all* order statistics (rank, select, successor) → BST or sorted container is better.
- You have edge weights that are `0` or `1` only → 0-1 BFS deque beats Dijkstra.
- You know `k` is constant (e.g. 10) and `n` is small — sorting may be faster in practice due to cache effects.

## 2. Core Idea
A binary heap is a **complete binary tree stored in an array**, with the invariant that every parent is ≤ (min-heap) or ≥ (max-heap) its children. Insertion and extraction cost `O(log n)` because the tree is height-balanced by construction — the completeness property guarantees `log n` depth, and the sift-up / sift-down walk touches one ancestor chain.

For "top k" problems, keep a **heap of size `k`**: each arriving element pushes in `O(log k)` and, if the heap grows too big, pops the wrong-side element — so you never store more than `k`. This gives `O(n log k)` overall, strictly better than `O(n log n)` sorting when `k << n`.

### Array layout of a binary heap
For a 0-indexed array `h`:
- `parent(i) = (i - 1) // 2`
- `left(i) = 2 * i + 1`
- `right(i) = 2 * i + 2`

Completeness is maintained by always inserting at index `len(h)` and always popping from index 0 (then moving the last element to index 0 and sifting down). The array is **not sorted**; only the parent-child invariant holds.

### Why `heapify` is O(n), not O(n log n)
A naive build — `n` pushes — is `O(n log n)`. Floyd's sift-down from `n//2 - 1` down to 0 is `O(n)` because most of the tree's nodes are near the leaves, and their sift-down work is bounded by their height. Summing `Σ (h * nodes_at_that_height) = O(n)`. This `O(n)` build is a frequent interview follow-up.

### Heap variants
- **Min-heap**: root is smallest; Python's `heapq` default.
- **Max-heap**: negate values, or push `(-priority, item)` tuples.
- **Indexed heap / decrease-key heap**: supports `update(key, new_priority)` in `O(log n)`. `heapq` doesn't; use **lazy deletion** (push new priority, skip stale entries at pop time).
- **Double-ended priority queue**: min-max heap, interval heap — rare in interviews.
- **Fibonacci heap**: `O(1)` amortised decrease-key; theoretical. Dijkstra's `O(E + V log V)` uses this.

## 3. Template

### Template A — basic heap operations
```python
import heapq                      # GOTCHA: stdlib module provides MIN-heap only — no `heappushmax`

# heapq is a min-heap.
pq = []
heapq.heappush(pq, 5)             # O(log n); mutates pq in place
heapq.heappush(pq, 2)
heapq.heappush(pq, 7)
print(heapq.heappop(pq))          # 2  (smallest). GOTCHA: heappop mutates AND returns

# heapify in O(n)
arr = [5, 3, 8, 1, 9, 2]
heapq.heapify(arr)                # GOTCHA: mutates in place, returns None. arr IS the heap (not sorted!)

# Max-heap by negation
max_pq = []
heapq.heappush(max_pq, -x)        # negate on push
largest = -heapq.heappop(max_pq)  # negate on pop to restore original

# Shortcut aggregates (both O(n log k))
heapq.nlargest(3, arr)            # returns list in descending order; not a heap
heapq.nsmallest(3, arr)           # returns list in ascending order
```

### Template B — top-k largest with a min-heap of size k
```python
def top_k_largest(nums, k):
    h = []                               # MIN-heap of size k holds the k LARGEST seen
    for x in nums:
        heapq.heappush(h, x)
        if len(h) > k:
            heapq.heappop(h)             # drop smallest so the k largest remain
    return h                              # k largest in ARBITRARY order (heap not sorted)

# Kth largest itself:
def kth_largest(nums, k):
    return top_k_largest(nums, k)[0]     # h[0] is the ROOT = smallest-of-k = kth largest overall
```

### Template C — top-k frequent (heap over (count, item))
```python
from collections import Counter

def top_k_frequent(nums, k):
    counts = Counter(nums)               # Counter: dict subclass; O(n) one-pass count
    h = []
    for val, c in counts.items():        # .items() yields (key, value) pairs
        heapq.heappush(h, (c, val))      # GOTCHA: (count, val) — heap compares by count FIRST, then val
        if len(h) > k:
            heapq.heappop(h)
    return [val for _, val in h]         # unpack tuple; `_` discards count
```

### Template D — merge k sorted lists
```python
def merge_k(lists):
    h = []
    for i, lst in enumerate(lists):
        if lst:                                   # skip empty lists — else lst[0] raises IndexError
            heapq.heappush(h, (lst[0], i, 0))    # (value, list_idx, elem_idx). i = tie-breaker + locator
    out = []
    while h:
        val, i, j = heapq.heappop(h)              # tuple-unpack
        out.append(val)
        if j + 1 < len(lists[i]):                 # only enqueue if NEXT index exists
            heapq.heappush(h, (lists[i][j + 1], i, j + 1))
    return out
```

### Template E — two-heap median
```python
class MedianFinder:
    def __init__(self):
        self.lo = []                       # max-heap via negation; lower half (values stored as negatives)
        self.hi = []                       # min-heap; upper half

    def addNum(self, x):
        heapq.heappush(self.lo, -x)        # push negative to simulate max-heap
        heapq.heappush(self.hi, -heapq.heappop(self.lo))   # move lo's max to hi (double-negate to restore)
        if len(self.hi) > len(self.lo):
            heapq.heappush(self.lo, -heapq.heappop(self.hi))   # rebalance: push hi's min back to lo

    def findMedian(self):
        if len(self.lo) > len(self.hi):
            return -self.lo[0]              # odd total; negate back. GOTCHA: list[0] is peek — heap not sorted
        return (-self.lo[0] + self.hi[0]) / 2   # even → average the roots. `/` is float division in Py3
```

### Template F — Dijkstra's algorithm (weighted shortest path)
```python
def dijkstra(graph, src):
    """graph: adjacency list {u: [(v, w), ...]} with non-negative weights."""
    dist = {src: 0}
    pq = [(0, src)]                        # (distance, node) — distance FIRST so heap orders by it
    while pq:
        d, u = heapq.heappop(pq)
        if d > dist.get(u, float('inf')):  # dict.get avoids KeyError; default +inf
            continue                        # lazy-deleted stale entry — don't remove from heap, skip
        for v, w in graph.get(u, []):       # .get with [] default: absent key → empty neighbour list
            nd = d + w
            if nd < dist.get(v, float('inf')):
                dist[v] = nd
                heapq.heappush(pq, (nd, v))   # push even if already exists — stale entries filtered above
    return dist
```

### Template G — tie-break with a counter (stable on non-comparable payloads)
```python
import itertools

class PriorityQueue:
    def __init__(self):
        self.pq = []
        self.counter = itertools.count()   # infinite counter starting at 0
    def push(self, priority, item):
        heapq.heappush(self.pq, (priority, next(self.counter), item))    # counter prevents TypeError on item comparison
    def pop(self):
        priority, _, item = heapq.heappop(self.pq)    # `_` discards counter
        return priority, item               # implicit tuple return
```

The `counter` prevents `TypeError` when two tuples tie on `priority` and Python tries to compare `item` objects that may not support `<`.

### Template H — task scheduler / cooldown (max-heap + queue)
```python
from collections import deque, Counter

def least_interval(tasks, n):
    counts = Counter(tasks)                # count each task's frequency
    h = [-c for c in counts.values()]      # GOTCHA: negate for max-heap; list-comp over .values()
    heapq.heapify(h)                       # O(n) heap build — faster than n pushes
    cooldown = deque()                     # (available_time, count) tuples, FIFO
    time = 0
    while h or cooldown:                   # loop while EITHER has work
        time += 1
        if h:
            c = heapq.heappop(h) + 1       # `+1` because counts are NEGATIVE (decrement toward 0)
            if c < 0:                       # still tasks left of this type
                cooldown.append((time + n, c))
        if cooldown and cooldown[0][0] == time:
            heapq.heappush(h, cooldown.popleft()[1])   # [1] extracts count from tuple
    return time
```

Key mental tools:
- Python's `heapq` is **min-only**. Push `-x` (or `(-priority, x)`) for max-heap behaviour.
- For tie-breakers on non-comparable items, push `(priority, counter, item)`; the `counter` ensures stable ordering and avoids `TypeError` on payload comparison.
- `heapify(arr)` turns any list into a heap in `O(n)` — always prefer over `n` pushes when you have all elements up front.
- `heapq.nlargest(k, arr)` / `nsmallest(k, arr)` are `O(n log k)` shortcuts and pass a `key=` parameter.
- **Lazy deletion**: when you can't `decrease-key`, push a new entry and skip stale ones at pop time. Dijkstra's `if d > dist[u]: continue` is the canonical lazy-delete pattern.
- **Size-k invariant**: for top-k problems, the heap **never grows past k** — this bounds both time and memory.
- For a **max-heap of non-numeric priorities**, a neat trick is to implement a wrapper class with `__lt__` inverted.
- `heapq` is **not thread-safe**; use `queue.PriorityQueue` for that (comes with locking overhead).

## 4. Classic Problems
- **LC 215 — Kth Largest Element in an Array** (Medium): min-heap of size `k` (Template B). Quickselect is the `O(n)`-expected alternative.
- **LC 703 — Kth Largest Element in a Stream** (Easy): same, but online — bounded heap naturally supports streams.
- **LC 347 — Top K Frequent Elements** (Medium): Template C.
- **LC 973 — K Closest Points to Origin** (Medium): max-heap of size `k` keyed on distance.
- **LC 23 — Merge k Sorted Lists** (Hard): Template D.
- **LC 295 — Find Median from Data Stream** (Hard): two heaps, Template E.
- **LC 621 — Task Scheduler** (Medium): max-heap + cooldown queue (Template H).
- **LC 767 — Reorganize String** (Medium): max-heap of `(count, char)`, always pick the two most frequent.
- **LC 253 — Meeting Rooms II** (Medium): min-heap of end times; number of rooms needed = heap size.
- **LC 1642 — Furthest Building You Can Reach** (Medium): min-heap to track the `k` largest jumps that consumed ladders.
- **LC 743 — Network Delay Time** (Medium): Dijkstra (Template F).
- **LC 378 — Kth Smallest in Sorted Matrix** (Medium): min-heap with row/col pointers, or binary-search on value.

## 5. Worked Example — Find Median from Data Stream (LC 295)
Problem: design a data structure that supports:
- `addNum(x)` — insert a number (called many times).
- `findMedian()` — return the median of all numbers seen so far (called many times).

Naive: maintain a sorted list. `addNum` is `O(n)` (binary-search insert), `findMedian` is `O(1)`. Too slow if both ops are hot.

Better: **two heaps** that each hold roughly half the numbers.

### Step 1. The invariant
Maintain:
- `lo`: a **max-heap** holding the smaller half (via negation).
- `hi`: a **min-heap** holding the larger half.
- `|len(lo) - len(hi)| <= 1`, with `len(lo) >= len(hi)` (a convention).
- Every element of `lo` is `<=` every element of `hi`.

Under this invariant:
- If `len(lo) > len(hi)`, the median is `lo`'s max (root).
- Else, the median is the average of `lo`'s max and `hi`'s min.

Both queries are `O(1)`; insertions are `O(log n)` because we only touch logs on push/pop.

### Step 2. Insertion algorithm
To add `x`, we'd like to place it in whichever side keeps the invariant. A clean trick:
1. Push `x` into `lo`.
2. Move the max of `lo` to `hi` (this ensures every `lo` ≤ every `hi`).
3. If now `len(hi) > len(lo)`, move the min of `hi` back to `lo` to restore the size invariant.

This takes three heap operations — all `O(log n)`. It's a "pass through both heaps" that guarantees both invariants.

### Step 3. Implement
```python
import heapq

class MedianFinder:
    def __init__(self):
        self.lo = []        # max-heap (store negatives — heappop returns -max, negate to get max)
        self.hi = []        # min-heap (stores actual values)

    def addNum(self, x):
        heapq.heappush(self.lo, -x)                               # step 1: tentatively add to lo
        heapq.heappush(self.hi, -heapq.heappop(self.lo))          # step 2: hand off lo's max to hi
        if len(self.hi) > len(self.lo):                           # step 3: rebalance if needed
            heapq.heappush(self.lo, -heapq.heappop(self.hi))

    def findMedian(self):
        if len(self.lo) > len(self.hi):
            return -self.lo[0]                                     # odd total → lo has one extra
        return (-self.lo[0] + self.hi[0]) / 2                      # even → average roots; `/` returns float
```

### Step 4. Trace the stream `[1, 2, 3, 4, 5]`
Show `lo` as its max-at-root (negate the stored values), `hi` as its min-at-root.

| op | stream | step | `lo` (max-heap, show values) | `hi` (min-heap) | median |
|---|---|---|---|---|---|
| `addNum(1)` | `[1]` | push 1 to lo, move to hi, size imbalance 0>1? no wait — hi has 1, lo is empty → rebalance | lo=[], hi=[1] → `len(hi)>len(lo)` → move 1 back | lo=[1], hi=[] | — |
| `findMedian` | — | | lo=[1], hi=[] | | `1` |
| `addNum(2)` | `[1,2]` | push 2 to lo → lo has max=2; move to hi → hi=[2]; sizes ok | | lo=[1], hi=[2] | — |
| `findMedian` | — | | | | `(1+2)/2 = 1.5` |
| `addNum(3)` | `[1,2,3]` | push 3 to lo (lo max=3); move 3 to hi; now hi=[2,3], lo=[1]; rebalance → move 2 back | | lo=[2,1], hi=[3] | — |
| `findMedian` | — | | | | `2` |
| `addNum(4)` | `[1..4]` | push 4 to lo (lo max=4); move 4 to hi → hi=[3,4]; sizes `len(hi)=2, len(lo)=2` — ok | | lo=[2,1], hi=[3,4] | — |
| `findMedian` | — | | | | `(2+3)/2 = 2.5` |
| `addNum(5)` | `[1..5]` | push 5 to lo (lo max=5); move 5 to hi → hi=[3,4,5]; rebalance → move 3 back to lo | | lo=[3,1,2], hi=[4,5] | — |
| `findMedian` | — | | | | `3` |

Medians emitted: `1, 1.5, 2, 2.5, 3` — matching the true medians of prefixes `[1], [1,2], [1,2,3], [1,2,3,4], [1,2,3,4,5]` ✓.

### Step 5. Why the push-cross-rebalance trick works
Step 1 (`lo.push(x)`) may put a too-large element in `lo`.

Step 2 (`hi.push(lo.pop())`) removes the largest element of `lo` and moves it to `hi`. After this step, every element remaining in `lo` is `<= the element moved`, which is `<= every original element of hi` — so the **cross-invariant** (all `lo <=` all `hi`) is preserved.

Step 3 corrects the **size invariant**: if `hi` is now bigger, move its smallest back to `lo`.

The elegance is that a single canonical flow — push, hand off, rebalance — handles all insertion cases (x belongs in lo, x belongs in hi, sizes equal or off by one) without branching.

### Step 6. Complexity
- `addNum`: `O(log n)` — three heap operations.
- `findMedian`: `O(1)` — peek at one or both roots.
- Space: `O(n)` total across both heaps.

### Step 7. Alternatives and tradeoffs
- **Sorted list** (`bisect.insort`): `O(n)` add, `O(1)` median — bad if adds are hot.
- **Balanced BST / order statistic tree**: `O(log n)` add and median via rank query — same as two heaps, but harder to implement from scratch.
- **Two heaps**: the interview canonical. Clean, short, and purely uses stdlib `heapq`.

## 6. Common Variations

### Top-k and kth
- **Kth largest in array** (LC 215): min-heap of size k; quickselect for `O(n)` expected.
- **Kth largest in stream** (LC 703): same, but online.
- **K closest points to origin** (LC 973): max-heap on distance (keep smallest k distances).
- **K smallest pairs with smallest sums** (LC 373): seed with `(a[0], b[j])`, pop and expand.
- **Find K pairs with smallest sums** (LC 373): min-heap over pair-index BFS.
- **Top K frequent elements** (LC 347): Template C or bucket sort for `O(n)`.
- **Top K frequent words** (LC 692): tie-break by alphabetical — use `(count, word)` where word compares lexicographically under max-heap negation of counts.

### Merge / stream
- **Merge k sorted lists** (LC 23): Template D.
- **Smallest range covering elements from k lists** (LC 632): heap of current front per list; track range span.
- **Ugly number II** (LC 264): min-heap emitting multiples of 2/3/5; dedup with a set. Or three-pointer DP.
- **Super ugly number** (LC 313): generalise to k primes.
- **Sort nearly sorted array**: heap of size k+1 emits sorted stream; `O(n log k)`.

### Scheduler / interval / cooldown
- **Meeting rooms II** (LC 253): min-heap of end times.
- **Task scheduler** (LC 621): Template H.
- **Reorganize string** (LC 767): max-heap, always place the two most frequent distinct chars.
- **Rearrange string k distance apart** (LC 358): extension with a cooldown window.
- **Single-threaded CPU** (LC 1834): sort by arrival, then a ready-queue heap.
- **Minimum number of refueling stops** (LC 871): max-heap of gas station fuels reachable.

### Two-heap patterns
- **Median from data stream** (LC 295): Template E.
- **Sliding window median** (LC 480): two heaps + lazy deletion.
- **IPO** (LC 502): one heap of affordable profits (max), one of unaffordable capitals (min).

### Dijkstra and graph variants
- **Network delay time** (LC 743): Template F.
- **Cheapest flights within k stops** (LC 787): heap of `(cost, stops, node)`.
- **Swim in rising water** (LC 778): modified Dijkstra on a grid.
- **Path with minimum effort** (LC 1631): minimise max edge weight along path.
- **Minimum spanning tree** (Prim's): heap of candidate edges from frontier.

### Lazy deletion idioms
- Stream + window → keep pushing, pop stale entries when they surface.
- "Decrease-key" missing → push new priority, skip if stale.
- Typical check: `if d > dist[u]: continue` or `if timestamp < cutoff: continue`.

### Edge cases & pitfalls
- **k = 0**: define behaviour up front (usually `[]`).
- **k >= n**: the heap never trims; return everything or sort.
- **Duplicates**: important for "kth distinct" — must track uniqueness explicitly.
- **Empty stream / empty heap**: peek before pop; return sentinel.
- **Tie-break `TypeError`**: when `priority` ties, Python compares the next tuple element. Payloads must be comparable; insert a monotonically increasing counter.
- **Negation overflow**: Python fine; Java/C++ be careful with `Integer.MIN_VALUE`.
- **Modifying items in place**: if `item` is a mutable dict/list, mutating it after push breaks the heap invariant. Push tuples with immutable priorities.
- **Using a list as a max-heap directly**: Python has no `heapq.heappush_max`; negate or wrap.
- **Heap vs sorted list**: a sorted list (`SortedList` from `sortedcontainers`) is `O(log n)` for *everything*, including rank/select — often overlooked when the interviewer wants "kth".

## 7. Related Patterns
- **Sorting** — a full sort is sometimes simpler; heap wins when only top-k or online data.
- **Binary Search** — competing approach for "kth smallest" on sorted or monotone structures.
- **Quickselect** — `O(n)` expected for kth element, no auxiliary structure; heap is `O(n log k)` worst-case but simpler to code correctly under time pressure.
- **BST / Sorted Containers** — supports rank / successor as well as min/max; heap only supports one end. Trade features for speed.
- **Graph BFS** — Dijkstra is BFS on a weighted graph, with the queue upgraded to a heap. 0-1 BFS fills the gap for binary weights.
- **Greedy** — heaps are the main data structure behind greedy algorithms that "always pick the most urgent / best so far".
- **Interval problems** — heap of end-times underpins meeting-rooms, exam-rooms, and most "how many concurrent X" questions.
- **Monotonic deque** — an alternative to heap for sliding-window max/min when the window is **contiguous** (not priority-based).

**Distinguishing note**: if the question is "top k" or "kth" and a full sort wastes work, use a **heap of size k**. If the data fits in memory and you need everything sorted, just sort. If the data is weighted-graph shortest path, **Dijkstra's heap** is the canonical form. If you need both ends of a priority range, use **two heaps** (median) or a balanced BST. If you need `decrease-key`, use **lazy deletion** unless the algorithm is taught with a Fibonacci heap.
