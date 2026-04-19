# 04 — Strings

## 1. When to Use
- Input is text: `s`, `word`, `pattern`, `sentence`, `document`, `path`.
- Task involves **substrings, subsequences of characters, palindromes, anagrams, matching, parsing, or transformation**.
- Keywords: *"substring"*, *"contains"*, *"reorder the letters"*, *"case-insensitive"*, *"alphanumeric only"*, *"valid parentheses"*, *"decode/encode"*, *"longest/shortest"*, *"pattern occurs in"*.
- Constraints mention a limited alphabet (`a-z`, ASCII 128, digits, DNA `ACGT`) — this unlocks fixed-size counting arrays and bitmasks.
- You need to **compare two strings structurally** (anagrams, isomorphic, one-edit-distance).
- The problem looks like an array problem but with alphabet structure giving extra tricks.
- Python immutability trap: if you are building a string character-by-character with `+=`, think *list + join* or *list of chars* instead.

## 2. Core Idea
A string is an array of characters plus an alphabet. Almost every array technique (two pointers, sliding window, prefix sum) transfers directly, and the bounded alphabet unlocks extras: fixed-size frequency vectors (`[0] * 26`), bitmask fingerprints, hash signatures, and `O(26)` comparisons instead of `O(n)`. In Python, immutability forces you to build results with `list` / `deque` / `bytearray`, never with `+=` inside a loop — otherwise you accidentally get `O(n^2)` work.

The right question on any string problem: *"what is the canonical form of this character sequence for my purpose?"* Sorted chars, frequency vector, bitmask of seen, lowered+alnum-filtered — picking the right canonical form is usually half the solution.

## 3. Template

### Fixed 26-slot counter (lowercase English)
```python
def count_lower(s):
    freq = [0] * 26                          # GOTCHA: `[[0]] * 26` would share the same inner list (mutable trap). Plain ints are safe.
    for ch in s:
        freq[ord(ch) - ord('a')] += 1        # ord('a') == 97; subtracting maps 'a'..'z' → 0..25
    return freq                               # use tuple(freq) when you need a hashable key (e.g. dict / set)
```

### Two-pointer palindrome check with alnum-skip
```python
def is_palindrome(s):
    lo, hi = 0, len(s) - 1
    while lo < hi:
        # `lo < hi` guard inside the inner while prevents pointers crossing on all-non-alnum input like " ,;"
        while lo < hi and not s[lo].isalnum(): lo += 1   # `.isalnum()` is True for letters AND digits
        while lo < hi and not s[hi].isalnum(): hi -= 1
        if s[lo].lower() != s[hi].lower(): return False  # `.lower()` per char is OK; cheaper to lower s once if reused
        lo += 1; hi -= 1
    return True
```

### Expand-around-center palindrome (find the longest)
```python
def longest_palindrome(s):
    def expand(l, r):
        # Boundary check FIRST (short-circuits on l < 0 or r >= len), then char compare. Order matters — Python AND short-circuits left-to-right.
        while l >= 0 and r < len(s) and s[l] == s[r]:
            l -= 1; r += 1
        return s[l+1:r]                       # loop exits one step PAST valid bounds; +1/-1 corrects, slice end is exclusive
    best = ""
    for i in range(len(s)):
        for a, b in ((i, i), (i, i + 1)):     # (i,i) = odd-length center; (i, i+1) = even-length (between two chars)
            cand = expand(a, b)
            if len(cand) > len(best): best = cand
    return best
```

### Anagram comparison (vector equality)
```python
def is_anagram(a, b):
    if len(a) != len(b): return False        # cheap early exit; without this you'd still get the right answer but slower
    f = [0] * 26
    for ch in a: f[ord(ch) - ord('a')] += 1  # +1 for letters in a
    for ch in b: f[ord(ch) - ord('a')] -= 1  # -1 for letters in b — net zero ⇒ same multiset
    return all(v == 0 for v in f)            # `all` short-circuits on first non-zero ⇒ faster than `sum(map(abs, f)) == 0`
```

### Rolling hash (Rabin-Karp skeleton)
```python
def rabin_karp(text, pattern, base=31, mod=(1 << 61) - 1):
    # `(1 << 61) - 1` is a large Mersenne prime — minimises collision chance and fits in 64-bit signed
    n, m = len(text), len(pattern)
    if m > n: return -1
    p_hash = t_hash = 0
    power = 1                                 # will hold base^(m-1) mod p — used to subtract the leading char on slide
    for i in range(m):
        p_hash = (p_hash * base + ord(pattern[i])) % mod   # polynomial hash: c0*b^(m-1) + c1*b^(m-2) + ...
        t_hash = (t_hash * base + ord(text[i])) % mod
        if i < m - 1: power = power * base % mod           # avoid one extra multiply on the last iter
    for i in range(n - m + 1):
        # GOTCHA: hash equality is NOT proof of substring equality (collisions exist) — verify with text[i:i+m] == pattern
        if t_hash == p_hash and text[i:i+m] == pattern:
            return i
        if i + m < n:
            # Slide window: subtract leading char's contribution, multiply by base, add new trailing char
            t_hash = ((t_hash - ord(text[i]) * power) * base + ord(text[i+m])) % mod
            # Python's `%` already returns non-negative for positive mod, so no extra normalisation needed
    return -1
```

