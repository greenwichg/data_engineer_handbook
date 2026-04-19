# 03 — Arrays

## 1. When to Use
- Input is a **list/vector of comparable items** where **order matters**: `nums`, `heights`, `prices`, `intervals`, `grid[i]`.
- You need **index-based access**, traversal, or in-place rearrangement.
- Keywords: *"rotate"*, *"reverse"*, *"in-place"*, *"kth"*, *"subarray"*, *"prefix"*, *"index"*, *"contiguous"*, *"rearrange"*.
- Constraints mention contiguous storage, `O(1)` random access, or ask you to *"do it without extra space"* / *"O(1) extra memory"*.
- You know the size up front (or a tight upper bound) — arrays beat linked lists for random access and cache locality.
- 2D grids / matrices: everything applies by indexing `[row][col]` or flattening to `row * cols + col`.
- Problems stated with "array" but the real pattern is hidden: two pointers, sliding window, prefix sum, index-as-hash.

## 2. Core Idea
An array is a contiguous block of memory offering `O(1)` index access and `O(n)` insert/delete in the middle. Most "array patterns" exploit that cheap indexing to coordinate multiple positions simultaneously (two pointers, sliding window, prefix sums) or to **re-order data so a hidden structure becomes a linear sweep**. The mental model: you hold one or two fingers on the array, slide them deliberately, and maintain a tiny aggregate (`sum`, `best`, `count`, `last_seen`) as they move.

In-place manipulation leans on two primitives: **swap** (constant work, no shifts) and **write-pointer filtering** (read all elements, write only those you keep). These two cover remove-duplicates, move-zeroes, partition, reverse, and 3-way partition.

## 3. Template

### One-pass scan with running aggregate
```python
def one_pass(arr):
    n = len(arr)
    if n == 0: return None                       # GOTCHA: arr[0] would IndexError on empty input
    running = arr[0]                             # seed with first element so combine sees a real value
    for i in range(1, n):                        # start at 1 because arr[0] is already in `running`
        running = combine(running, arr[i])       # e.g. running = max(running, arr[i])
    return running
```

### Two-pointer in-place filter (read/write pointers)
```python
def filter_in_place(arr, keep):
    write = 0                                # next slot to write a kept element
    for read in range(len(arr)):             # `read` always advances; `write` advances only on a keep
        if keep(arr[read]):
            arr[write] = arr[read]           # safe: write <= read, so we never overwrite an unread element
            write += 1
    return write                             # arr[:write] is the kept prefix; arr[write:] is garbage
```

### Reverse in place
```python
def reverse_in_place(arr, lo=0, hi=None):
    if hi is None: hi = len(arr) - 1         # GOTCHA: never use `hi=len(arr)-1` in the def line — defaults are evaluated ONCE at import
    while lo < hi:                            # strict `<`: when lo == hi we'd swap an element with itself (harmless but pointless)
        arr[lo], arr[hi] = arr[hi], arr[lo]   # tuple swap — no temp variable needed in Python
        lo += 1; hi -= 1                      # `;` lets us put two statements on one line (use sparingly)
```

### Cyclic rotation via three reverses (the k-rotation trick)
```python
def rotate(arr, k):
    n = len(arr); k %= n                     # GOTCHA: k may exceed n; `k %= n` normalises (also handles k = 0 correctly)
    reverse_in_place(arr, 0, n - 1)          # 1) reverse whole array
    reverse_in_place(arr, 0, k - 1)          # 2) reverse first k (the new front)
    reverse_in_place(arr, k, n - 1)          # 3) reverse rest. Three reverses == one rotation, O(1) extra memory
```

### Dutch National Flag — 3-way partition in one pass
```python
def dutch_flag(arr, pivot):
    lo, mid, hi = 0, 0, len(arr) - 1         # tuple unpacking initialises three vars in one line
    while mid <= hi:                          # `<=`: must process the element AT hi too
        if arr[mid] < pivot:
            arr[lo], arr[mid] = arr[mid], arr[lo]; lo += 1; mid += 1   # safe to advance both — swapped value is always 1 (already classified)
        elif arr[mid] > pivot:
            arr[mid], arr[hi] = arr[hi], arr[mid]; hi -= 1             # KEY: do NOT advance mid — the swapped-in value is still unclassified
        else:
            mid += 1                          # value == pivot; already in middle region
```

