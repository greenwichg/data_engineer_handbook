# 07 — Sliding Window

## 1. When to Use
- You are asked about a **contiguous subarray / substring** of an array or string.
- Keywords: *"longest"*, *"shortest"*, *"smallest"*, *"exactly k"*, *"at most k"*, *"at least k"*, *"contains all of"*, *"max sum of size k"*, *"average of last k"*, *"substring with property X"*.
- A brute force would enumerate every `[l..r]` range — `O(n^2)` — and you need `O(n)`.
- The condition is **monotonic** in one direction: once a window becomes invalid by growing (adding an element), it stays invalid until you shrink; once it is valid, shrinking preserves the property until the critical element leaves.
- Window state is **cheap to update on add/remove** (sum, counter, max via monotonic deque, distinct count).
- Fixed window size `k` — slide by one and update in `O(1)`.
- Variable window size — grow on the right, shrink on the left to restore an invariant.
- Streaming data where you only care about a fixed-size recent window.

### Prereq: values must be non-negative for sliding-window sums
If values can be negative, sliding window's "sum only grows" invariant breaks. Use **prefix sum + hashmap** (see file 08) instead.

## 2. Core Idea
A sliding window maintains a contiguous range `[l, r]` and amortises work across overlapping ranges. Instead of recomputing over each `[l..r]` from scratch, you update incrementally: extend `r` to **grow** the window (add an element), advance `l` to **shrink** it (remove an element) until the invariant holds again. Each element enters and leaves the window at most once → `O(n)` total, even though there are two nested loops.

The five ingredients to name explicitly before writing any code:
1. **Window state** — what aggregate do I maintain? (sum, counter, distinct-count, max via deque).
2. **On add** — when `r` advances by one, how does state change?
3. **On remove** — when `l` advances by one, how does state change?
4. **Validity predicate** — given the state, is the window valid?
5. **What do I record** — length, count, sum, or left-boundary of the best window so far?

## 3. Template

### Template A — variable window (shrink-until-valid)
```python
# "Longest/shortest subarray/substring satisfying P"
def variable_window(arr):
    l = 0                                          # left edge (inclusive)
    best = 0 or float('inf')                       # init: 0 for longest (we maximise), inf for shortest (we minimise)
    state = init_state()
    for r, x in enumerate(arr):                    # r is the right edge (inclusive)
        state = add(state, x)                      # (2) on add — extending window by one
        while not is_valid(state):                 # KEY: `while` not `if` — may need to remove multiple elements before valid again
            state = remove(state, arr[l]); l += 1  # (3) on remove — shrinking from the left
        best = better(best, r - l + 1)             # (5) record. Window length = r - l + 1 (both inclusive)
    return best
```

### Template B — fixed size-k window
```python
def max_sum_k(arr, k):
    s = sum(arr[:k])                               # GOTCHA: arr[:k] creates a copy. For huge k, use sum(islice(arr, k)) instead
    best = s                                       # initialise with first window's sum (don't use float('-inf') unless arr could be empty)
    for r in range(k, len(arr)):                   # r starts at k — first NEW right-edge after the initial window
        s += arr[r] - arr[r - k]                   # slide: add new right, drop old left. arr[r-k] is the element falling out
        best = max(best, s)
    return best
```

### Template C — "at most k" count trick
```python
# count subarrays with at most k distinct
def at_most(arr, k):
    from collections import Counter
    cnt = Counter(); l = 0; total = 0              # Counter starts empty; missing keys default to 0 on `+=`
    for r, x in enumerate(arr):
        cnt[x] += 1                                # Counter is dict subclass; missing keys auto-init to 0 BEFORE the +=
        while len(cnt) > k:                        # `len(cnt)` = number of distinct keys with non-zero count (after del below)
            cnt[arr[l]] -= 1
            if cnt[arr[l]] == 0: del cnt[arr[l]]   # KEY: must DELETE zero-count keys; otherwise len(cnt) overcounts distincts
            l += 1
        total += r - l + 1                         # ARITHMETIC TRICK: every valid window of size r-l+1 contributes that many subarrays ending at r
    return total

# exactly k = at_most(k) - at_most(k - 1)         # subtraction trick: "exactly" rarely has a clean direct formula
```

