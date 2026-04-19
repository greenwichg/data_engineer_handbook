# 06 — Two Pointers

## 1. When to Use
- Input is a **sorted array** or becomes sorted after preprocessing.
- You need to find **pairs, triplets, or partitions** that satisfy a condition.
- Keywords: *"pair sum"*, *"triplet"*, *"closest to target"*, *"reverse in place"*, *"partition"*, *"move zeroes"*, *"remove in place"*, *"merge two sorted"*, *"container"*, *"trap water"*.
- You would otherwise write an `O(n^2)` pair-loop — two pointers on a sorted input turns it into `O(n)`.
- Two sequences need to be **walked in lock-step**: merging two sorted arrays, intersection, diff.
- Linked-list problems about **middle node**, **cycle**, **nth-from-end** (slow/fast variant).
- Problem asks for `O(1)` extra space — two pointers beat hashing when memory is constrained.
- In-place mutations where a **read pointer** scans and a **write pointer** records kept elements.

## 2. Core Idea
Two pointers exploit monotonicity: on a sorted array, moving the left pointer right can only *increase* a pair sum; moving the right pointer left can only *decrease* it. That monotone relationship means each step **eliminates an entire row or column** of the hypothetical `O(n^2)` search space, collapsing the work to `O(n)`. The pattern generalises beyond sums: anywhere a predicate is monotone as one endpoint moves, two pointers can exploit it.

Three flavours dominate:
1. **Opposite ends, converging** (`lo → ..., ← hi`) — for sorted-pair-sum, palindrome, container problems.
2. **Same direction, different speeds** (`slow` / `fast`) — for cycle detection, middle-of-list, nth-from-end, duplicate detection.
3. **Same direction, read & write** (`read` scans, `write` records) — for in-place filter, remove duplicates, move zeroes, partition.

## 3. Template

### Variant A — opposite ends, converging (sorted pair-sum)
```python
def pair_sum(arr, target):
    arr.sort()                               # GOTCHA: in-place — mutates caller's list. Use sorted(arr) to keep original.
    lo, hi = 0, len(arr) - 1                 # tuple unpacking initialises both vars
    while lo < hi:                           # strict `<`: at lo == hi we'd be summing one element with itself
        s = arr[lo] + arr[hi]
        if s == target:
            return (lo, hi)
        elif s < target:
            lo += 1                          # need a larger sum — moving lo right gives a bigger arr[lo] (sorted)
        else:
            hi -= 1                          # need a smaller sum — moving hi left gives a smaller arr[hi]
    return None
```

### Variant B — slow / fast (cycle detection, middle)
```python
def has_cycle(head):
    slow = fast = head                       # both bound to the same node initially (chained assignment)
    # `fast and fast.next`: must check fast itself first to avoid AttributeError on None.next
    while fast and fast.next:
        slow = slow.next                     # 1 step
        fast = fast.next.next                # 2 steps — guaranteed safe by the loop guard
        if slow is fast: return True         # `is` checks identity (same object), `==` would be value comparison
    return False

def middle(head):
    slow = fast = head
    while fast and fast.next:
        slow = slow.next
        fast = fast.next.next
    return slow                              # KEY: when len is even, returns the SECOND middle (1->2->3->4 gives 3, not 2)
```

### Variant C — read / write (in-place filter)
```python
def move_non_zero_forward(arr):
    write = 0                                # next slot to place a non-zero
    for read in range(len(arr)):
        if arr[read] != 0:
            arr[write], arr[read] = arr[read], arr[write]   # swap (not just copy) keeps zeros being shoved to the back
            write += 1
    return arr                               # arr[:write] are the non-zeros in original order; arr[write:] are zeros
```

### Variant D — merge two sorted sequences
```python
def merge(a, b):
    i = j = 0
    out = []
    while i < len(a) and j < len(b):
        if a[i] <= b[j]:                     # `<=` (not `<`) keeps the merge STABLE — equal values from `a` come first
            out.append(a[i]); i += 1
        else:
            out.append(b[j]); j += 1
    out.extend(a[i:])                        # whichever loop exited still has tail; extend handles empty slice gracefully
    out.extend(b[j:])                        # exactly one of these will be non-empty
    return out
```