### Index-as-hash (values in `1..n` → place at `arr[i-1]`)
```python
def first_missing_positive(arr):
    n = len(arr)
    for i in range(n):
        # `while` (not `if`): one swap may bring in another out-of-place value that ALSO needs swapping
        while 1 <= arr[i] <= n and arr[arr[i] - 1] != arr[i]:   # second condition prevents infinite loop on duplicates
            # GOTCHA: order matters! Python evaluates RHS fully before assigning. If we wrote
            #   arr[i], arr[arr[i]-1] = arr[arr[i]-1], arr[i]
            # then the SECOND target `arr[arr[i]-1]` would re-read the just-changed arr[i] → wrong index.
            arr[arr[i] - 1], arr[i] = arr[i], arr[arr[i] - 1]
    for i in range(n):
        if arr[i] != i + 1: return i + 1     # first slot whose value doesn't match position+1
    return n + 1                              # all 1..n present; answer is n+1
```

Key mental tools:
- Guard `n == 0` and `n == 1` up front; most bugs live in empty-array edge cases.
- Prefer **swap, do not shift**: popping from the middle is `O(n)`; swapping is `O(1)`.
- Use `enumerate` when you need both index and value; use slice assignment `arr[a:b] = ...` when you really mean "replace a slice".
- When the values are bounded by `n`, the array itself can serve as a frequency/presence map.

## 4. Classic Problems
- **LC 26 — Remove Duplicates from Sorted Array** (Easy): read/write two pointers.
- **LC 189 — Rotate Array** (Medium): three-reverse trick for `O(1)` space.
- **LC 238 — Product of Array Except Self** (Medium): prefix + suffix passes.
- **LC 75 — Sort Colors** (Medium): Dutch National Flag.
- **LC 41 — First Missing Positive** (Hard): index-as-hash in place, `O(n)` / `O(1)`.

## 5. Worked Example — Dutch National Flag (LC 75 Sort Colors)
Problem: given `nums` of `0`s, `1`s, `2`s, sort in place in one pass with `O(1)` extra space.

Input: `nums = [2, 0, 2, 1, 1, 0]`.

Invariant: three pointers partition the array into four regions.

```
[ 0 .. lo-1 ]  [ lo .. mid-1 ]  [ mid .. hi ]  [ hi+1 .. n-1 ]
     0s              1s            unknown           2s
```

- `arr[mid] == 0` → swap into the `0`-region, advance `lo` and `mid`.
- `arr[mid] == 1` → already correct, advance `mid`.
- `arr[mid] == 2` → swap into the `2`-region, shrink `hi` (do **not** advance `mid` — the swapped-in element is still unknown).

```python
def sortColors(arr):
    lo, mid, hi = 0, 0, len(arr) - 1         # lo: end of 0-region; mid: scanner; hi: start of 2-region
    while mid <= hi:                          # `<=` because element AT hi is still unclassified
        v = arr[mid]                          # snapshot; arr[mid] might be mutated by the swap below
        if v == 0:
            arr[lo], arr[mid] = arr[mid], arr[lo]
            lo += 1; mid += 1                 # swap brings in a 1 from middle region (already-scanned), safe to advance mid
        elif v == 2:
            arr[mid], arr[hi] = arr[hi], arr[mid]
            hi -= 1                           # KEY: do NOT advance mid — incoming value is unscanned, must re-examine next loop
        else:  # v == 1
            mid += 1
```

Step-by-step on `[2, 0, 2, 1, 1, 0]`:

| step | `lo` | `mid` | `hi` | `arr[mid]` | action | array after |
|---|---|---|---|---|---|---|
| start | 0 | 0 | 5 | 2 | swap(mid, hi); hi-- | `[0, 0, 2, 1, 1, 2]` |
| 1 | 0 | 0 | 4 | 0 | swap(lo, mid); lo++, mid++ | `[0, 0, 2, 1, 1, 2]` |
| 2 | 1 | 1 | 4 | 0 | swap(lo, mid); lo++, mid++ | `[0, 0, 2, 1, 1, 2]` |
| 3 | 2 | 2 | 4 | 2 | swap(mid, hi); hi-- | `[0, 0, 1, 1, 2, 2]` |
| 4 | 2 | 2 | 3 | 1 | mid++ | `[0, 0, 1, 1, 2, 2]` |
| 5 | 2 | 3 | 3 | 1 | mid++ | `[0, 0, 1, 1, 2, 2]` |
| stop | 2 | 4 | 3 | — | `mid > hi` | `[0, 0, 1, 1, 2, 2]` |

Final `[0, 0, 1, 1, 2, 2]`. Time `O(n)`, space `O(1)`, exactly one pass. Why three pointers: once a `2` arrives from the right via swap, we *re-examine* it (by not advancing `mid`), which is what keeps the unknown region well-defined.

### A quick in-place variant — remove duplicates from sorted array (LC 26)
Input: `nums = [1, 1, 2, 2, 2, 3, 4, 4, 5]`.