### Template D — max/min over sliding window (monotonic deque)
```python
from collections import deque
def max_sliding_window(arr, k):
    dq = deque()                                    # store INDICES (not values) so we can detect when an index falls out of window
    out = []
    for i, x in enumerate(arr):
        while dq and dq[0] <= i - k:                # evict from FRONT if leftmost index is now outside [i-k+1, i]
            dq.popleft()                            # popleft is O(1) on deque (list.pop(0) is O(n) — never use for queue)
        while dq and arr[dq[-1]] < x:               # KEY: smaller-or-equal old values can never be the max while x is in window — pop them
            dq.pop()                                # pop from BACK
        dq.append(i)
        if i >= k - 1:                              # only start emitting once we've seen k elements
            out.append(arr[dq[0]])                  # front of deque holds the current max's index
    return out
```

### Template E — "covers all" with a need-counter (Minimum Window Substring)
```python
from collections import Counter
def min_window(s, t):
    need = Counter(t)                              # need[c] = how many more of c we still need (positive = still need; negative = surplus)
    missing = len(t)                                # total chars still missing across all keys
    l = 0
    best = (float('inf'), 0, 0)                    # tuple: (length, start, end) — compare by first element
    for r, ch in enumerate(s):
        # KEY: only decrement `missing` when need was POSITIVE — surplus chars don't reduce missing
        if need[ch] > 0: missing -= 1
        need[ch] -= 1                               # may go negative; tracks surplus for later add-back
        while missing == 0:
            if r - l + 1 < best[0]: best = (r - l + 1, l, r)   # record BEFORE shrinking past critical char
            need[s[l]] += 1
            if need[s[l]] > 0: missing += 1         # only re-increment missing when we cross from satisfied (≤0) to needed (>0)
            l += 1
    return "" if best[0] == float('inf') else s[best[1]:best[2] + 1]   # +1: slice end exclusive
```

Key mental tools:
- **Never recompute from scratch**: every element should enter and leave the window once (`O(n)` amortised).
- **Shrink on a `while`, not an `if`**: multiple elements may need to leave before the window becomes valid.
- **State is the part that changes on add/remove**: sum is `O(1)`; Counter is `O(1)` per key; max over window needs a monotonic deque.
- **"Exactly k" trick**: for counting problems, `atMost(k) - atMost(k - 1)`.
- **Fixed vs variable**: fixed-size windows do not need a `while`; they advance both ends together.

## 4. Classic Problems
- **LC 3 — Longest Substring Without Repeating Characters** (Medium): shrink on duplicate.
- **LC 76 — Minimum Window Substring** (Hard): need-counter + missing count.
- **LC 209 — Minimum Size Subarray Sum** (Medium): shrink while sum ≥ target.
- **LC 239 — Sliding Window Maximum** (Hard): monotonic deque of indices.
- **LC 904 — Fruit Into Baskets** (Medium): longest subarray with ≤ 2 distinct.

## 5. Worked Example — Minimum Window Substring (LC 76)
Problem: given `s = "ADOBECODEBANC"`, `t = "ABC"`, find the smallest window of `s` that contains every character of `t` (with multiplicity).

Expected answer: `"BANC"`.

Approach: Template E. `need[c]` tracks how many of `c` the window still needs (negative means surplus). `missing` counts total remaining characters the window needs. The window is valid once `missing == 0`; then shrink from the left to minimise its size.

```python
from collections import Counter

def minWindow(s, t):
    need = Counter(t)                              # need: {A:1, B:1, C:1} for t="ABC"
    missing = len(t)                                # total chars still owed; window valid when this hits 0
    l = 0
    best = (float('inf'), 0, 0)                    # tuple comparison uses first element first → effectively comparing lengths
    for r, ch in enumerate(s):
        if need[ch] > 0: missing -= 1              # only count toward `missing` if this char was still needed
        need[ch] -= 1                               # always decrement; goes negative for surplus chars
        while missing == 0:
            if r - l + 1 < best[0]: best = (r - l + 1, l, r)   # KEY: record BEFORE attempting to remove (next removal may invalidate)
            need[s[l]] += 1
            if need[s[l]] > 0: missing += 1        # only when need crosses 0→positive does the window become invalid
            l += 1
    return "" if best[0] == float('inf') else s[best[1]:best[2] + 1]
```

Step-by-step on `s = "ADOBECODEBANC"` with `t = "ABC"`:

Index layout:
```
 0 1 2 3 4 5 6 7 8 9 10 11 12
 A D O B E C O D E B A  N  C
```

Column key:
- `ch` — `s[r]` just added
- `need` — `{A, B, C}` counts only (others omitted for clarity; negative = surplus)
- `missing` — total needed chars still missing
- `window` — the current `s[l..r]` (before shrinking within this row)
- action after add

