# 14 — Recursion

## 1. When to Use
- Problem has a natural **self-similar structure**: trees, graphs, grids, nested lists, divide-and-conquer.
- Keywords: *"for each subtree"*, *"divide"*, *"conquer"*, *"all possible"*, *"combine the results of…"*, *"nested"*, *"reduce to a smaller instance"*, *"merge left and right"*.
- A problem can be expressed as a function of itself on a **strictly smaller input**.
- You can describe the answer as `answer(root) = combine(answer(left), answer(right))` — the **combine-subproblem-answers** shape.
- Backtracking / DFS / tree traversal is needed (see those patterns for the specialised forms).
- You have **overlapping subproblems** that reappear many times → recursion + memoisation → DP.
- Input structure is inherently recursive (JSON, XML, nested S-expressions, file trees, grammars, regexes).

### Signals that recursion is the wrong tool
- You can solve it with a single `O(n)` linear scan and mutable state.
- The recursion depth is `O(n)` and `n` is large (>10^4 in Python without `setrecursionlimit`) and the problem has a trivial iterative form — convert to an explicit stack or loop.
- You need **tail recursion** for correctness; Python does not optimise it, so iterative is required.

## 2. Core Idea
Recursion solves a problem by **reducing it to smaller instances of itself**, then combining the subproblem results. You need three ingredients:

1. A **base case** that does no further recursion — handles the smallest input explicitly.
2. A **recursive step** whose input is **provably smaller** (by a well-ordering on the problem space — size, depth, value, lex order) so the call tree is finite.
3. A **combine step** that merges subproblem results into the current answer.

Each recursive call is a frame on the call stack — that stack *is* your data structure, and Python's frame machinery is doing the bookkeeping for free. If the stack depth becomes a problem (recursion limit ~1000 by default, though `setrecursionlimit` can extend it), convert to an explicit stack (iterative DFS) or to iterative DP.

The crucial mental move is to **trust the recursion**: when you write `answer_left = solve(left)`, treat it as if it already returns the correct answer for `left` without tracing nested frames in your head. You verify correctness by verifying (a) the base case, (b) that inputs get smaller, and (c) that the combine step is right given correct sub-answers. This is induction on the call tree.

### Recursion shapes you will see
- **Linear recursion**: one recursive call per frame (factorial, list sum, reverse linked list).
- **Binary / tree recursion**: two calls per frame (Fibonacci, tree traversal, divide and conquer).
- **k-ary recursion**: arbitrary branching (DFS on a tree with many children, n-ary tree traversal).
- **Mutual recursion**: two or more functions call each other (recursive descent parsers, `is_even / is_odd`).
- **Nested recursion**: a recursive call's argument is itself a recursive call (Ackermann's function, some number-theoretic recurrences).
- **Tail recursion**: the recursive call is the **last** action — equivalent to a loop.

## 3. Template

### Template A — canonical recursive shape
```python
def solve(instance):
    # 1) Base case — smallest / trivial input. GOTCHA: MUST come first — missing base case = infinite recursion
    if is_base(instance):
        return base_answer(instance)

    # 2) Reduce — split into strictly smaller subproblems
    parts = split(instance)

    # 3) Recurse — solve each subproblem, trusting it returns correctly (list-comp)
    sub_answers = [solve(p) for p in parts]

    # 4) Combine — merge subproblem answers
    return combine(instance, sub_answers)
```

### Template B — tree recursion (post-order combine)
```python
def max_depth(node):
    if node is None:                              # GOTCHA: `is None` (identity) — more explicit than `if not node`
        return 0                                   # return 0 for empty tree (identity element for max)
    return 1 + max(max_depth(node.left), max_depth(node.right))   # +1 for current node

def tree_sum(node):
    if node is None: return 0                     # 0 = identity for sum
    return node.val + tree_sum(node.left) + tree_sum(node.right)   # + is left-associative; evaluation order L→R
```

### Template C — divide and conquer (merge sort)
```python
def merge_sort(arr):
    if len(arr) <= 1:
        return arr[:]                              # GOTCHA: `arr[:]` returns a shallow COPY — avoids mutating caller's list
    mid = len(arr) // 2                            # `//` integer division; `/` returns float in Py3
    left = merge_sort(arr[:mid])                   # slice up to (but not including) mid — end-exclusive
    right = merge_sort(arr[mid:])                  # slice from mid onward — no overlap with left
    return merge(left, right)