### Variant E — fix-one-scan-two (3Sum skeleton)
```python
def three_sum(arr):
    arr.sort()
    res = []
    n = len(arr)
    for i in range(n - 2):                   # n-2 because we need at least 2 more elements for lo, hi
        if i > 0 and arr[i] == arr[i - 1]: continue   # KEY: dedupe ANCHOR. Skip when same value already used as anchor.
        lo, hi = i + 1, n - 1
        while lo < hi:
            s = arr[i] + arr[lo] + arr[hi]
            if s == 0:
                res.append([arr[i], arr[lo], arr[hi]])
                lo += 1; hi -= 1             # advance both AFTER recording (otherwise infinite loop)
                # KEY: dedupe lo/hi by comparing to PREVIOUS slot (not next) — `arr[lo - 1]` is the value we just used
                while lo < hi and arr[lo] == arr[lo - 1]: lo += 1
                while lo < hi and arr[hi] == arr[hi + 1]: hi -= 1
            elif s < 0:
                lo += 1
            else:
                hi -= 1
    return res
```

Key mental tools:
- **Invariant**: state precisely what is true of `arr[lo..hi]` at every step. Correctness follows from preserving the invariant.
- **Progress**: every iteration must move at least one pointer, or the loop never terminates.
- **Termination**: converging variants end when `lo >= hi`; same-direction variants end when the read pointer exhausts.
- **Dedup**: on sorted inputs, skip when `arr[i] == arr[i-1]` to avoid repeated results (crucial for 3Sum, 4Sum).

## 4. Classic Problems
- **LC 167 — Two Sum II (Sorted)** (Medium): classic converging pointers.
- **LC 15 — 3Sum** (Medium): fix one index, two-pointer the rest.
- **LC 11 — Container With Most Water** (Medium): move the shorter wall.
- **LC 42 — Trapping Rain Water** (Hard): left/right max pointers.
- **LC 283 — Move Zeroes** (Easy): slow/fast in-place rewrite.

## 5. Worked Example — 3Sum (LC 15)
Problem: given `nums`, return all **unique** triplets `(a, b, c)` with `a + b + c = 0`.

Input: `nums = [-1, 0, 1, 2, -1, -4]`.

### Step 1. Sort
Sort to unlock monotonicity and make duplicate-skipping easy: `nums = [-4, -1, -1, 0, 1, 2]`.

### Step 2. Fix one, two-pointer the rest
Iterate `i` from 0 to n-3. For each `i`, two-pointer `lo = i+1`, `hi = n-1` looking for `-nums[i]`. Skip `i` when it matches the previous anchor (`arr[i] == arr[i-1]` with `i > 0`), and after recording a solution skip duplicates at both `lo` and `hi`.

```python
def threeSum(nums):
    nums.sort()
    res = []
    n = len(nums)
    for i in range(n - 2):
        if nums[i] > 0: break                              # OPTIMISATION: smallest is positive ⇒ no triplet sums to 0
        if i > 0 and nums[i] == nums[i - 1]: continue      # dedupe anchor: same anchor value already produced its triplets
        lo, hi = i + 1, n - 1
        target = -nums[i]                                  # need lo + hi == -anchor for total = 0
        while lo < hi:
            s = nums[lo] + nums[hi]
            if s == target:
                res.append([nums[i], nums[lo], nums[hi]])
                lo += 1; hi -= 1                           # MUST advance both — otherwise next iteration finds same triplet
                # Dedupe AFTER moving so we compare to the value we just used (arr[lo-1] / arr[hi+1])
                while lo < hi and nums[lo] == nums[lo - 1]: lo += 1
                while lo < hi and nums[hi] == nums[hi + 1]: hi -= 1
            elif s < target:
                lo += 1                                    # need bigger sum
            else:
                hi -= 1                                    # need smaller sum
    return res
```

### Step 3. Trace
Sorted array: `[-4, -1, -1, 0, 1, 2]` (indices 0..5).

**Anchor `i = 0`, `nums[i] = -4`, target = 4.** `lo = 1`, `hi = 5`:

| `lo` | `hi` | `nums[lo]` | `nums[hi]` | `s = lo + hi` | compare to 4 | action |
|---|---|---|---|---|---|---|
| 1 | 5 | -1 | 2 | 1 | 1 < 4 | `lo++` |
| 2 | 5 | -1 | 2 | 1 | 1 < 4 | `lo++` |
| 3 | 5 | 0 | 2 | 2 | 2 < 4 | `lo++` |
| 4 | 5 | 1 | 2 | 3 | 3 < 4 | `lo++` |
| stop | | | | | `lo == hi` | — |

No triplet for `i = 0`.

**Anchor `i = 1`, `nums[i] = -1`, target = 1.** `lo = 2`, `hi = 5`:

| `lo` | `hi` | `nums[lo]` | `nums[hi]` | `s` | compare to 1 | action | record |
|---|---|---|---|---|---|---|---|
| 2 | 5 | -1 | 2 | 1 | = | record `[-1, -1, 2]`, advance both, skip dups | `[[-1,-1,2]]` |
| 3 | 4 | 0 | 1 | 1 | = | record `[-1, 0, 1]`, advance both | `[[-1,-1,2],[-1,0,1]]` |
| stop | | | | | `lo >= hi` | — | |

