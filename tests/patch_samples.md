# PatchGate Regression Samples (Frozen v1)

Purpose:
- Provide a minimal, portable regression corpus for PatchGate.
- Every change to `patch_gate.sh` MUST preserve expected outcomes on these samples,
  unless a protocol major bump is explicitly made (v2/v3).

How to use:
- Copy any sample block into a `.diff` file and run:
  - `./patch_gate.sh sample.diff`
- Expected result is indicated per sample.

Conventions:
- PASS samples MUST exit 0.
- FAIL samples MUST exit non-zero and print a `[patch_gate] FAIL:` message.
- Samples intentionally cover both common and adversarial cases.

NOTE:
- Some PASS samples require a base repo state (files exist with exact content).
  `tests/run.sh` creates that state automatically.

---

## PASS-01: Modify an existing file (requires base state)
Expected: PASS

```diff
diff --git a/README.md b/README.md
index 0000000..1111111 100644
--- a/README.md
+++ b/README.md
@@ -1,1 +1,2 @@
 # PatchGate
+PATCH READY
```

---

## PASS-02: Add a new text file with content
Expected: PASS

```diff
diff --git a/docs/example.txt b/docs/example.txt
new file mode 100644
--- /dev/null
+++ b/docs/example.txt
@@ -0,0 +1,2 @@
+hello
+world
```

---

## PASS-03: Delete an existing file with content (requires base state)
Expected: PASS

```diff
diff --git a/docs/to_delete.txt b/docs/to_delete.txt
deleted file mode 100644
--- a/docs/to_delete.txt
+++ /dev/null
@@ -1,1 +0,0 @@
-delete-me
```

---

## PASS-04: Add an empty file (allowed; may have no hunks)
Expected: PASS

```diff
diff --git a/empty/new_empty.txt b/empty/new_empty.txt
new file mode 100644
--- /dev/null
+++ b/empty/new_empty.txt
```

---

## PASS-05: Delete an empty file (requires base state; may have no hunks)
Expected: PASS

```diff
diff --git a/empty/old_empty.txt b/empty/old_empty.txt
deleted file mode 100644
--- a/empty/old_empty.txt
+++ /dev/null
```

---

## FAIL-01: Missing diff header
Expected: FAIL

```diff
--- a/foo.txt
+++ b/foo.txt
@@ -1,1 +1,1 @@
-a
+b
```

---

## FAIL-02: Path traversal with ../
Expected: FAIL

```diff
diff --git a/../pwn.txt b/../pwn.txt
new file mode 100644
--- /dev/null
+++ b/../pwn.txt
@@ -0,0 +1,1 @@
+pwn
```

---

## FAIL-03: Touching .git/ internals
Expected: FAIL

```diff
diff --git a/.git/config b/.git/config
new file mode 100644
--- /dev/null
+++ b/.git/config
@@ -0,0 +1,1 @@
+evil
```

---

## FAIL-04: Binary patch marker
Expected: FAIL

```diff
diff --git a/bin/file b/bin/file
new file mode 100644
--- /dev/null
+++ b/bin/file
GIT binary patch
literal 3
abc
```

---

## FAIL-05: Symlink mode (120000)
Expected: FAIL

```diff
diff --git a/link b/link
new file mode 120000
--- /dev/null
+++ b/link
@@ -0,0 +1,1 @@
+target
```

---

## FAIL-06: Submodule mode (160000)
Expected: FAIL

```diff
diff --git a/submod b/submod
new file mode 160000
--- /dev/null
+++ b/submod
@@ -0,0 +1,1 @@
+deadbeef
```

---

## FAIL-07: Rename operation metadata
Expected: FAIL

```diff
diff --git a/a.txt b/b.txt
similarity index 100%
rename from a.txt
rename to b.txt
```

---

## FAIL-08: Copy operation metadata
Expected: FAIL

```diff
diff --git a/a.txt b/b.txt
similarity index 100%
copy from a.txt
copy to b.txt
```

---

## FAIL-09: Illegal file mode (100666)
Expected: FAIL

```diff
diff --git a/weird_mode.txt b/weird_mode.txt
new file mode 100666
--- /dev/null
+++ b/weird_mode.txt
@@ -0,0 +1,1 @@
+nope
```

---

## FAIL-10: Marker/header mismatch (diff says A, markers point to B)
Expected: FAIL

```diff
diff --git a/docs/a.txt b/docs/a.txt
new file mode 100644
--- /dev/null
+++ b/docs/b.txt
@@ -0,0 +1,1 @@
+oops
```

---

## FAIL-11: Backslash in path (explicitly blocked)
Expected: FAIL

```diff
diff --git a/win\path.txt b/win\path.txt
new file mode 100644
--- /dev/null
+++ b/win\path.txt
@@ -0,0 +1,1 @@
+nope
```

---

## FAIL-12: Mode-only patch (policy: not allowed)
Expected: FAIL

```diff
diff --git a/README.md b/README.md
old mode 100644
new mode 100755
index 0000000..1111111 100644
--- a/README.md
+++ b/README.md
```

---

## FAIL-13: No hunks for a modification (illegal)
Expected: FAIL

```diff
diff --git a/README.md b/README.md
index 0000000..1111111 100644
--- a/README.md
+++ b/README.md
```
