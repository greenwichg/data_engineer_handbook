# 05 — Hashing

## 1. When to Use
- You need **`O(1)` average membership, lookup, or counting**.
- Keywords: *"duplicate"*, *"contains"*, *"seen before"*, *"frequency"*, *"count of"*, *"group by"*, *"complement"*, *"pair that sums to k"*, *"exists index i, j such that..."*.
- You would otherwise write a nested loop comparing every element to every other — hashing is the canonical way to kill the inner loop.
- You need to **group** items by a key derived from each item (sorted chars, modulo class, canonical form, prefix sum).
- Order does not matter for the answer — sets and dicts intentionally drop order.
- You want cheap `"seen(x, at_some_index)"` bookkeeping while scanning.
- You need to **canonicalise** objects (anagrams, isomorphic strings, fractions, 2-tuples) to compare them.
- Prefix-sum problems where "how many subarrays with sum = k" can be answered by counting earlier prefix-sums.

## 2. Core Idea
A hash map trades `O(n)` extra space for `O(1)` average-case lookup, removing the inner loop of a naive pair-search. It also gives you a natural **canonicalisation** primitive: two objects hash to the same bucket iff they share a derived key, which is why anagram grouping, two-sum complements, and "seen-at-index" tricks all collapse to one pass with a dict.

Sets answer *"does X exist?"*. Dicts answer *"what extra info goes with X?"* (index, count, last-seen, running prefix, parent pointer). `defaultdict` removes the `if key not in d: d[key] = ...` boilerplate. `Counter` adds arithmetic on multi-sets for free.

## 3. Template

### Seen-before membership (set)
```python
def has_duplicate(arr):
    seen = set()                              # `set()` — empty set; `{}` is an empty DICT (common beginner trap)
    for x in arr:
        if x in seen: return True             # `in set` is O(1) avg vs `in list` which is O(n)
        seen.add(x)
    return False
```

### Complement lookup (two-sum pattern)
```python
def two_sum(arr, target):
    index_of = {}                            # value -> index we saw it at
    for i, x in enumerate(arr):              # enumerate yields (index, value) pairs — cleaner than range(len(...))
        if target - x in index_of:           # KEY: check BEFORE inserting x, otherwise x might pair with itself when target == 2*x
            return [index_of[target - x], i]
        index_of[x] = i                      # if duplicate values, this overwrites — keeping the LATEST index
    return []
```

### Group by canonical key
```python
from collections import defaultdict
def group_anagrams(strs):
    buckets = defaultdict(list)              # GOTCHA: `defaultdict(list)` auto-creates `[]` on first access — `buckets[key].append` just works
    for s in strs:
        key = tuple(sorted(s))               # `sorted(s)` returns a LIST of chars; tuple() makes it hashable for dict-key use
        buckets[key].append(s)
    return list(buckets.values())            # `.values()` is a view; wrap in list() to materialise
```

### Frequency / top-k
```python
from collections import Counter
def top_k_frequent(nums, k):
    cnt = Counter(nums)                      # Counter is a dict subclass: Counter([1,1,2]) → {1: 2, 2: 1}
    return [v for v, _ in cnt.most_common(k)]   # most_common(k) returns list of (value, count) tuples; `_` discards the count
```

### Prefix-sum + hash (count subarrays with sum = k)
```python
def subarray_sum_equals_k(arr, k):
    cnt = 0
    running = 0
    seen = {0: 1}                            # KEY: seed with prefix-sum 0 occurring once (the empty prefix). Without this, subarrays starting at index 0 with sum=k are missed.
    for x in arr:
        running += x
        cnt += seen.get(running - k, 0)      # `.get(key, 0)` returns 0 if key absent — avoids KeyError
        seen[running] = seen.get(running, 0) + 1   # GOTCHA: must check BEFORE inserting (otherwise zero-sum subarray of length 0 gets counted)
    return cnt
```