**Anchor `i = 2`, `nums[i] = -1`**: duplicate of `i = 1` → skip.

**Anchor `i = 3`, `nums[i] = 0`, target = 0.** `lo = 4`, `hi = 5`:

| `lo` | `hi` | `nums[lo]` | `nums[hi]` | `s` | compare to 0 | action |
|---|---|---|---|---|---|---|
| 4 | 5 | 1 | 2 | 3 | 3 > 0 | `hi--` |
| stop | | | | | `lo == hi` | — |

No triplet.

Final result: `[[-1, -1, 2], [-1, 0, 1]]`. Time `O(n^2)`: outer loop `n`, inner two-pointer `O(n)`. Space `O(1)` apart from output. The dedup skips are what guarantee each triplet is emitted once even when the sorted input has repeated values.

## 6. Common Variations

### Opposite ends, converging (sorted input)
- **Two sum sorted** (LC 167): classic converging pair.
- **Three sum** (LC 15): outer anchor + two pointers.
- **Three sum closest** (LC 16): track best-|diff| as you move.
- **Four sum** (LC 18): two nested anchors + two pointers.
- **Container with most water** (LC 11): move the shorter wall — the **only** correct move.
- **Trapping rain water** (LC 42): track left-max and right-max, move the pointer from the shorter side.
- **Valid palindrome** (LC 125, LC 680): alnum-skip both ends.
- **Is subsequence** (LC 392): advance one pointer on match.

### Same direction, slow/fast (linked lists + arrays)
- **Cycle detection** (LC 141): slow moves 1, fast moves 2.
- **Cycle entry** (LC 142): after meeting, restart one pointer at head, advance together.
- **Middle of linked list** (LC 876).
- **Nth from end** (LC 19): gap of `n` between two pointers.
- **Happy number** (LC 202): cycle detection on the sum-of-squares sequence.
- **Find the duplicate number** (LC 287): Floyd's on `arr[i]` as "next pointer".

### Same direction, read / write (in-place edits)
- **Remove duplicates from sorted** (LC 26): write advances only on new value.
- **Remove element** (LC 27): write skips val.
- **Move zeroes** (LC 283): write advances on non-zero; later fill with zeros or swap.
- **Sort colors / Dutch flag** (LC 75): three pointers for 3-way partition.
- **Partition array** (LC 905, LC 922): even/odd or parity-based.

### Two sequences walked in lock-step
- **Merge two sorted arrays** (LC 88): merge into `a` from the back (known capacity).
- **Merge two sorted linked lists** (LC 21): dummy head + merge.
- **Intersection of two arrays** (LC 349, LC 350): sort + two pointers.
- **Backspace string compare** (LC 844): reverse-scan both strings with skip counters.

### Distance/window variants (two pointers with a gap)
- **Minimum size subarray sum** (LC 209): shrink window while sum ≥ target (sliding window flavour).
- **Longest ones with at most k flips** (LC 1004): same.
- **Longest mountain** (LC 845): expand both directions from peaks.

### Edge cases & pitfalls
- Unsorted input — remember to sort first if values (not indices) matter.
- Duplicate-handling: decide whether the answer should include duplicates and dedup accordingly.
- Integer overflow in sums (Python fine; Java/C++ use `long`).
- `lo < hi` vs `lo <= hi` — off-by-one sinks pair-based algorithms.
- Moving the "wrong" pointer in container/water problems (always move the shorter side).
- Infinite loop when both pointers can stand still — always prove progress.

## 7. Related Patterns
- **Sliding Window** — same-direction two-pointer with explicit window state; most "at-most-k" and "longest with constraint" problems.
- **Binary Search** — single-pointer convergence on a sorted index space; two pointers converge from the outside instead.
- **Sorting** — the near-universal preprocessing step that unlocks two pointers.
- **Hashing** — the alternative when the input is unsorted and sorting would destroy needed index info.
- **Linked List** — slow/fast is a linked-list-specific two-pointer.
- **Arrays** — two pointers are the main in-place mutation primitive.
- **Greedy** — container-with-most-water is a greedy proof: moving the shorter wall is always safe.

**Distinguishing note**: if moving the "wrong" pointer makes the condition **monotonically worse**, you have a two-pointer problem. If the condition depends on a contiguous window's **aggregate**, you have a sliding-window problem. If the condition requires arbitrary lookups over what you have seen, it is hashing, not two pointers.
