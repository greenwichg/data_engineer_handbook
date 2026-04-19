# 11 — Stack

## 1. When to Use
- Input order matters and you need to process the **most recent** item first — **Last In, First Out**.
- Keywords: *"balanced parentheses"*, *"undo"*, *"evaluate expression"*, *"next greater / smaller element"*, *"previous greater / smaller"*, *"remove adjacent duplicates"*, *"simulate recursion"*, *"decode nested"*, *"largest rectangle"*, *"trapping rain water"*, *"asteroid collision"*, *"basic calculator"*.
- You need to **defer** work and revisit items later in reverse order.
- You have a recursive solution and want to convert it to an explicit-stack iterative form (to avoid stack-overflow on deep inputs, or to support resumption/checkpointing).
- The answer at index `i` depends on the **closest previous / next index satisfying a condition** — the canonical monotonic-stack shape.
- You need to implement a **greedy-with-undo**: place elements speculatively, pop them when a better candidate arrives (LC 316 remove duplicate letters, LC 402 remove k digits).
- You need to parse or evaluate a structure with **nested scopes** — expressions, XML, JSON — without building an explicit parse tree.

### Signals that it is NOT a stack problem
- You need the `k`-th most recent element, or random access in the middle → use an array or deque, not a stack.
- You need the minimum/maximum of a sliding window → monotonic **deque**, not monotonic stack (the eviction happens from the front too).
- You need priority (smallest / largest regardless of arrival order) → heap, not stack.

## 2. Core Idea
A stack remembers *contextual history* cheaply: push when you enter a new nested frame, pop when you leave it. Every operation is `O(1)` amortised and touches only the top, so the data structure is "what I'm currently in the middle of".

For "nearest smaller/greater" problems, a **monotonic stack** maintains an invariant — the sequence of values in the stack is strictly increasing or strictly decreasing at all times. Whenever a new element violates the invariant, you pop elements and resolve their answer on the way out. Because every element is pushed once and popped at most once, the total work across all iterations is `O(n)` — not `O(n^2)` as a naive loop would suggest.

The conceptual generalisation: a stack lets you **defer a decision** about an element until a future element arrives that decides its fate. The "fate" is usually "what is the first element to the right that beats me?" — when that element arrives, you resolve the pending answer and discard the deferred state. The same idea shows up in expression parsing (defer operand until operator resolves it), rectangle-in-histogram (defer bar until a shorter bar closes it), and greedy pruning (defer digit until a smaller digit allows removal).

## 3. Template

### Template A — matching / balance (paired brackets)
```python
def is_balanced(s):
    pair = {')': '(', ']': '[', '}': '{'}   # dict literal; values are the matching opener
    stack = []                               # GOTCHA: plain list used as stack; .append/.pop are O(1) amortised
    for ch in s:
        if ch in '([{':                      # `in <string>` does substring membership char-by-char
            stack.append(ch)
        elif ch in ')]}':
            if not stack or stack.pop() != pair[ch]:   # OR short-circuits: .pop() not called on empty stack
                return False                            # GOTCHA: list.pop() on empty raises IndexError — guard first
    return not stack                          # `not stack` is True for empty list (Pythonic emptiness check)
```

### Template B — monotonic stack (next greater / next smaller)
```python
def next_greater(arr):
    """For each i, the next index j > i with arr[j] > arr[i], else -1."""
    n = len(arr)
    out = [-1] * n                          # default -1 for "no next greater" — never overwritten if stack leftover
    stack = []                              # indices; arr[stack] strictly decreasing. GOTCHA: store INDICES not values
    for i, x in enumerate(arr):
        while stack and arr[stack[-1]] < x:    # `while` (not `if`) — may pop multiple. stack[-1] peeks top
            out[stack.pop()] = i            # .pop() removes AND returns; combined lookup+write
        stack.append(i)
    return out                              # indices left in stack get out[j] = -1 (their default)
```

Flip the comparator (`<` → `>`) and/or direction (iterate right-to-left) to get the four variants: next-greater, next-smaller, previous-greater, previous-smaller.

### Template C — expression / RPN evaluation (operand stack)
```python
def eval_rpn(tokens):
    stack = []
    ops = {'+': lambda a, b: a + b,
           '-': lambda a, b: a - b,
           '*': lambda a, b: a * b,
           '/': lambda a, b: int(a / b)}  # GOTCHA: int(a/b) truncates toward 0; a//b floors (differs for negatives!)
    for t in tokens:
        if t in ops:
            b = stack.pop(); a = stack.pop()   # ORDER MATTERS: b first (top), then a. `a-b` not `b-a`
            stack.append(ops[t](a, b))
        else:
            stack.append(int(t))            # int("-3") works; int handles leading minus
    return stack[0]                         # exactly one value remains on well-formed RPN; use stack.pop() defensively
```