### Bijection (two maps enforce one-to-one)
```python
def isomorphic(s, t):
    if len(s) != len(t): return False
    s_to_t, t_to_s = {}, {}                  # need TWO maps: a single map allows two source chars to alias to one target
    for a, b in zip(s, t):                   # zip stops at the shorter sequence — length check above ensures full coverage
        if a in s_to_t and s_to_t[a] != b: return False   # `a` previously mapped to a different `b` ⇒ not a function
        if b in t_to_s and t_to_s[b] != a: return False   # `b` previously came from a different `a` ⇒ not injective
        s_to_t[a] = b; t_to_s[b] = a
    return True
```

### Making unhashable things hashable
```python
# Mutable containers (list, set, dict) can't be dict keys or set elements.
# Convert to their immutable counterpart:
# list     -> tuple
key = tuple(lst)                              # GOTCHA: tuple of lists is still unhashable — must be tuple of immutables all the way down
# set      -> frozenset
key = frozenset(s)                            # frozenset preserves "no order, no duplicates" semantics, IS hashable
# dict     -> tuple of sorted items
key = tuple(sorted(d.items()))                # sorted() ensures dicts equal by content hash to the same key regardless of insertion order
# counter  -> tuple of fixed-size vector
key = tuple(freq_vector)                      # for [0]*26 anagram fingerprints
```

Key mental tools:
- **Set** → existence only.
- **Dict** → existence + payload (index, count, last-seen, parent).
- **defaultdict(list)** → "group by" with no boilerplate.
- **defaultdict(int)** → frequency counter (alias of `Counter` for simple cases).
- **Counter** → frequency + arithmetic (`c1 - c2`, `c1 & c2`, `c1 | c2`).
- Hash keys must be **immutable/hashable**; convert mutable containers first.
- Worst-case `O(n)` per op only under adversarial keys; practical interviews use `O(1)` avg.

## 4. Classic Problems
- **LC 1 — Two Sum** (Easy): complement lookup.
- **LC 217 — Contains Duplicate** (Easy): set of seen values.
- **LC 49 — Group Anagrams** (Medium): bucket by sorted-chars key.
- **LC 128 — Longest Consecutive Sequence** (Medium): set membership → start runs only at sequence heads.
- **LC 560 — Subarray Sum Equals K** (Medium): prefix-sum frequency map.

## 5. Worked Example — Longest Consecutive Sequence (LC 128)
Problem: given `nums = [100, 4, 200, 1, 3, 2]`, find the length of the longest sequence of consecutive integers (order-independent).

Expected answer: `4` (sequence `1, 2, 3, 4`).

**Wrong approach**: sort first — that is `O(n log n)` and the problem asks for `O(n)`.

**Right approach**: put all numbers in a set. Walk the array; only attempt to extend a sequence *starting from `x`* if `x - 1` is **not** in the set — i.e. `x` is the head of a run. Then count upward while `x+1, x+2, ...` are present. Each number is visited at most twice (once when skipped, once when extended), giving `O(n)`.

```python
def longestConsecutive(nums):
    s = set(nums)                            # dedupe AND get O(1) membership in one step
    best = 0
    for x in s:                              # iterating a set is fine; order is insertion-time but irrelevant here
        if x - 1 in s:
            continue                         # KEY: skip non-heads. This is what keeps total work O(n) instead of O(n^2)
        length = 1
        y = x
        while y + 1 in s:                    # walk forward; each value visited at most once across all run-heads
            y += 1
            length += 1
        best = max(best, length)
    return best
```

Trace on `nums = [100, 4, 200, 1, 3, 2]`, `s = {1, 2, 3, 4, 100, 200}`:

| `x` | `x - 1 in s`? | run-head? | walk | length | `best` |
|---|---|---|---|---|---|
| 1 | no (`0` missing) | yes | 1 → 2 → 3 → 4, stop (no 5) | 4 | 4 |
| 2 | yes (`1` in set) | no → skip | — | — | 4 |
| 3 | yes | skip | — | — | 4 |
| 4 | yes | skip | — | — | 4 |
| 100 | no (`99` missing) | yes | 100, stop (no 101) | 1 | 4 |
| 200 | no | yes | 200, stop | 1 | 4 |