```python
write = 1                                    # nums[0] is always kept (the first occurrence)
for read in range(1, len(nums)):             # start at 1 because we compare with read-1
    if nums[read] != nums[read - 1]:         # input is sorted ⇒ duplicates are adjacent
        nums[write] = nums[read]             # safe: write <= read, never overwrites unread element
        write += 1
```

State trace:

| `read` | `nums[read]` | new? | `write` before | action | prefix `nums[:write]` |
|---|---|---|---|---|---|
| 1 | 1 | no | 1 | skip | `[1]` |
| 2 | 2 | yes | 1 | `nums[1]=2`, write=2 | `[1, 2]` |
| 3 | 2 | no | 2 | skip | `[1, 2]` |
| 4 | 2 | no | 2 | skip | `[1, 2]` |
| 5 | 3 | yes | 2 | `nums[2]=3`, write=3 | `[1, 2, 3]` |
| 6 | 4 | yes | 3 | `nums[3]=4`, write=4 | `[1, 2, 3, 4]` |
| 7 | 4 | no | 4 | skip | `[1, 2, 3, 4]` |
| 8 | 5 | yes | 4 | `nums[4]=5`, write=5 | `[1, 2, 3, 4, 5]` |

Return `k = 5`. Time `O(n)`, space `O(1)`. The read/write pointer skeleton generalises to move-zeroes, remove-element, keep-at-most-two.

## 6. Common Variations

### In-place rewrites (same-direction two pointers)
- **Remove duplicates allowing ≤ 2 copies** (LC 80): compare `nums[read]` with `nums[write - 2]`.
- **Move zeroes to end** (LC 283): keep non-zeros via write pointer, then fill the tail with zeros.
- **Remove element equal to val** (LC 27): skip when `nums[read] == val`.

### Partition / 3-way split
- **Dutch flag** (LC 75): 3-way on a pivot value.
- **Quickselect partition**: pivot, low/high swaps, expected `O(n)` kth element.
- **Wiggle sort** (LC 324): 3-way partition around median + interleave.

### Cyclic rotations & reorderings
- **Rotate by `k`** (LC 189): reverse whole, reverse first `k`, reverse rest.
- **Rotate 2D matrix 90°** (LC 48): transpose then reverse rows.
- **Reorder to `a0, b0, a1, b1, ...`**: split in half, interleave.

### Index/value tricks
- **Index-as-hash** (LC 41, LC 448, LC 287): when values live in `1..n`, mark or swap into position.
- **Negate as a visit marker**: negate `arr[abs(x) - 1]` to record presence in `O(1)`.
- **Cyclic sort**: repeatedly swap `arr[i]` with `arr[arr[i] - 1]` until `arr[i] == i + 1`.

### Two-pass aggregates
- **Product except self** (LC 238): left-product pass, right-product pass, combine.
- **Trapping rain water** (LC 42): left-max and right-max arrays; or two-pointer variant.
- **Best time to buy/sell** (LC 121): track running min while computing running max profit.

### Running-state scans
- **Kadane's maximum subarray** (LC 53): `cur = max(x, cur + x)`.
- **Max product subarray** (LC 152): track both max and min (negatives flip sign).
- **Majority element** (LC 169): Boyer-Moore vote counter.

### Matrix / 2D arrays
- **Spiral order** (LC 54): four boundaries shrinking inward.
- **Set matrix zeroes** (LC 73): use first row/column as markers.
- **Search 2D matrix** (LC 240): staircase search from top-right corner.

### Edge cases you must always consider
- empty array, single element, two elements
- all identical values
- already sorted / reverse sorted
- negatives, zeros, or overflow-prone values
- `k == 0`, `k == n`, `k > n` for rotations and windows

## 7. Related Patterns
- **Strings** — strings are arrays of characters; almost every array technique transfers directly.
- **Two Pointers / Sliding Window** — the two dominant ways to turn `O(n^2)` array scans into `O(n)`.
- **Prefix Sum** — precompute once to answer range queries in `O(1)`.
- **Sorting** — the usual preprocessing step that unlocks two-pointer, binary search, or greedy.
- **Hashing** — when order does not matter, a set/map often beats an array scan.
- **Binary Search** — on sorted arrays, or on the **answer** parameter.
- **Heap** — streaming top-k over an array without sorting the rest.

**Distinguishing note**: "arrays" is the **substrate**, not a trick. When a problem is tagged array-only, the real pattern is usually one of: two-pointers, prefix-sum, sorting-then-sweep, sliding-window, or index-as-hash. Ask: *"what invariant do my pointers/aggregates maintain as I scan?"* — the answer names the pattern.
