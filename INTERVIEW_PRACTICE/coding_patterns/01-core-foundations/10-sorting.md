# 10 — Sorting

## 1. When to Use
- Order matters for a later step: **two pointers**, **binary search**, **greedy**, **grouping identical items**, **interval sweep**.
- Keywords: *"intervals"*, *"meetings"*, *"k closest"*, *"arrange / reorder"*, *"by this key"*, *"merge"*, *"smallest/largest k"*, *"earliest deadline"*, *"custom order"*, *"anagrams grouped together"*.
- You are told comparisons are valid and keys are orderable (numbers, strings, tuples, or custom comparator).
- A one-time `O(n log n)` sort unlocks a subsequent `O(n)` scan, beating the `O(n^2)` brute force.
- You need a **stable** arrangement (Python's `sorted` / `list.sort` are stable — equal keys preserve relative order).
- You need to **canonicalise** data: sort each string's characters to group anagrams, sort each tuple to group permutations.
- You need **top-k** or **kth element** — full sort works; heap or quickselect may be faster.
- Values are small bounded integers — counting/radix sort runs in linear time.
- You need to find pairs/triplets with a property — sorting enables two-pointer / binary-search follow-ups.

## 2. Core Idea
Sorting turns a shapeless input into a structured one so hidden relationships become **positional**: adjacency, monotonicity, or grouping. Once the data is ordered by the right key, the remaining work is often a linear sweep or a binary search, which is why "sort first, then walk" is one of the most reused skeletons in interview problems. A carefully chosen sort key is typically the hardest (and most creative) part — once the order is right, the rest writes itself.

Sorting is also a canonicalisation primitive: two structurally-equivalent inputs hash/compare equal after sorting (anagrams, permutations, bag-of-words). When hashing is awkward, sorting is the fallback.

## 3. Template

### Sort by key (most interview uses)
```python
items.sort(key=lambda x: x.priority)              # ascending. GOTCHA: .sort() returns None — chain on `sorted()` instead
items.sort(key=lambda x: -x.age)                  # descending via negation. Only works for numeric keys
items.sort(key=lambda x: (x.priority, -x.age))    # tuple key: compare priority first, then -age. Ties broken left-to-right
# For non-numeric reverse, use reverse=True (e.g. items.sort(key=str, reverse=True))
```

### Sort-then-sweep skeleton
```python
def sweep(items):
    items.sort(key=lambda x: x.start)             # dominant preprocessing. GOTCHA: mutates caller's list in place
    prev = None                                    # GOTCHA: `is not None` (not `if prev:`) — empty/zero-valued objects are falsy
    out = []
    for x in items:
        if prev is not None and overlaps(prev, x):    # AND short-circuits: `overlaps` never sees None
            prev = merge(prev, x)
        else:
            if prev is not None: out.append(prev)
            prev = x
    if prev is not None: out.append(prev)          # GOTCHA: don't forget the final flush after the loop
    return out
```

### Counting sort (bounded integer range)
```python
def count_sort(arr, lo_val, hi_val):
    V = hi_val - lo_val + 1                        # GOTCHA: +1 because range is inclusive on both ends
    buckets = [0] * V                              # `[0]*V` safe (ints are immutable). Never `[[0]]*V` — shared rows!
    for x in arr: buckets[x - lo_val] += 1         # offset so lo_val maps to index 0
    out = []
    for v, c in enumerate(buckets):
        out.extend([v + lo_val] * c)               # `list * c` repeats; `extend` avoids O(n) reallocs vs `+=`
    return out
```

### Custom comparator via cmp_to_key
```python
from functools import cmp_to_key                   # GOTCHA: Python 3 dropped `cmp=`; must wrap with cmp_to_key

def compare(a, b):
    # Return <0 if a before b, 0 if equal, >0 if a after b (C-style, NOT bool)
    if a + b > b + a: return -1                    # returning True/False here silently breaks sort (True==1, False==0)
    elif a + b < b + a: return 1
    return 0                                        # must return 0 for equals — else sort may be unstable/incorrect

items.sort(key=cmp_to_key(compare))                 # slower than key=lambda because each compare is a Python call
```

### Bucket sort (distribute into bins, sort each bin)
```python
def bucket_sort(arr, num_buckets):
    lo, hi = min(arr), max(arr)                    # GOTCHA: min/max on empty arr → ValueError; guard upstream
    size = (hi - lo) / num_buckets + 1e-9          # +epsilon so max value doesn't land at index==num_buckets
    buckets = [[] for _ in range(num_buckets)]     # list comprehension — NEVER `[[]]*n` (shared inner list!)
    for x in arr:
        buckets[int((x - lo) / size)].append(x)    # int() truncates toward zero (floor for non-negatives)
    out = []
    for b in buckets:
        b.sort(); out.extend(b)                    # semicolon is legal but stylistically unusual in Python
    return out
```

### Top-k / kth via heap (partial sort)
```python
import heapq
k_largest = heapq.nlargest(k, arr)                # O(n log k). GOTCHA: k >= n just returns sorted(arr, reverse=True)
k_smallest = heapq.nsmallest(k, arr)              # returns a LIST (not a heap); already sorted
# For objects: heapq.nlargest(k, arr, key=lambda x: x.score)  — key only applied once per item (cached)
```

### Stable sort guarantee
```python
# Python: .sort() and sorted() are stable (Timsort). GOTCHA: NOT guaranteed in C++ std::sort, use stable_sort.
# You can layer sorts: sort by secondary first, then by primary.
items.sort(key=lambda x: x.secondary)             # must apply LEAST-significant key first
items.sort(key=lambda x: x.primary)               # primary wins; secondary breaks ties (only works because stable)
```

Key mental tools:
- Python `sort` / `sorted` is **Timsort**: `O(n log n)` worst, `O(n)` best on partially sorted, **stable**.
- Sort by a **composite tuple** when tie-breaking matters: `key=(primary, -secondary, tertiary)`.
- For descending sort on a **non-numeric** field where `-` doesn't work, do `sort(key=..., reverse=True)` or sort twice (stability preserves secondary).
- Sorting does not preserve original indices — save `enumerate(arr)` first if you need them.
- For small bounded domains, **counting sort** is linear.

## 4. Classic Problems
- **LC 56 — Merge Intervals** (Medium): sort by start, sweep.
- **LC 252 / 253 — Meeting Rooms I / II** (Easy/Medium): sort endpoints or start+heap.
- **LC 179 — Largest Number** (Medium): custom comparator `a+b vs b+a`.
- **LC 75 — Sort Colors** (Medium): Dutch National Flag (3-way partition), counting sort alternative.
- **LC 147 — Insertion Sort List** (Medium): algorithmic, not just `.sort()`.

## 5. Worked Example — Largest Number (LC 179)
Problem: given non-negative integers, arrange them to form the largest possible number.

Input: `nums = [3, 30, 34, 5, 9]`. Expected: `"9534330"`.

### Step 1. Why natural sort fails
Sorting descending by numeric value gives `[34, 30, 9, 5, 3]` → `"3430953"`. Wrong — `9` should come before `34` because `9` is a larger first digit.

Sorting descending by **string** gives `["9", "5", "34", "30", "3"]` → `"9534303"`. Still wrong on the tail: `"303"` vs `"330"` — the latter is larger, so `30` should come **after** `3`.

The correct question for any pair `(a, b)`: which order produces a larger concatenation, `a+b` or `b+a`? Sort `a` before `b` iff `a+b > b+a`. This is a **well-defined total order** (you can check transitivity: if `a+b > b+a` and `b+c > c+b`, then `a+c > c+a`). So it is safe to use as a sort key.

### Step 2. Implementation

```python
from functools import cmp_to_key

def largestNumber(nums):
    strs = list(map(str, nums))           # GOTCHA: map() returns an iterator in Py3 — wrap with list() to sort
    def cmp(a, b):
        if a + b > b + a: return -1       # a should come first (descending: smaller return → earlier position)
        elif a + b < b + a: return 1
        return 0                           # must return 0 on equal — omitting falls through to None → TypeError
    strs.sort(key=cmp_to_key(cmp))
    result = "".join(strs)                # "".join — empty separator; joining a list of strs (not ints!)
    return "0" if result[0] == "0" else result   # handle all-zero input. ternary: `x if cond else y`
```

### Step 3. Trace on `nums = [3, 30, 34, 5, 9]`

Convert: `strs = ["3", "30", "34", "5", "9"]`.

Pairwise comparisons during sort:

| `a` | `b` | `a+b` | `b+a` | order |
|---|---|---|---|---|
| 3 | 30 | "330" | "303" | 3 before 30 (330 > 303) |
| 3 | 34 | "334" | "343" | 34 before 3 (343 > 334) |
| 3 | 5 | "35" | "53" | 5 before 3 |
| 3 | 9 | "39" | "93" | 9 before 3 |
| 30 | 34 | "3034" | "3430" | 34 before 30 |
| 30 | 5 | "305" | "530" | 5 before 30 |
| 30 | 9 | "309" | "930" | 9 before 30 |
| 34 | 5 | "345" | "534" | 5 before 34 |
| 34 | 9 | "349" | "934" | 9 before 34 |
| 5 | 9 | "59" | "95" | 9 before 5 |

After sorting descending by this relation: `["9", "5", "34", "3", "30"]`.

Join: `"9" + "5" + "34" + "3" + "30" = "9534330"`. ✓

### Step 4. Edge cases
- **All zeros**: `nums = [0, 0]` → sorted `["0", "0"]` → `"00"` → first char is `0` → return `"0"`.
- **Single element**: trivial — return `str(nums[0])`.
- **Duplicates**: the comparator handles equals correctly (returns 0, stable order preserved).

Time `O(n log n · L)` where `L` is max string length (each comparison is `O(L)`). Space `O(n · L)` for the string copies. Contrast with trying to sort numerically — no numeric comparator produces the right order.

## 6. Common Variations

### Sort-then-sweep (intervals)
- **Merge intervals** (LC 56): sort by start, merge adjacent overlaps.
- **Insert interval** (LC 57): like LC 56 but with one insertion.
- **Non-overlapping intervals** (LC 435): sort by end, greedy keep earliest-finishing.
- **Minimum arrows to burst balloons** (LC 452): same as LC 435.
- **Meeting rooms II** (LC 253): sort starts, min-heap of ends; or sweep-line.
- **Interval list intersections** (LC 986): two-pointer merge on two sorted lists.

### Sort by custom key / comparator
- **Largest number** (LC 179): compare `a+b vs b+a`.
- **Sort array by parity** (LC 905, LC 922): partition or key function.
- **Reorder array by some priority**: `key = (group, -value)`.
- **Custom sort order** (LC 791): dictionary-order defined by another string; `key = order_dict[c]`.

### Sort to group / canonicalise
- **Group anagrams** (LC 49): `key = tuple(sorted(s))` or 26-tuple.
- **Find all anagrams** (LC 438): sliding window instead, but insight is the same.
- **Contains duplicate III** (LC 220): sort + sliding window; or bucket.

### Sort + two pointers / binary search
- **Two / three / four sum** (LC 15, LC 18): sort + two pointers.
- **Container with most water** (LC 11): no sort needed, but a cousin.
- **Kth smallest pair distance** (LC 719): sort + binary search on distance.
- **Count of smaller numbers after self** (LC 315): mergesort with count, or BIT.

### Partial sort (top-k, kth element)
- **Top-k frequent** (LC 347): heap of size k.
- **Kth largest** (LC 215): heap or quickselect.
- **K closest points to origin** (LC 973): heap of size k.
- **K closest elements** (LC 658): binary search + two pointers.

### Non-comparison sorts (linear time)
- **Counting sort**: integers in `[0, V)` → `O(n + V)`.
- **Radix sort**: integers / fixed-length strings → `O(nd)` for `d` digits.
- **Bucket sort**: uniformly distributed reals → `O(n)` expected.
- **LC 164 — Maximum Gap**: bucket sort to find max gap in `O(n)`.
- **LC 75 — Sort Colors**: 3-way partition, one pass.

### Algorithmic sorts (when library sort is disallowed)
- **Merge sort**: `O(n log n)` stable; natural for linked lists (LC 148).
- **Quicksort**: `O(n log n)` expected, `O(n^2)` worst; not stable; in-place.
- **Heapsort**: `O(n log n)` guaranteed, not stable; in-place.
- **Insertion sort**: `O(n^2)` worst, `O(n)` on nearly sorted; good for small arrays.
- **Timsort**: Python / Java default; hybrid of merge + insertion sort.

### Stability-dependent problems
- **Sort by grade keeping submission order within grade**: need stability.
- **Multi-key sort via successive passes**: only works because stable.
- **Inversions counting** (LC 493): merge sort variant; not a stability issue per se, but mergesort's structure gives it for free.

### Sort in 2D / with index preservation
- **Sort by key while remembering original index**: `list(enumerate(arr))` → `sort(key=lambda t: t[1])`.
- **Sort matrix rows / columns individually**: `sorted(row) for row in mat`.
- **Sort by column sum / row sum**: key function over the aggregate.

### Edge cases & pitfalls
- **Empty / single-element** input: sorting is a no-op.
- **Ties**: specify tie-breaks via composite key; otherwise rely on stability.
- **Sort large dataset**: in-place `list.sort()` avoids copying.
- **Sort custom objects**: implement `__lt__`, or sort by `key=...`.
- **Never sort inside a loop** that is already inside another loop — that is `O(n^2 log n)`.
- **String vs numeric order**: `"10" < "9"` in string order.
- **Locale-aware sort** on Unicode — use `locale` module or `unicodedata`.
- **Sorting a generator** — must be materialised first (`sorted(gen)` returns a list).

## 7. Related Patterns
- **Two Pointers / Sliding Window** — the usual `O(n)` follow-up pass after sorting.
- **Binary Search** — another `O(log n)` follow-up on sorted arrays, including "binary search on answer".
- **Greedy** — many greedy proofs require the input sorted by the greedy key (earliest-deadline, shortest-job, edge-weight).
- **Heap / Priority Queue** — streaming version of sorting when you only need top-k or a priority order.
- **Union Find** — Kruskal's MST sorts edges by weight, then unions.
- **Bucket / Counting Sort** — domain-aware linear-time alternatives to comparison sort.
- **Hashing** — competing canonicalisation technique; hash to group vs sort to group.
- **Merge Sort** — natural for linked lists, counting inversions, external sorting.
- **Quickselect** — `O(n)` expected kth element without full sort.

**Distinguishing note**: if your brute force smells `O(n^2)` because it compares all pairs, sort first and ask *"does adjacency in sorted order carry the information I need?"* If yes, you just dropped a factor of `n / log n`. If the problem gives you a **stream** rather than a static array, prefer a heap over a full sort. If the values are small bounded integers, prefer counting / radix sort over comparison sort.