def merge(a, b):
    i = j = 0                                      # chained assignment: both set to 0
    out = []
    while i < len(a) and j < len(b):
        if a[i] <= b[j]:                           # `<=` (not `<`) preserves stability
            out.append(a[i]); i += 1
        else:
            out.append(b[j]); j += 1
    out.extend(a[i:]); out.extend(b[j:])           # one slice is empty; `extend` O(len(slice))
    return out
```

### Template D — memoisation (top-down DP)
```python
from functools import lru_cache

@lru_cache(maxsize=None)                           # maxsize=None = unbounded cache. GOTCHA: args must be HASHABLE (no lists/dicts)
def fib(n):
    if n < 2: return n                             # covers both n=0 and n=1 via `return n`
    return fib(n - 1) + fib(n - 2)

# Or with an explicit dict
def fib_dict(n, memo=None):
    if memo is None: memo = {}                    # GOTCHA: `memo={}` as default would SHARE state across calls (mutable default trap)
    if n < 2: return n
    if n in memo: return memo[n]                  # check memo BEFORE computing
    memo[n] = fib_dict(n - 1, memo) + fib_dict(n - 2, memo)   # store AFTER computing
    return memo[n]
```

### Template E — fast exponentiation (halve the problem)
```python
def power(x, n):
    if n == 0: return 1                            # identity base case
    if n < 0: return 1 / power(x, -n)              # GOTCHA: returns float for negative exponents
    half = power(x, n // 2)                        # compute once, reuse — key to O(log n) speedup
    return half * half * (x if n & 1 else 1)       # `n & 1` tests odd; ternary picks extra factor of x
```

### Template F — tail-recursion rewritten as iteration
```python
# Tail-recursive (do not use in Python — no TCO, blows stack at ~1000)
def factorial_tail(n, acc=1):                      # `acc=1` is OK as default here — int is immutable (not a mutable default!)
    if n <= 1: return acc
    return factorial_tail(n - 1, acc * n)         # last action is a call

# Iterative equivalent
def factorial(n):
    acc = 1
    while n > 1:                                   # loop body mirrors the recursive call
        acc *= n; n -= 1                            # GOTCHA: `acc *= n` BEFORE `n -= 1` — else multiply by n-1 instead
    return acc
```

### Template G — iterative via explicit stack (depth-first emulation)
```python
def iterative_dfs_preorder(root):
    if not root: return []
    out = []; stack = [root]
    while stack:
        node = stack.pop()                        # LIFO: last pushed = first popped
        out.append(node.val)
        if node.right: stack.append(node.right)   # push right FIRST so it's popped AFTER left
        if node.left:  stack.append(node.left)    # left pushed last → popped first (preserves preorder)
    return out
```

Key mental tools:
- **Write the base case first** — it is the contract that makes the rest correct.
- State the function's **meaning precisely**: *"given X, return Y"*. Stick to that meaning at every call site.
- **Trust the recursion**: when you write `solve(smaller)`, assume it works. Don't mentally expand frames.
- **Prove termination**: argue that every recursive call's input is strictly smaller under some well-ordering (size, depth, lex, numeric).
- **Prove correctness by induction**: base case + inductive step (assume subproblem answers correct → combine is correct).
- Python's default recursion limit is 1000 frames. For deep inputs: `sys.setrecursionlimit(10**6)` or convert to iterative.
- **Memoisation** collapses exponential call trees to polynomial when subproblems repeat (overlapping subproblems property).
- `@lru_cache` requires hashable arguments — convert lists to tuples, dicts to frozensets before calling.
- **Do not mutate arguments** unless you are sure of the ownership — it breaks the "function of input" mental model.

## 3.5. Proving recursion terminates and is correct
Every recursion proof has two halves:

**Termination**: define a measure `μ(input)` — a natural number, or any well-founded order — and show that every recursive call is made on an input with strictly smaller `μ`. Common measures:
- Length of array / string.
- Tree height / number of nodes.
- Numeric value (for `pow(x, n)`, `μ = n`).
- Remaining budget (`k` steps left, `n` choices remaining).

**Correctness**: induction on `μ`.
- *Base case*: the function returns the right answer when `μ(input)` is minimal.
- *Inductive step*: assume the function returns the right answer for all inputs with `μ < k`. Show it returns the right answer when `μ(input) = k`, given that all recursive calls are on smaller-`μ` inputs (by termination) and thus correct (by IH).

Skipping the proof is fine for trivial recursions. For anything with tricky bookkeeping (Floyd's cycle finding, certain DP transitions), write it down — it catches 80% of off-by-one bugs.

## 4. Classic Problems
- **LC 104 — Maximum Depth of Binary Tree** (Easy): textbook tree recursion (Template B).
- **LC 21 — Merge Two Sorted Lists** (Easy): recursive merge.
- **LC 50 — Pow(x, n)** (Medium): halve the exponent — `O(log n)` (Template E).
- **LC 509 — Fibonacci Number** (Easy): naive recursion is exponential, memoisation makes it linear (Template D).
- **LC 394 — Decode String** (Medium): recursive parser over nested brackets.
- **LC 241 — Different Ways to Add Parentheses** (Medium): split at each operator, recurse on both sides, combine — canonical D&C with memoisation.
- **LC 95 — Unique Binary Search Trees II** (Medium): enumerate trees by picking each root.

## 5. Worked Example — Fibonacci with Memoisation (LC 509)
Problem: compute `F(n)` where `F(0) = 0`, `F(1) = 1`, `F(n) = F(n-1) + F(n-2)`.

This is the canonical worked example for three reasons: it exposes the **exponential blowup** of naive recursion, shows how **overlapping subproblems** lead to memoisation, and previews the bottom-up DP that is the topic's natural successor.

### Step 1. Write the naive recursion and see it explode
```python
def fib(n):
    if n < 2: return n                             # handles F(0)=0 and F(1)=1 in one line
    return fib(n - 1) + fib(n - 2)                # GOTCHA: no memo → exponential O(φⁿ)
```
Call tree for `n = 5`:

```
                fib(5)
             /         \
         fib(4)         fib(3)
         /    \         /    \
     fib(3)  fib(2)  fib(2)  fib(1)
     /   \   /   \   /   \
  fib(2) fib(1) fib(1) fib(0) fib(1) fib(0)
  /  \
fib(1) fib(0)
```

Count the calls: 1 + 2 + 4 + 6 + 2 = 15 (`fib(5)` plus all descendants). More generally, `T(n) = T(n-1) + T(n-2) + 1`, which grows as `Θ(φ^n)` with `φ = (1+√5)/2 ≈ 1.618`. Exponential — `fib(50)` alone makes over a billion calls.

**The pathology**: `fib(3)` is computed twice, `fib(2)` three times, `fib(1)` five times, `fib(0)` three times. The subproblems **overlap**.

### Step 2. Add a memo (top-down DP)
```python
def fib(n, memo=None):
    if memo is None: memo = {}                    # GOTCHA: `memo={}` as default is SHARED across top-level calls — use None sentinel
    if n < 2: return n
    if n in memo: return memo[n]                  # `in dict` is O(1) avg
    memo[n] = fib(n - 1, memo) + fib(n - 2, memo) # must pass `memo` to both children to share state
    return memo[n]
```

Trace for `n = 5` (top-down fills `memo`; only the leftmost-first DFS order shown):

| call | in memo? | action | `memo` after |
|---|---|---|---|
| `fib(5)` | no | recurse into `fib(4)` then `fib(3)` | — |
| `fib(4)` | no | recurse into `fib(3)` then `fib(2)` | — |
| `fib(3)` | no | recurse into `fib(2)` then `fib(1)` | — |
| `fib(2)` | no | recurse into `fib(1)=1` then `fib(0)=0`; store `2:1` | `{2:1}` |
| `fib(2)` returns `1` | | | |
| back in `fib(3)`: `fib(1) = 1` | | `1 + 1 = 2`; store `3:2` | `{2:1, 3:2}` |
| `fib(3)` returns `2` | | | |
| back in `fib(4)`: `fib(2)` | **yes** | return `1` directly (memo hit) | `{2:1, 3:2}` |
| `fib(4)` store: `2 + 1 = 3`; `4:3` | | | `{2:1, 3:2, 4:3}` |
| back in `fib(5)`: `fib(3)` | **yes** | return `2` (memo hit) | `{2:1, 3:2, 4:3}` |
| `fib(5)` store: `3 + 2 = 5`; `5:5` | | | `{2:1, 3:2, 4:3, 5:5}` |

Result: `5`. Each subproblem `fib(0..n)` is computed **once** — `O(n)` work per subproblem times `n` subproblems = `O(n)` time total, `O(n)` memo space plus `O(n)` call-stack depth. We turned `Θ(φ^n)` into `O(n)` by eliminating redundant work.

### Step 3. Recognise the pattern — this is DP
Top-down memoised recursion is exactly top-down DP. To convert to bottom-up:

```python
def fib_bottom_up(n):
    if n < 2: return n
    prev2, prev1 = 0, 1                           # F(0), F(1)
    for _ in range(2, n + 1):                     # range end-exclusive: iterates 2..n
        prev2, prev1 = prev1, prev2 + prev1       # GOTCHA: tuple-assign — RHS fully evaluated BEFORE LHS; avoids needing `tmp`
    return prev1
```

Same `O(n)` time, `O(1)` space (we only need the last two values). This is the standard trajectory: recursion → recursion + memo (top-down DP) → iterative DP → space-optimised DP.

### Step 4. Why this matters
Every DP problem you meet started life as a recursive definition. Being fluent in the recursion-to-DP move — identify subproblems, identify overlap, add a memo, optionally flip to iterative — is the mechanical core of most medium/hard interview problems.

## 6. Common Variations

### Head vs tail recursion
- **Head recursion** (combine *after* the call returns): tree traversals, `reverse_list(head.next) + head` — cannot be trivially flattened to a loop.
- **Tail recursion** (recursive call is the last action): convert to a `while` loop. Python does not optimise; always prefer the loop if depth matters.

### Divide and conquer
- **Merge sort** (Template C): `T(n) = 2T(n/2) + O(n) = O(n log n)`.
- **Quicksort**: same recurrence on average; worst-case `O(n^2)` on adversarial pivots.
- **Maximum subarray** (LC 53 D&C solution): `max(left, right, cross-midpoint)`.
- **Closest pair of points**: classical D&C in computational geometry.
- **Fast exponentiation** (Template E): `O(log n)`.
- **Karatsuba multiplication**: `T(n) = 3T(n/2) + O(n) = O(n^{log_2 3})`.

### Tree recursion (the 80% of tree problems)
- Root / leaf aggregates: max depth, balanced check, diameter, max path sum.
- Top-down accumulation: root-to-leaf paths (LC 257), path sum (LC 112).
- Post-order combine: return a tuple from each subtree (e.g. `(is_balanced, height)` to avoid double recursion in LC 110).
- Tree construction from traversals: LC 105 (preorder + inorder), LC 106 (inorder + postorder).

### Mutual recursion
- `is_even(n) / is_odd(n)` toy example.
- Recursive descent parsers: `parse_expr / parse_term / parse_factor`.
- Game-theoretic recursion: `max_score(state) / min_score(state)`.

### Memoisation placement
- Always check memo **before** doing work.
- Store **after** computing, **before** returning.
- For functions with **mutable defaults** (`memo={}`), the default is **shared** across calls — a Python footgun. Either use `memo=None` and initialise inside, or pass an explicit dict.
- `@lru_cache` is ergonomic but caches forever; clear it with `.cache_clear()` if you re-run tests.

### Iterative rewrite techniques
- Tail recursion → `while`.
- Linear recursion → accumulator + loop.
- Tree recursion → explicit stack (Template G) or Morris traversal (no extra space).
- Overlapping subproblems → memo → bottom-up DP with a table.

### Edge cases & pitfalls
- **Empty input** — return the identity element for combine (0 for sum, [] for list of subsets).
- **Recursion depth limit** — Python 1000 default. For n = 10^5 linear recursion, you must rewrite iteratively or call `sys.setrecursionlimit`.
- **Unbounded recursion** — missing base case, or base case never reached due to a bug in reduction. Prove termination explicitly.
- **Mutable default arguments** — `def f(..., memo={})` shares `memo` across all calls at module level.
- **Returning references vs copies** — if you mutate a subproblem's return value, aliasing can cause silent corruption. Copy if uncertain.
- **Hashability for memo keys** — lists/dicts/sets are not hashable; convert to tuple / frozenset.

## 7. Related Patterns
- **Backtracking** — recursion + an **undo** step after each child call. The undo is what distinguishes backtracking from plain recursion.
- **Dynamic Programming** — recursion + memo (top-down), or the bottom-up iterative dual.
- **DFS** — recursion on graphs/trees; often the natural expression of "visit every child and combine".
- **Divide and Conquer** — recursion where subproblems are disjoint slices of the input and combine is non-trivial.
- **Stack** — the iterative substitute for a recursion's implicit call stack.
- **Tree DFS / Tree BFS** — tree traversal patterns are recursion-first (DFS) or queue-first (BFS).
- **Greedy** — some recursions are actually greedy once you prove the "choose locally best" is optimal.

**Distinguishing note**: **recursion** is a *technique*, not a pattern on its own. You apply it when the problem's structure is self-similar; the actual work lives in the *combine* step, which is where backtracking (undo), DP (memo), D&C (disjoint splits), and DFS (visit-every-child) diverge. If you find yourself debugging nested frames, you have lost trust in the recursion — step back, write down the function's contract, and verify base + reduction + combine in isolation.