Return `4`. Time `O(n)`: each element is either a run head (walked once) or skipped immediately; the while loop inside each run head covers distinct elements totaling at most `n` across the whole algorithm.

Why the `x - 1 in s` guard matters: without it, starting from `4` you would walk only `{4}` (length 1), and starting from `3` you would walk `{3, 4}` (length 2), etc. The guard ensures **each run is walked exactly once**, keeping total work `O(n)`.

## 6. Common Variations

### Existence (set-based)
- **Contains duplicate** (LC 217): return on first repeat.
- **Happy number** (LC 202): set of seen sums to detect cycle.
- **Intersection of two arrays** (LC 349): `set(a) & set(b)`.
- **Longest consecutive sequence** (LC 128): set + run-head guard.

### Count / frequency (dict-based)
- **Valid anagram** (LC 242): Counter equality.
- **Top-k frequent** (LC 347): Counter + heap or bucket sort.
- **First non-repeating char** (LC 387): Counter + second pass.
- **Ransom note** (LC 383): `Counter(magazine) - Counter(ransom)` must be non-negative.

### Complement lookup (dict-indexed)
- **Two sum** (LC 1): target - x.
- **Pairs with k-difference** (LC 532, LC 2006): two-pass or count.
- **Contains duplicate II** (LC 219): last-index map with `i - j <= k` test.
- **Four-sum count** (LC 454): pairwise sum + complement on halves.

### Group by canonical key (defaultdict)
- **Group anagrams** (LC 49): sorted-chars key.
- **Group shifted strings** (LC 249): diff pattern key.
- **Partition strings by first letter**: `key = s[0]`.

### Prefix-sum + hash
- **Subarray sum equals k** (LC 560): map running-sum → count.
- **Contiguous array** (LC 525): map `0→-1`, running balance of +/-1.
- **Subarray sums divisible by k** (LC 974): map running mod k → count.
- **Continuous subarray sum** (LC 523): map mod-k → earliest index.

### Bijection / two-way mapping
- **Isomorphic strings** (LC 205): two dicts.
- **Word pattern** (LC 290): char ↔ word bijection.
- **Palindrome permutation** (LC 266): at most one odd count.

### Bitmask-as-hash-key
- **Find all duplicate DNA sequences** (LC 187): map 10-char substring → count.
- **Longest substring distinct chars** (bounded alphabet): 26-bit mask as integer key.

### Rolling hash
- **Find substring** (Rabin-Karp): `O(n + m)` expected.
- **Repeated DNA sequences** (LC 187): hash each 10-window.
- **Distinct substrings of length k**: set of rolling hashes.

### Edge cases & pitfalls
- Duplicate keys — do you need **first** index or **last** index?
- Negative numbers or zeros affecting modulo keys.
- Mutable values in dicts (fine); mutable *keys* (not fine — use tuples).
- Very large hash keys (e.g. full lists) — cost of hashing dominates; use shorter fingerprints.
- Adversarial inputs causing collisions (rare outside CTFs); use double hashing.
- Dict iteration order is **insertion order** in modern Python — do not rely on sorted order.

## 7. Related Patterns
- **Arrays / Strings** — hashing is the "kill the inner loop" upgrade to brute force.
- **Prefix Sum** — partners with a hash map to count subarrays matching a target.
- **Sliding Window** — frequency maps are the standard window state.
- **Two Pointers** — hashing is the alternative when sorting would lose original indices.
- **Sorting** — another canonicalisation: sort to group, vs hash to group.
- **Union Find** — hash maps are how you convert arbitrary keys into DSU indices.
- **Trie** — hierarchical prefix-grouping; hashing is flat.
- **Binary Search** — uses sorted arrays, hashing uses unsorted; pick by what the input supports.

**Distinguishing note**: reach for a **set** the moment you hear *"duplicate / seen"*; a **dict** the moment you hear *"complement / index / last-seen / count"*; a **defaultdict(list)** the moment you hear *"group by"*. If you also hear *"contiguous"* or *"in the range"*, you probably want prefix-sum + dict, not raw dict.
