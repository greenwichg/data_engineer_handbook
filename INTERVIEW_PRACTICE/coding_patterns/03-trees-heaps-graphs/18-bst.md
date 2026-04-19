# 18 — BST (Binary Search Tree)

## 1. When to Use
- Problem states the input is a **BST** (`left subtree < node.val < right subtree`, or with a defined tie-break for duplicates).
- Keywords: *"kth smallest / largest"*, *"range sum in BST"*, *"successor / predecessor"*, *"validate BST"*, *"insert / delete in BST"*, *"trim BST"*, *"closest value"*, *"recover BST with two swaps"*, *"convert sorted structure to BST"*, *"iterator over BST"*.
- You need both **ordered traversal** and **O(log n) search** from the same structure.
- You are asked for operations that would be trivial on a sorted array, but on **dynamic** data (inserts and deletes between queries).
- You want a persistent structure that supports **rank queries** ("how many elements are less than x") or **select queries** ("give me the 5th smallest") — augmented BST.
- You are designing an in-memory index for range queries with mutations.
- You need to build a tree from a sorted array or sorted linked list (LC 108, LC 109) — the BST structure is defined by mid-picking recursion.

### Signals this is NOT a BST-specific problem
- The tree is an arbitrary binary tree (no ordering) → Tree DFS / BFS.
- You only need min / max or top-k → heap is strictly simpler and faster.
- You need `O(log n)` worst-case on *any* input → vanilla BST can skew to `O(n)`; you need a self-balancing tree (AVL, Red-Black, Treap) — usually not expected in interviews unless asked.
- The data is **static and sorted** — a sorted array + binary search is better than building a BST.

## 2. Core Idea
A BST encodes a sorted order implicitly: **in-order traversal visits keys ascending**, and for any query you compare against the current node and descend into exactly one subtree. When the tree is balanced, search / insert / delete are all `O(log n)`. When it is skewed (e.g. built from a sorted input without balancing), operations degrade to `O(n)` — which is why Red-Black and AVL trees exist in standard libraries.

Three BST facts power most problems:
1. **In-order = sorted**. If the question touches order statistics, reach for in-order first.
2. **Search descends one side**. At each node, the left and right subtrees are disjoint in value ranges — one comparison rules out half the tree (on average).
3. **Valid bounds propagate downward**. A node's valid value range is `(parent_lower_bound, parent_upper_bound)`, tightened by each step you take left or right.

The single most common bug in BST problems is **validating a BST by comparing only to immediate children** — this misses grandchild violations. E.g. the tree `[10, 5, 15, null, null, 6, 20]` has `10 < 15` (ok), `6 < 15` (ok as left child of 15), but the BST invariant is violated because 6 is in 10's right subtree yet is less than 10. The correct validation passes `(lo, hi)` **bounds** through the recursion.