### Template D — nested decode / frame stack
```python
def decode_string(s):
    """LC 394: '3[a2[c]]' -> 'accaccacc'."""
    stack = []                            # list of (repeat_count, accumulated_str_before) — tuples are immutable
    cur = ""; k = 0                        # GOTCHA: k aggregates multi-digit numbers like "23" via k*10+digit
    for ch in s:
        if ch.isdigit():
            k = k * 10 + int(ch)           # must handle multi-digit; single int(ch) would lose "23"
        elif ch == '[':
            stack.append((k, cur))         # snapshot context; tuple-packing without parens would also work
            cur, k = "", 0                 # tuple-unpacking assignment resets both simultaneously
        elif ch == ']':
            prev_k, prev_str = stack.pop() # tuple unpacking from popped frame
            cur = prev_str + cur * prev_k  # `str * int` repeats: "ab" * 3 == "ababab"
        else:
            cur += ch                      # GOTCHA: O(n²) for long strings; use list+join in hot paths
    return cur
```

### Template E — greedy with undo (monotonic stack as a deletion tool)
```python
def remove_k_digits(num, k):
    """LC 402: remove k digits to produce the smallest number."""
    stack = []
    for d in num:                                # iterating a str yields chars; '9' > '5' uses lexicographic compare (OK for digits)
        while k and stack and stack[-1] > d:    # `k` truthy == k>0; three conditions via AND short-circuit
            stack.pop(); k -= 1
        stack.append(d)
    stack = stack[:len(stack) - k]               # slice end-exclusive; negative result OK but len-k always >=0 here
    return "".join(stack).lstrip("0") or "0"    # `or "0"` handles empty/all-zero result (empty str is falsy)
```

### Template F — iterative DFS via explicit stack
```python
def iterative_dfs(root):
    if not root: return                          # GOTCHA: `not root` is True for None AND for empty list — usually fine for tree nodes
    stack = [root]
    while stack:
        node = stack.pop()                       # pops from end (LIFO); pop(0) would be BFS but O(n) — use deque instead
        visit(node)
        for child in reversed(node.children):    # reversed() returns an iterator, not a new list — cheap
            stack.append(child)                  # pushing last → popped first, so leftmost child processed first
```

