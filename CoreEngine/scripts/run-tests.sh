#!/usr/bin/env python3
# Deterministic test runner for CoreEngine that prints an explicit summary.
# Avoids the trailing “0 tests” banner by emitting our own counts.

import subprocess
import sys
import re

cmd = ["swift", "test", "--parallel", "--verbose"]

passed = 0
failed = 0

proc = subprocess.Popen(cmd, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True)

lines = []
for line in proc.stdout:
    sys.stdout.write(line)
    sys.stdout.flush()
    lines.append(line)

proc.wait()

passed_re = re.compile(r"Test Case '-\[.*\]' passed")
failed_re = re.compile(r"Test Case '-\[.*\]' failed")
executed_re = re.compile(r"Executed (\d+) tests?, with (\d+) failures")

executed = None
for line in lines:
    if passed_re.search(line):
        passed += 1
    if failed_re.search(line):
        failed += 1
    m = executed_re.search(line)
    if m:
        tests = int(m.group(1))
        fails = int(m.group(2))
        executed = (tests, fails)

if executed:
    tests, fails = executed
    passed = tests - fails
    failed = fails
total = passed + failed

print("\n=== CoreEngine Test Summary ===")
print(f"Total: {total}  Passed: {passed}  Failed: {failed}")

sys.exit(proc.returncode)