| `r` | `ch` | `need{A,B,C}` after add | `missing` | `l` | shrink? | best after |
|---|---|---|---|---|---|---|
| 0 | A | `{A:0, B:1, C:1}` | 2 | 0 | no | — |
| 1 | D | `{A:0, B:1, C:1}` | 2 | 0 | no | — |
| 2 | O | `{A:0, B:1, C:1}` | 2 | 0 | no | — |
| 3 | B | `{A:0, B:0, C:1}` | 1 | 0 | no | — |
| 4 | E | `{A:0, B:0, C:1}` | 1 | 0 | no | — |
| 5 | C | `{A:0, B:0, C:0}` | **0** | 0 | yes | — |
| — | — | — | — | — | record `(6, 0, 5) = "ADOBEC"`, then shrink `l=0` (A leaves → `need.A=1`, missing=1) | best = (6, 0, 5) |
| 6 | O | `{A:1, B:0, C:0}` | 1 | 1 | no | (6, 0, 5) |
| 7 | D | — | 1 | 1 | no | (6, 0, 5) |
| 8 | E | — | 1 | 1 | no | (6, 0, 5) |
| 9 | B | `{A:1, B:-1, C:0}` | 1 | 1 | no | (6, 0, 5) |
| 10 | A | `{A:0, B:-1, C:0}` | **0** | 1 | yes | — |
| — | — | shrink: `s[1]=D` leaves (`need.D→0`, still missing==0), `l=2` | — | 2 | cont. | — |
| — | — | shrink: `s[2]=O` leaves, `l=3` | — | 3 | cont. | — |
| — | — | shrink: `s[3]=B` leaves (`need.B=0`, surplus gone, still missing==0), `l=4` | — | 4 | cont. | — |
| — | — | shrink: `s[4]=E` leaves, `l=5` | — | 5 | cont. | — |
| — | — | at `l=5`, window is `s[5..10]="CODEBA"` length 6, record tied best — keep (6, 0, 5) or update; then `s[5]=C` leaves (`need.C=1`, missing=1), `l=6` | — | 6 | stop | (6, 0, 5) |
| 11 | N | — | 1 | 6 | no | (6, 0, 5) |
| 12 | C | `{A:0, B:-1, C:0}` | **0** | 6 | yes | — |
| — | — | window `s[6..12]="ODEBANC"` length 7 — not better | — | 6 | cont. | (6, 0, 5) |
| — | — | shrink: O leaves, l=7; D leaves, l=8; E leaves, l=9; B leaves (`need.B=0`, surplus gone), l=10; window `s[10..12]="ANC"` length 3 — better → best = (3, 10, 12) | — | 10 | cont. | **(3, 10, 12)** |
| — | — | shrink: `s[10]=A` leaves (`need.A=1`, missing=1), `l=11` | — | 11 | stop | (3, 10, 12) |

Loop ends at `r = 12`. Return `s[10:13] = "ANC"`.

Wait — the expected answer is `"BANC"` (length 4). Let me re-check: `"BANC"` is `s[9..12]`, length 4, which contains A, B, C. But `"ANC"` is `s[10..12]`, length 3 — it contains `A`, `N`, `C` but **no `B`**. So `"ANC"` does NOT cover `t = "ABC"`.

Checking the shrink step where `l` moved past the `B` at index 9: when `s[9] = B` leaves the window, `need[B]` went from `-1` to `0`. Since `0` is not `> 0`, we correctly did **not** increment `missing`. That is because there was still a surplus `B` — wait, but index 9 is the only `B` remaining once index 3's `B` has already left. Let me recheck.

Looking again: at `r = 10`, the window was `s[1..10]`, which contained `B` at index 3 and `B` at index 9. So `need[B]` was `-1` (two `B`s, one needed — surplus of one). When `l` advanced past index 3 (the first `B`), `need[B]` went from `-1` to `0` — still satisfied. Good. At `l = 5`, the window was `s[5..10] = "CODEBA"`, containing exactly one `B` (at index 9). `need[B] = 0`.

Continuing: when `s[5] = C` leaves, `need[C]` goes from `0` to `1`, so `missing` becomes `1`. We stop shrinking at `l = 6`.

At `r = 12`, we add `C`, `missing` returns to 0. Window `s[6..12] = "ODEBANC"`, length 7. We shrink:
- `s[6] = O` leaves, `need[O]` goes negative → `missing` unchanged.
- `s[7] = D` leaves → missing unchanged.
- `s[8] = E` leaves → missing unchanged.
- `s[9] = B` leaves → `need[B]` goes from `0` to `1` → `missing` becomes `1`. Stop.
- Before stopping, we **recorded** the window `s[9..12] = "BANC"`, length `4` as the new best.