### Build result via list + join (never `+=` on str)
```python
def transform(s):
    parts = []
    for ch in s:
        parts.append(ch.upper() if ch.isalpha() else ch)   # ternary: `value_if_true if cond else value_if_false`
    return "".join(parts)                     # KEY: strings are IMMUTABLE in Python; `result += ch` allocates a NEW string each time → O(n^2)
```

Key mental tools:
- `ord(c) - ord('a')` maps lowercase to `0..25`.
- `collections.Counter` for arbitrary alphabets; `[0] * 26` when you know it's English.
- Two anagrams compare equal either by `sorted(a) == sorted(b)` (`O(n log n)`) or by frequency vector (`O(n + Σ)`).
- Bitmask `mask |= 1 << (ord(c) - ord('a'))` records which letters appeared — useful for "longest substring with distinct chars" in bounded alphabets.
- Normalise input once (`s.lower()`, `s.strip()`, filter alnum) rather than inside every comparison.

## 4. Classic Problems
- **LC 125 — Valid Palindrome** (Easy): two pointers with alnum skip.
- **LC 242 — Valid Anagram** (Easy): frequency vector.
- **LC 3 — Longest Substring Without Repeating Characters** (Medium): sliding window + last-seen index.
- **LC 438 — Find All Anagrams in a String** (Medium): fixed-window with 26-int match.
- **LC 5 — Longest Palindromic Substring** (Medium): expand around center.

## 5. Worked Example — Longest Palindromic Substring (LC 5)
Problem: given `s = "babad"`, return any longest palindromic substring. Expected `"bab"` or `"aba"`.

Approach: for each index `i`, treat it as the **center** of a palindrome and expand outward while characters match. Do this for odd-length centers (`i, i`) and even-length centers (`i, i + 1`). Every palindrome has exactly one center, so every candidate is visited exactly twice (once as odd, once as even).

```python
def longestPalindrome(s):
    def expand(l, r):
        # Bounds first, then char compare — Python AND short-circuits, so s[l] never indexes out-of-range
        while l >= 0 and r < len(s) and s[l] == s[r]:
            l -= 1; r += 1
        return l + 1, r - 1                  # loop overshoots by 1 each side; +1/-1 reels back to the last valid match

    best_l, best_r = 0, 0                    # default to a length-1 palindrome at index 0
    for i in range(len(s)):
        for a, b in ((i, i), (i, i + 1)):    # try odd center (single char) and even center (between two chars)
            l, r = expand(a, b)
            if r - l > best_r - best_l:      # compare lengths via index difference (cheaper than len(slice))
                best_l, best_r = l, r
    return s[best_l:best_r + 1]              # +1 because slice end is exclusive
```

Trace on `s = "babad"` (indices 0..4):

| `i` | center | expand steps `(l, r)` | palindrome found | length | `(best_l, best_r)` after |
|---|---|---|---|---|---|
| 0 | (0,0) `b` | `(0,0)` ok → `(-1,1)` stop | `"b"` | 1 | (0, 0) |
| 0 | (0,1) `b,a` | mismatch immediately | `""` | 0 | (0, 0) |
| 1 | (1,1) `a` | `(1,1)` ok → `(0,2)` `b=b` ok → `(-1,3)` stop | `"bab"` | 3 | (0, 2) |
| 1 | (1,2) `a,b` | mismatch | `""` | 0 | (0, 2) |
| 2 | (2,2) `b` | `(2,2)` ok → `(1,3)` `a=a` ok → `(0,4)` `b≠d` stop | `"aba"` | 3 | (0, 2) |
| 2 | (2,3) `b,a` | mismatch | `""` | 0 | (0, 2) |
| 3 | (3,3) `a` | `(3,3)` ok → `(2,4)` `b≠d` stop | `"a"` | 1 | (0, 2) |
| 3 | (3,4) `a,d` | mismatch | `""` | 0 | (0, 2) |
| 4 | (4,4) `d` | `(4,4)` ok → `(3,5)` oob stop | `"d"` | 1 | (0, 2) |
| 4 | (4,5) oob | skip | — | — | (0, 2) |

Return `s[0:3] = "bab"`. Time `O(n^2)`, space `O(1)`. Manacher's algorithm gets this to `O(n)` by reusing palindromes already found around previously-expanded centers.

### Alternative — frequency-vector anagram check (LC 242)
For `s = "anagram"`, `t = "nagaram"`:

| step | action | `a` | `g` | `m` | `n` | `r` |
|---|---|---|---|---|---|---|
| start | — | 0 | 0 | 0 | 0 | 0 |
| +a | freq | 1 | 0 | 0 | 0 | 0 |
| +n | freq | 1 | 0 | 0 | 1 | 0 |
| +a | freq | 2 | 0 | 0 | 1 | 0 |
| +g | freq | 2 | 1 | 0 | 1 | 0 |
| +r | freq | 2 | 1 | 0 | 1 | 1 |
| +a | freq | 3 | 1 | 0 | 1 | 1 |
| +m | freq | 3 | 1 | 1 | 1 | 1 |
| -n | decrement | 3 | 1 | 1 | 0 | 1 |
| -a | decrement | 2 | 1 | 1 | 0 | 1 |
| -g | decrement | 2 | 0 | 1 | 0 | 1 |
| -a | decrement | 1 | 0 | 1 | 0 | 1 |
| -r | decrement | 1 | 0 | 1 | 0 | 0 |
| -a | decrement | 0 | 0 | 1 | 0 | 0 |
| -m | decrement | 0 | 0 | 0 | 0 | 0 |

All zero → anagram. `O(n)` time, `O(1)` space (26-slot array).

## 6. Common Variations

### Palindrome family
- **Check palindrome**: two pointers (LC 125).
- **Longest palindromic substring**: expand-around-center (LC 5), Manacher `O(n)`.
- **Palindromic subsequence**: DP `dp[i][j]` on `s[i..j]` (LC 516, LC 647).
- **Palindrome partitioning**: backtracking + memo (LC 131, LC 132).
- **Valid palindrome with ≤ k deletions** (LC 680, LC 1216): two pointer + skip budget.

### Anagram family
- **Valid anagram** (LC 242): frequency vector.
- **Group anagrams** (LC 49): canonical key = sorted chars or 26-tuple.
- **Find all anagrams in a string** (LC 438): sliding window + rolling 26-int compare.
- **Permutation in string** (LC 567): same as LC 438 — "does any window match the pattern frequency?"
- **Minimum window substring** (LC 76): sliding window with need-counter.

### Pattern matching
- **Naive match**: `O(n·m)`.
- **KMP**: `O(n + m)` via longest-proper-prefix-that-is-also-suffix table (LC 28, LC 459).
- **Z-algorithm**: `O(n + m)` alternative, computes Z-array over `pattern + sep + text`.
- **Rabin-Karp rolling hash**: `O(n + m)` expected; great for multi-pattern match (Aho-Corasick generalisation).
- **Suffix array / suffix automaton**: heavy tools, `O(n log n)` / `O(n)` build, for `k` distinct substrings etc.

### Parsing & transformation
- **Tokenise**: `s.split()`, regex, manual scan.
- **Decode string** (LC 394): stack of `(count, partial)` frames.
- **Basic calculator** (LC 224, LC 227): operand stack + operator stack (or recursion).
- **Roman to int / int to Roman** (LC 13, LC 12): table lookup + greedy.
- **Run-length encode/decode**: scan, group runs, emit `count+char`.

### Substring windows
- **Longest substring without repeating** (LC 3): sliding window + last-seen.
- **Longest substring with ≤ k distinct** (LC 340): window + Counter.
- **Smallest window containing pattern** (LC 76): window + need-counter + formed count.
- **Character replacement** (LC 424): window with majority-char bookkeeping.

### Edit / comparison DP
- **Edit distance** (LC 72): 2D DP with insert/delete/replace.
- **Longest common subsequence** (LC 1143): 2D DP.
- **Longest common substring**: 2D DP where `dp[i][j] = dp[i-1][j-1] + 1` iff equal chars.
- **One edit distance** (LC 161): two pointers with a skip budget.

### Alphabet tricks
- **Bitmask of letters present**: 26-bit int per string, union/intersect/XOR.
- **Unique chars check**: `len(set(s)) == len(s)`.
- **Isomorphic strings** (LC 205): two maps enforcing a bijection.
- **Word pattern** (LC 290): pattern-char ↔ word bijection via two maps.

### Edge cases
- empty string, single char, all same char
- mixed case, whitespace, punctuation
- unicode beyond ASCII (use `Counter`, not 26-array)
- string length differences in paired problems
- `+=` accidental `O(n^2)` in Python/Java loops

## 7. Related Patterns
- **Arrays** — strings inherit every array technique; alphabet is the bonus.
- **Hashing** — `Counter` / sets / canonical keys / rolling hash.
- **Sliding Window** — dominant pattern for "longest/shortest substring with constraint".
- **Two Pointers** — palindromes, reversals, alnum-filter, one-edit comparisons.
- **Dynamic Programming** — edit distance, LCS, palindromic subsequence, partitioning.
- **Tries** — many patterns against one text, autocompletion, prefix grouping.
- **Stack** — nested-structure parsers (brackets, calculators, decoders).

**Distinguishing note**: if a problem asks about **contiguous** slices of characters, it is almost always sliding window or two pointers; if it asks about **reorderings**, it is a Counter / 26-int fingerprint; if it asks about **edit distance** or **subsequences**, it is DP; if it asks about **matching one pattern in one text**, start with naive/rolling-hash before reaching for KMP.
