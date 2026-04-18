# 19 — Heap / Priority Queue

## 1. When to Use
- You need fast access to the **smallest** or **largest** element of a dynamic collection.
- Keywords: *"top k"*, *"kth largest / smallest"*, *"k closest"*, *"merge k sorted"*, *"scheduler"*, *"median of stream"*, *"shortest path with weights"* (Dijkstra).
- You are streaming data and must not sort it all at once.
- You want `O(n log k)` rather than `O(n log n)` because only the top `k` matter.
- You need repeated `extract_min` / `extract_max` with occasional inserts.

## 2. Core Idea
A binary heap is a complete binary tree stored in an array, with the invariant that every parent is ≤ (min-heap) or ≥ (max-heap) its children. Insertion and extraction cost `O(log n)` because the tree is height-balanced by construction. For "top k" problems, keep a heap of size `k`: each arriving element pushes in `O(log k)` and, if the heap grows too big, pops the wrong-side element — so you never store more than `k`.

## 3. Template
```python
import heapq

# 1) heapq is a min-heap. For max-heap, negate values.
pq = []                                  # min-heap
heapq.heappush(pq, 5)
heapq.heappush(pq, 2)
smallest = heapq.heappop(pq)            # 2

# 2) Top-k largest with a min-heap of size k
def top_k(nums, k):
    h = []
    for x in nums:
        heapq.heappush(h, x)
        if len(h) > k:
            heapq.heappop(h)            # drop smallest so the k largest remain
    return h                             # the k largest, in arbitrary order

# 3) Merge k sorted lists using a heap of (value, list_id, index)
def merge_k(lists):
    h = []
    for i, lst in enumerate(lists):
        if lst: heapq.heappush(h, (lst[0], i, 0))
    out = []
    while h:
        val, i, j = heapq.heappop(h)
        out.append(val)
        if j + 1 < len(lists[i]):
            heapq.heappush(h, (lists[i][j + 1], i, j + 1))
    return out

# 4) Two-heap median (max-heap of lower half, min-heap of upper half)
class MedianFinder:
    def __init__(self):
        self.lo = []   # max-heap, store as negated values
        self.hi = []   # min-heap

    def addNum(self, x):
        heapq.heappush(self.lo, -x)
        heapq.heappush(self.hi, -heapq.heappop(self.lo))
        if len(self.hi) > len(self.lo):
            heapq.heappush(self.lo, -heapq.heappop(self.hi))

    def findMedian(self):
        if len(self.lo) > len(self.hi): return -self.lo[0]
        return (-self.lo[0] + self.hi[0]) / 2
```
Key mental tools:
- Python's `heapq` is min-only. Push `-x` (or `(-priority, x)`) for max-heap behaviour.
- For tie-breakers on non-comparable items, push `(priority, counter, item)`; `counter` ensures stable ordering and avoids TypeError.
- `heapify(arr)` turns any list into a heap in `O(n)` — faster than `n` pushes.
- `heapq.nlargest(k, arr)` / `nsmallest(k, arr)` are `O(n log k)` shortcuts.

## 4. Classic Problems
- **LC 215 — Kth Largest Element in an Array** (Medium): min-heap of size `k`.
- **LC 23 — Merge k Sorted Lists** (Hard): heap over list heads.
- **LC 295 — Find Median from Data Stream** (Hard): two heaps.
- **LC 347 — Top K Frequent Elements** (Medium): heap of size `k` over `(freq, val)`.
- **LC 621 — Task Scheduler** (Medium): max-heap of remaining counts with cooldowns.

## 5. Worked Example — Kth Largest Element in an Array (LC 215)
Problem: find the `k`-th largest element in `nums = [3, 2, 1, 5, 6, 4]`, `k = 2`.

Approach: maintain a min-heap of size `k`. After processing all elements, the heap holds the `k` largest values; the root is the smallest of those, which is the `k`-th largest overall.

```python
import heapq

def findKthLargest(nums, k):
    h = []
    for x in nums:
        heapq.heappush(h, x)
        if len(h) > k:
            heapq.heappop(h)
    return h[0]
```

Trace (heap root on the left):

| step | `x` | action | heap after | heap size |
|---|---|---|---|---|
| 1 | 3 | push 3 | `[3]` | 1 |
| 2 | 2 | push 2 | `[2, 3]` | 2 |
| 3 | 1 | push 1 → size 3 > k, pop min (1) | `[2, 3]` | 2 |
| 4 | 5 | push 5 → size 3 > k, pop min (2) | `[3, 5]` | 2 |
| 5 | 6 | push 6 → size 3 > k, pop min (3) | `[5, 6]` | 2 |
| 6 | 4 | push 4 → size 3 > k, pop min (4) | `[5, 6]` | 2 |

Return `h[0] = 5`. The 2nd largest of `[3, 2, 1, 5, 6, 4]` is indeed `5`. Time `O(n log k)`, space `O(k)`. For small `k` this beats sorting (`O(n log n)`).

## 6. Common Variations
- **K closest points to origin** (LC 973): max-heap of size `k` on distance.
- **Top-k frequent** (LC 347): build a Counter, then heap of size `k`.
- **K-way merge**: generalises merging two sorted lists; also appears in external sorting.
- **Dijkstra**: min-heap of `(dist, node)` gives shortest paths in `O((V + E) log V)`.
- **Prim's MST**: min-heap of candidate edges.
- **Scheduler with cooldown** (LC 621): alternate popping from a max-heap and parking on a cooldown queue.
- **Decrease-key**: classical heaps do not support it; use lazy deletion (push the new priority, skip stale entries on pop) or a Fibonacci heap (theoretical).
- **Edge cases**: `k = 0`, `k == len(nums)`, duplicates (matters for "kth *distinct*"), empty stream.

## 7. Related Patterns
- **Sorting** — a full sort is sometimes simpler; heap wins when only top-k or online data.
- **Binary Search** — competing approach for "kth smallest" on sorted or monotone structures.
- **Quickselect** — `O(n)` expected for kth element, no auxiliary structure; heap is worst-case `O(n log k)`.
- **BST** — supports rank / successor as well as min/max; heap only supports one end.
- **Graph BFS** — Dijkstra is BFS on a weighted graph, with the queue upgraded to a heap.

Distinguishing note: if the question is "top k" or "kth" and the full sort wastes work, use a **heap of size k**. If the data fits in memory and you need everything sorted, just sort. If the data is weighted-graph shortest path, Dijkstra's heap is the canonical form.