### Successor and predecessor
Two derived operations worth memorising:
- **Successor** of `node`: smallest key strictly greater than `node.val`.
  - If `node.right` exists → leftmost of `node.right`.
  - Else → walk up ancestors until you find one you came to via its left child; that ancestor is the successor (or none exists → you're at the max).
- **Predecessor** of `node`: symmetric (swap left/right).

These underpin deletion (replace-with-successor), iterators (LC 173), and range queries.

## 3. Template

### Template A — search (iterative is simpler than recursive)
```python
def search(root, target):
    while root:
        if target == root.val: return root
        root = root.left if target < root.val else root.right
    return None
```

### Template B — insert
```python
def insert(root, val):
    if root is None:
        return TreeNode(val)
    if val < root.val:
        root.left  = insert(root.left,  val)
    else:
        root.right = insert(root.right, val)
    return root
```

### Template C — delete (classic three-case)
```python
def delete(root, key):
    if root is None: return None
    if key < root.val:
        root.left = delete(root.left, key)
    elif key > root.val:
        root.right = delete(root.right, key)
    else:
        # Case 1: no children
        if root.left is None and root.right is None:
            return None
        # Case 2: one child
        if root.left is None:  return root.right
        if root.right is None: return root.left
        # Case 3: two children — replace with in-order successor
        succ = root.right
        while succ.left:
            succ = succ.left
        root.val = succ.val
        root.right = delete(root.right, succ.val)
    return root
```

### Template D — validate via bounds propagation
```python
def is_valid(root, lo=float('-inf'), hi=float('inf')):
    if root is None: return True
    if not (lo < root.val < hi): return False
    return (is_valid(root.left,  lo, root.val)
        and is_valid(root.right, root.val, hi))
```

### Template E — in-order iterator (kth smallest, BST iterator)
```python
def kth_smallest(root, k):
    stack = []
    node = root
    while stack or node:
        while node:                     # dive left
            stack.append(node); node = node.left
        node = stack.pop()              # visit
        k -= 1
        if k == 0: return node.val
        node = node.right               # dive right

class BSTIterator:                       # LC 173 — amortised O(1) next
    def __init__(self, root):
        self.stack = []
        self._push_left(root)
    def _push_left(self, node):
        while node:
            self.stack.append(node); node = node.left
    def next(self):
        node = self.stack.pop()
        self._push_left(node.right)
        return node.val
    def hasNext(self):
        return bool(self.stack)
```

### Template F — range sum / trim / filter by range
```python
def range_sum(root, lo, hi):
    if root is None: return 0
    if root.val < lo: return range_sum(root.right, lo, hi)   # prune left
    if root.val > hi: return range_sum(root.left,  lo, hi)   # prune right
    return root.val + range_sum(root.left, lo, hi) + range_sum(root.right, lo, hi)

def trim(root, lo, hi):
    if root is None: return None
    if root.val < lo: return trim(root.right, lo, hi)
    if root.val > hi: return trim(root.left,  lo, hi)
    root.left  = trim(root.left,  lo, hi)
    root.right = trim(root.right, lo, hi)
    return root
```

### Template G — build balanced BST from sorted input
```python
def sorted_array_to_bst(arr):
    def go(lo, hi):
        if lo > hi: return None
        mid = (lo + hi) // 2
        node = TreeNode(arr[mid])
        node.left  = go(lo, mid - 1)
        node.right = go(mid + 1, hi)
        return node
    return go(0, len(arr) - 1)
```

### Template H — LCA in BST
```python
def lca_bst(root, p, q):
    while root:
        if p.val < root.val and q.val < root.val:
            root = root.left
        elif p.val > root.val and q.val > root.val:
            root = root.right
        else:
            return root                  # split point
    return None
```

Key mental tools:
- **In-order = sorted** — the single most powerful BST fact. If the question hints at order, sort, or "kth", start here.
- Validate with **bounds propagation** (Template D), not child-local comparisons.
- **Successor** of `node`: if `node.right` exists, leftmost of `node.right`; else walk up until you come from a left child.
- **Deletion**: two-child case swaps with in-order successor (or predecessor) and recursively deletes the successor.
- **Range pruning**: in-order traversal with `val < lo` or `val > hi` shortcuts lets you skip entire subtrees — this is the "BST is indexed" superpower.
- **Duplicates policy**: pick `<` vs `<=` up front and stick to it. Most problems assume unique keys; confirm.
- **Recursion depth on skewed input**: for `n = 10^5` and an adversarial insert order, recursion blows the default limit — iterate or set `sys.setrecursionlimit`.
- **Iterative is cleaner** than recursive for search and LCA — the descent is naturally a loop.

## 4. Classic Problems
- **LC 98 — Validate BST** (Medium): Template D bounds-propagating recursion.
- **LC 230 — Kth Smallest Element in a BST** (Medium): Template E in-order iterator.
- **LC 173 — Binary Search Tree Iterator** (Medium): Template E class form; amortised O(1) per `next`.
- **LC 235 — Lowest Common Ancestor of BST** (Easy): Template H descend while both on same side.
- **LC 236 — Lowest Common Ancestor of Binary Tree** (Medium): not BST-specific; post-order DFS.
- **LC 108 — Convert Sorted Array to BST** (Easy): Template G.
- **LC 109 — Convert Sorted List to BST** (Medium): in-order simulation with a list pointer.
- **LC 450 — Delete Node in a BST** (Medium): Template C successor swap.
- **LC 700 — Search in a BST** (Easy): Template A.
- **LC 701 — Insert into a BST** (Medium): Template B.
- **LC 938 — Range Sum of BST** (Easy): Template F.
- **LC 669 — Trim a BST** (Medium): Template F trim variant.
- **LC 99 — Recover BST** (Medium): in-order finds two swapped nodes.
- **LC 270 — Closest BST Value** (Easy): descend while tracking the best `|val - target|`.
- **LC 653 — Two Sum IV** (Easy): in-order + two pointers, or set.

## 5. Worked Example — Validate BST (LC 98)
Problem: given a binary tree, determine if it is a valid BST. A valid BST is defined as:
- The left subtree of a node contains only nodes with keys **strictly less than** the node's key.
- The right subtree contains only nodes with keys **strictly greater**.
- Both left and right subtrees must also be BSTs.

This is the canonical "BST invariant" problem. The wrong solutions are instructive and often appear in real code review.

### Why "just compare to children" is wrong
A naive check: "for every node, `node.left.val < node.val < node.right.val`." This fails on:

```
      10
     /  \
    5    15
        /  \
       6    20
```

Here `15.left = 6 < 15` (ok by child-local check) but `6 < 10` violates the invariant — 6 is in 10's right subtree, so it must be greater than 10. Child-local comparisons have no knowledge of 10.

### Why "in-order and check sorted" works but is two-pass
You can run in-order traversal, collect values, and verify the list is strictly increasing. That's O(n) time and space and clean to reason about, but it does two passes and it allocates. We'd prefer a single pass that short-circuits on the first violation.

### Bounds-propagating recursion (the canonical solution)
Carry `(lo, hi)` bounds down the recursion. At each node, `lo < node.val < hi` must hold. When descending left, the new upper bound is `node.val`; descending right, the new lower bound is `node.val`.

```python
def isValidBST(root):
    def go(node, lo, hi):
        if node is None: return True
        if not (lo < node.val < hi): return False
        return go(node.left, lo, node.val) and go(node.right, node.val, hi)
    return go(root, float('-inf'), float('inf'))
```

### Trace on the failing tree
Tree:
```
        10
       /  \
      5    15
          /  \
         6    20
```

| call | `node.val` | `(lo, hi)` | `lo < val < hi`? | recurse | result |
|---|---|---|---|---|---|
| `go(10, -inf, +inf)` | 10 | (-∞, +∞) | ✓ | left, right | — |
| `go(5, -inf, 10)` | 5 | (-∞, 10) | ✓ | both None → True | True |
| `go(15, 10, +inf)` | 15 | (10, +∞) | ✓ | left, right | — |
| `go(6, 10, 15)` | 6 | (10, 15) | `10 < 6`? **✗** | — | **False** |
| back up | | | | `15.left` returned False | short-circuit `and` → False |
| back up to root | | | | right returned False | **False** |

Returns `False` as expected. The critical line is `go(6, 10, 15)` — here we've carried the "must be > 10" constraint from the original descent into 15's right subtree. Without bounds propagation, this check is impossible.

### Trace on a valid tree
```
        10
       /  \
      5    15
          /  \
         12   20
```

| call | `val` | `(lo, hi)` | valid? |
|---|---|---|---|
| `go(10, -∞, +∞)` | 10 | (-∞, +∞) | ✓ |
| `go(5, -∞, 10)` | 5 | (-∞, 10) | ✓ |
| `go(15, 10, +∞)` | 15 | (10, +∞) | ✓ |
| `go(12, 10, 15)` | 12 | (10, 15) | ✓ |
| `go(20, 15, +∞)` | 20 | (15, +∞) | ✓ |

All leaves and Nones return True → root returns True.

### Equivalent: in-order with a running predecessor
Single-pass without bounds; keep the last value visited and check strictly increasing.

```python
def isValidBST(root):
    prev = [None]                         # mutable reference via list
    def inorder(node):
        if node is None: return True
        if not inorder(node.left): return False
        if prev[0] is not None and node.val <= prev[0]:
            return False
        prev[0] = node.val
        return inorder(node.right)
    return inorder(root)
```

Same `O(n)` time, `O(h)` stack. Both solutions are canonical; the bounds approach generalises to problems where you need to *carry* information (e.g. range queries), while the in-order approach generalises to anything exploiting sorted order (LC 99 recover, LC 230 kth smallest).

### Complexity
Time `O(n)` — every node visited once. Space `O(h)` for the recursion stack. The short-circuit `and` means violations terminate early, but the worst case is still `O(n)` (perfectly valid BST).

### Takeaway
The bounds-propagation trick — "push constraints down the recursion" — appears in many problems beyond BST: range DP, constraint satisfaction, segment-tree queries. The discipline of explicitly naming the invariant `(lo, hi)` at each recursive call is what makes subtle tree problems tractable.

## 6. Common Variations

### Core operations
- **Search** (LC 700): Template A.
- **Insert** (LC 701): Template B.
- **Delete** (LC 450): Template C — the "two-child" successor-swap case is the tricky one.
- **Validate BST** (LC 98): Template D.
- **LCA** (LC 235): Template H — descend while both targets share the same side.

### In-order exploitation
- **Kth smallest** (LC 230): Template E.
- **BST iterator** (LC 173): Template E class form with `_push_left` helper.
- **Recover BST** (LC 99): in-order finds the two swapped nodes — they are the **two descents** in the otherwise-sorted sequence.
- **Minimum absolute difference in BST** (LC 530, LC 783): in-order; track `prev` and compute `val - prev`.
- **Two sum in BST** (LC 653): two iterators (forward and reverse) converging like sorted two-pointer.
- **Inorder successor in BST** (LC 285, LC 510): specialised descent.

### Range / pruning queries
- **Range sum of BST** (LC 938): Template F — prune subtrees out of range.
- **Trim BST** (LC 669): Template F trim variant.
- **Closest BST value** (LC 270): descend while tracking `best = min(best, |val - target|)`.
- **Closest K values** (LC 272): in-order with a sliding window of size k, or two iterators (predecessor + successor).

### Construction
- **Sorted array → BST** (LC 108): Template G — mid-picking keeps it balanced.
- **Sorted list → BST** (LC 109): in-order simulation — recurse on counts, consume the list pointer in order.
- **Build BST from preorder** (LC 1008): insert each element, or use bounds-propagation construction.
- **Unique BSTs** (LC 96 count, LC 95 enumerate): Catalan number; recursion over root choice.

### Augmented BST
- **Count smaller numbers after self** (LC 315): each node augmented with `left_subtree_size`; insert right-to-left, accumulating left counts at each descent.
- **Reverse pairs / count inversions**: merge sort or segment tree are usually simpler; augmented BST works but needs balancing.

### Self-balancing BSTs (interview-adjacent)
- **AVL tree**: rotate to maintain `|height_left − height_right| ≤ 1`.
- **Red-Black tree**: used by `std::map`, Java `TreeMap`, Python's `sortedcontainers.SortedList` (actually a skip-list-ish structure).
- **Treap**: BST + heap on random priorities; expected balanced.
- **Splay tree**: amortised `O(log n)` with locality.

Interviews rarely ask you to implement these from scratch; they ask whether you know why vanilla BST can be `O(n)` and how balanced variants avoid it.

### Edge cases & pitfalls
- **Empty tree** — most templates return a sentinel (None / 0 / -1 / True). Always handle explicitly.
- **Duplicates policy** — `<` vs `<=` in inserts. State it up front.
- **Skewed trees** — insert from a sorted input without balancing → `O(n)` per op. If you want guarantees, use a balanced BST.
- **Incorrect validation** — comparing only to immediate children, or using `<=` where `<` is required.
- **Losing the root** — Templates B/C/F must return the (possibly new) root; the caller must do `root = insert(root, x)`.
- **Stack overflow on deep recursion** — Python's default limit is 1000. For competitive inputs, iterate or bump the limit.
- **Integer overflow for bounds** — Python is fine; in Java/C++ use `Long.MIN_VALUE` / `LONG_MIN` for initial bounds.
- **Deletion does not rebalance** — vanilla BST delete preserves the BST invariant but not balance; repeated deletes can degrade the shape.

## 7. Related Patterns
- **Tree DFS** — the *mechanic*; BST adds ordering invariants.
- **Binary Search** — BST's decision procedure is a binary search over tree paths; every comparison halves the search region on average.
- **Sorted Array** — a BST is the dynamic version of a sorted array; pick whichever matches update frequency.
- **Heap** — maintains the *min/max* only; BST maintains *all* orderings. Heap is faster and simpler for top-k; BST is the right choice for rank / select / range queries.
- **Trie** — another tree that indexes by key; trie partitions by character, BST partitions by comparison.
- **Segment Tree / Fenwick Tree (BIT)** — alternative range-query structures over a fixed index space; usually preferred over augmented BST when the universe is known up front.
- **Sorted Containers / Order Statistic Tree** — in competitive programming, `sortedcontainers.SortedList` (Python) or policy trees (C++) replace a hand-rolled balanced BST.

**Distinguishing note**: if you would use a sorted array for "rank / count / closest" but the data changes online, reach for a BST (or balanced tree). If you only need "min / max / top-k", reach for a heap — it is strictly smaller/faster for that narrower job. If the universe of keys is known in advance and bounded, a Fenwick tree or segment tree often beats the BST both in constant factors and in cache behaviour. Use a BST when the input is dynamic, the universe is unbounded or unknown, and you need the full ordering machinery.