Key mental tools:
- In Python, use a plain `list` with `.append` and `.pop()` — both `O(1)` amortised. Avoid `list.pop(0)` (that's `O(n)`; use `collections.deque` if you need it).
- For monotonic stacks, **store indices** (not values) so you can compute distances (`i - j`) as well as read `arr[j]` when needed.
- Decide **strictly** vs **non-strictly** monotone based on the problem's tie-break rule. Strictly-decreasing (`<`) means equal elements do *not* pop each other; non-strictly (`<=`) means they do. LC 84 histogram and LC 42 trapping rain water diverge on exactly this choice.
- **Prove amortised O(n)**: "each element is pushed once and popped at most once". If your loop can push the same element twice, the analysis breaks.
- Add a **sentinel** at the end (e.g. `arr + [0]` for a histogram, `arr + [-inf]` for next-greater) to force the stack to drain — avoids a second loop to handle leftovers.

## 4. Classic Problems
- **LC 20 — Valid Parentheses** (Easy): Template A; classical pair-matching.
- **LC 739 — Daily Temperatures** (Medium): Template B; monotonic decreasing stack of indices.
- **LC 84 — Largest Rectangle in Histogram** (Hard): Template B with both previous-smaller and next-smaller resolved on the same pass.
- **LC 150 — Evaluate Reverse Polish Notation** (Medium): Template C.
- **LC 394 — Decode String** (Medium): Template D; stack of `(count, partial_string)` frames.
- **LC 402 — Remove K Digits** (Medium): Template E.
- **LC 735 — Asteroid Collision** (Medium): Template B with "both sides explode on tie" semantics.

## 5. Worked Example — Largest Rectangle in Histogram (LC 84)
Problem: given bar heights `heights = [2, 1, 5, 6, 2, 3]`, find the area of the largest axis-aligned rectangle that fits entirely inside the histogram.

### Step 1. Formulate the subproblem
For each bar `i`, the largest rectangle that uses `heights[i]` as its height has width `right[i] - left[i] - 1`, where:
- `left[i]` = index of the nearest bar to the left strictly shorter than `heights[i]`, or `-1` if none.
- `right[i]` = index of the nearest bar to the right strictly shorter than `heights[i]`, or `n` if none.

If we compute `left` and `right` in `O(n)` each, the final answer is `max(h[i] * (right[i] - left[i] - 1))`.

### Step 2. Compute `left` and `right` with monotonic stacks
Both are variants of Template B. For `right`, scan left-to-right with a strictly-increasing stack of indices — when a shorter bar arrives, all taller bars in the stack have found their right-bound and are popped.

```python
def largestRectangleArea(heights):
    n = len(heights)
    left = [-1] * n                              # default sentinel — "no smaller bar to the left"
    right = [n] * n                              # default sentinel — "no smaller bar to the right"
    stack = []                                   # indices, heights[stack] strictly increasing. GOTCHA: >= pops equals too
    for i, h in enumerate(heights):
        while stack and heights[stack[-1]] >= h:
            j = stack.pop()
            right[j] = i                         # first strictly smaller on the right
        left[i] = stack[-1] if stack else -1     # ternary: read AFTER popping; top is now previous-smaller
        stack.append(i)
    return max(h * (right[i] - left[i] - 1) for i, h in enumerate(heights))   # generator expr inside max() — O(1) space
```

### Step 3. Trace with `heights = [2, 1, 5, 6, 2, 3]`
Indices: `0, 1, 2, 3, 4, 5`. Stack stores indices; we show `heights` at those indices in parentheses.

| `i` | `h` | stack before | pops (resolve `right[j] = i`) | `left[i]` | stack after |
|---|---|---|---|---|---|
| 0 | 2 | `[]` | — | `-1` (empty stack) | `[0(2)]` |
| 1 | 1 | `[0(2)]` | pop 0: `right[0]=1` | `-1` | `[1(1)]` |
| 2 | 5 | `[1(1)]` | — (1 < 5, invariant holds) | `1` | `[1(1), 2(5)]` |
| 3 | 6 | `[1(1), 2(5)]` | — (5 < 6) | `2` | `[1(1), 2(5), 3(6)]` |
| 4 | 2 | `[1(1), 2(5), 3(6)]` | pop 3: `right[3]=4`; pop 2: `right[2]=4` | `1` | `[1(1), 4(2)]` |
| 5 | 3 | `[1(1), 4(2)]` | — (2 < 3) | `4` | `[1(1), 4(2), 5(3)]` |

Leftovers in the stack at end-of-loop keep `right[j] = n = 6` (their default). So:

| `i` | `h` | `left` | `right` | width = `right - left - 1` | area |
|---|---|---|---|---|---|
| 0 | 2 | -1 | 1 | 1 | 2 |
| 1 | 1 | -1 | 6 | 6 | **6** |
| 2 | 5 | 1 | 4 | 2 | **10** |
| 3 | 6 | 2 | 4 | 1 | 6 |
| 4 | 2 | 1 | 6 | 4 | 8 |
| 5 | 3 | 4 | 6 | 1 | 3 |

Max area = **10** (from bar 2 spanning indices 2–3 with height 5).

### Step 4. Complexity and the pop-once-each argument
Each index is pushed once and popped at most once across the whole loop. The `while` loop is not `O(n)` per iteration; the total number of inner iterations across the whole outer loop is bounded by `n`. Total time: `O(n)`. Space: `O(n)` for the stack plus the two auxiliary arrays.

### Step 5. One-pass variant
The two arrays can be fused into a single pass by sentinelling `heights + [0]`: when we finally reach the sentinel, all remaining bars in the stack have their right-bound = `n`. This is the compact production form.

```python
def largestRectangleArea(heights):
    stack = []; best = 0
    for i, h in enumerate(heights + [0]):        # `+ [0]` sentinel forces all bars to resolve. GOTCHA: `heights[i]` below would fail at sentinel — we iterate h here
        while stack and heights[stack[-1]] >= h:
            top = stack.pop()
            width = i if not stack else i - stack[-1] - 1   # empty stack ⇒ bar extends all the way left
            best = max(best, heights[top] * width)
        stack.append(i)                          # always push current index (even sentinel) — it still triggers resolution for smaller bars
    return best
```

The sentinel trick is worth memorising — it generalises to many "resolve all pending elements at the end" monotonic-stack problems.

## 6. Common Variations

### Pair matching and nesting
- **Valid parentheses** (LC 20): classic Template A.
- **Minimum remove to make valid parentheses** (LC 1249): stack of unmatched `(` indices; remove leftovers at the end.
- **Longest valid parentheses** (LC 32): stack of indices, push `-1` sentinel, measure on every `)` that pops.
- **Simplify path** (LC 71): path component stack; `..` pops, `.` ignored.
- **Basic calculator** (LC 224, LC 227): stack of operands with a sign; handles nested parentheses.

### Monotonic stack — "nearest X"
- **Next greater element** (LC 496, LC 503 circular): strictly decreasing stack.
- **Daily temperatures** (LC 739): same, resolve distance on pop.
- **Largest rectangle in histogram** (LC 84): previous-smaller + next-smaller combined.
- **Maximal rectangle** (LC 85): reduces to LC 84 per row.
- **Trapping rain water** (LC 42): stack of indices; when a taller bar arrives, pop and compute horizontal slabs.
- **Sum of subarray minimums / maximums** (LC 907): for each element find the span where it is the min/max.
- **Online stock span** (LC 901): monotonically decreasing stack of `(price, span)` pairs.

### Expression / RPN
- **Evaluate RPN** (LC 150): Template C.
- **Infix to RPN (shunting yard)**: two stacks, one for operators, one for output.
- **Decode string** (LC 394): Template D.
- **Number of atoms** (LC 726): chemistry-formula flavour of Template D.

### Greedy with undo (monotonic stack as pruning)
- **Remove K digits** (LC 402): smallest number after k removals.
- **Remove duplicate letters / smallest subsequence** (LC 316, LC 1081): each letter appears once, lexicographically smallest.
- **132 pattern** (LC 456): stack of candidate "2" values; scan right to left tracking max "3".
- **Asteroid collision** (LC 735): stack of moving-right asteroids; incoming left-movers cause collisions.
- **Car fleet** (LC 853): stack of arrival times; a slower fleet leader absorbs followers.

### Iterative traversal / deferred work
- **Iterative inorder / preorder / postorder** (LC 94, LC 144, LC 145): explicit stack simulation.
- **Clone graph iterative** (LC 133): stack of nodes to process.
- **Flatten multilevel doubly linked list** (LC 430): stack of deferred "next" nodes.

### Edge cases & pitfalls
- **Empty input** — early return, or make the templates robust to `not stack`.
- **Strict vs non-strict comparator** — the wrong one silently produces off-by-one areas or lost duplicates.
- **Forgetting to drain the stack at the end** — use a sentinel or a post-loop cleanup.
- **Using `list.pop(0)`** — that's `O(n)`, destroying the amortised guarantee; if you need FIFO, use `collections.deque`.
- **Mutating the stack while iterating** — keep `while stack and cond` patterns, never `for x in stack`.
- **Overflow in product/area** — Python is fine; C++/Java need `long`.
- **Mixing value-stack and index-stack** — pick one. Index-stack is more flexible (you can read the value from the array and also compute distances).

## 7. Related Patterns
- **Recursion** — every recursion has an equivalent explicit-stack iterative form (each recursive call = a stack frame).
- **Queue / Deque** — FIFO sibling. A deque is a stack that also allows cheap front operations — use it when you need **both** ends (e.g., sliding-window max).
- **Monotonic Deque** — sliding-window max/min. The stack gains a "head-eviction" operation based on window age.
- **DFS** — iterative DFS uses a stack; the pattern of push-children / pop-node is identical to the frame stack.
- **Greedy** — "remove k digits to make smallest number", "asteroid collision", "daily temperatures" — all greedy rules enforced via a monotonic stack.
- **Parsing / Shunting-yard** — expression evaluation and compilers use dual operator/operand stacks.
- **Dynamic Programming** — many DP-on-array problems where the transition depends on the previous-smaller/greater index (LC 907 sum of subarray minimums) become `O(n)` via monotonic stack instead of `O(n^2)` DP.

**Distinguishing note**: any question asking for the *closest* previous / next element under a comparison is a **monotonic stack** problem. Any question asking about *nesting* or *matching* is a **pair-matching** stack problem. Any question that wants both ends cheap (max of a moving window) is a **monotonic deque** problem. The structural difference is front-eviction: absent in a stack, core to a deque.