So the answer is `"BANC"` (not `"ANC"` — my earlier trace confused the shrink order). Let me fix the trace row:

Correct trace at `r = 12`:

| sub-step | `l` | action | `need.B`, `missing` | window | record? |
|---|---|---|---|---|---|
| enter while | 6 | record `(7, 6, 12)` — worse than (6,0,5), skip | — | `"ODEBANC"` | no |
| remove O | 7 | `need.O` up | still 0 | `"DEBANC"` len 6, equal — skip | no |
| remove D | 8 | similar | still 0 | `"EBANC"` len 5, worse → skip | no |
| remove E | 9 | similar | still 0 | `"BANC"` len 4 | **best = (4, 9, 12)** |
| remove B | 10 | `need.B` 0→1, `missing` 0→1 | 1 | exit while | — |

Return `s[9:13] = "BANC"`. Time `O(|s| + |t|)`: each character enters and leaves the window at most once. Space `O(|Σ|)` for the counter.

The critical lesson: the `while missing == 0` shrink loop **records before each attempted removal**, because a removal may invalidate the window. That ordering is what turns a shrink into a minimum-finder.

## 6. Common Variations

### Variable window, shrink-until-valid
- **Longest substring without repeating** (LC 3): shrink on duplicate.
- **Longest substring with ≤ k distinct** (LC 340): shrink when Counter size > k.
- **Longest substring with ≤ 2 distinct** (LC 159): special case of LC 340.
- **Fruit into baskets** (LC 904): equivalent to LC 159.
- **Longest repeating character replacement** (LC 424): window size − max-char-count ≤ k.
- **Max consecutive ones III** (LC 1004): longest subarray with ≤ k zeros.

### Variable window, shrink-until-target-met
- **Minimum window substring** (LC 76): shrink while `missing == 0`.
- **Smallest window with distinct chars of string** (LC 632-like): similar need-counter.
- **Minimum size subarray sum** (LC 209): shrink while sum ≥ target.

### Fixed size window
- **Maximum average subarray I** (LC 643): compute fixed-k sum; track max.
- **Find all anagrams in a string** (LC 438): fixed-size 26-int compare.
- **Permutation in string** (LC 567): similar to LC 438.
- **Sliding window median** (LC 480): two heaps or SortedList.

### Monotonic deque (sliding extremum)
- **Sliding window maximum** (LC 239).
- **Longest subarray where max − min ≤ limit** (LC 1438): two deques.
- **Shortest subarray with sum ≥ k** (LC 862): deque over prefix sums, supports negatives.
- **Constrained subsequence sum** (LC 1425): DP with monotonic deque.

### Count problems (at-most / exactly)
- **Subarrays with k different integers** (LC 992): `atMost(k) - atMost(k-1)`.
- **Subarrays with k odd numbers** (LC 1248): same trick with odd parity.
- **Binary subarrays with sum k** (LC 930): same trick or prefix sum.
- **Number of substrings containing all three characters** (LC 1358): shrink + count.

### Stream / online
- **Moving average from data stream** (LC 346): fixed-window sum with a `deque`.
- **Logger rate limiter** (LC 359): timestamp window per message.
- **Number of recent calls** (LC 933): timestamp deque with eviction.

### Edge cases & pitfalls
- **Values can be negative** → sliding-window sum breaks; use prefix-sum + hashmap.
- **`k > n`** — handle up front; window cannot exist.
- **Empty input** — early return `""` / `0`.
- Forgetting to record **before** shrinking past the critical element (see worked example).
- Using `if` instead of `while` to shrink (only removes one element; may stay invalid).
- Window state that is expensive to update (avoid `sum(arr[l:r+1])` — that defeats the point).
- Off-by-one on fixed windows: `r - k + 1` vs `r - k`.

## 7. Related Patterns
- **Two Pointers** — sliding window is a same-direction two-pointer with bounded window state.
- **Prefix Sum** — dominant alternative when values can be negative; counts subarrays with a given sum.
- **Hashing** — Counters are the standard window state for alphabet / multiset invariants.
- **Monotonic Deque / Stack** — sliding max/min and sum-at-least-k problems.
- **Binary Search on Answer** — for "is there a window of length L satisfying X?", binary-search `L` and verify with a window pass.
- **Dynamic Programming** — when the problem asks about non-contiguous subsequences, windowing does not apply; switch to DP.

**Distinguishing note**: if the problem is about **contiguous** slices and the aggregate updates in `O(1)` per step, it is sliding window. If the slices may be **non-contiguous** (subsequences), it is DP. If values can be **negative** and you still need contiguous-range sums, it is prefix-sum + hashmap.
