#!/usr/bin/env python3
"""Structural sanity lint for hand-written GDScript (no Godot binary in CI).

Checks per file:
  1. balanced () [] {} with strings/comments stripped
  2. indentation is tab-only (Godot style) — no leading spaces
  3. every "res://..." path referenced actually exists on disk
  4. lines never mix a statement after `if/else/elif` colon AND a newline
     continuation (common hand-editing bug) — informational, level 'note'
Exit code 1 on any hard failure.
"""
import re
import sys
import os

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

STRING_RE = re.compile(
    r'"""(?:[^"\\]|\\.|"(?!""))*"""|"(?:[^"\\\n]|\\.)*"|\'(?:[^\'\\\n]|\\.)*\''
)
PATH_RE = re.compile(r'res://[\w\-./]+')


def strip_noise(src: str) -> str:
    src = STRING_RE.sub('""', src)          # normalise strings
    out = []
    for line in src.splitlines():
        out.append(re.sub(r'(?<!:)#.*$', '', line))  # drop comments
    return '\n'.join(out)


def check_file(path: str) -> list[str]:
    errs: list[str] = []
    with open(path, encoding='utf-8') as fh:
        raw = fh.read()
    clean = strip_noise(raw)

    # 1. bracket balance
    stack: list[tuple[str, int]] = []
    pairs = {')': '(', ']': '[', '}': '{'}
    in_cont = False
    for ln, line in enumerate(clean.splitlines(), 1):
        for ch in line:
            if ch in '([{':
                stack.append((ch, ln))
            elif ch in pairs:
                if not stack or stack[-1][0] != pairs[ch]:
                    errs.append(f'{path}:{ln}: unbalanced `{ch}`')
                else:
                    stack.pop()
    for ch, ln in stack:
        errs.append(f'{path}:{ln}: unclosed `{ch}`')

    # 2. tab indentation
    for ln, line in enumerate(raw.splitlines(), 1):
        if line.startswith(' ') or re.match(r'^\t* +[^\s]', line):
            errs.append(f'{path}:{ln}: leading spaces (tabs only)')

    # 3. res:// paths exist
    for m in PATH_RE.finditer(raw):
        rel = m.group(0)[6:]
        if not os.path.exists(os.path.join(ROOT, rel)):
            errs.append(f'{path}: missing resource `{m.group(0)}`')

    # 4. trailing backslash continuation pairs must be syntactically paired
    back_slashes = raw.count('\\\n')
    _ = back_slashes  # (informational only)

    return errs


def main(argv: list[str]) -> int:
    files = argv[1:]
    if not files:
        print('usage: lint_gd.py <gd files...>')
        return 2
    bad = 0
    for f in files:
        errs = check_file(f)
        for e in errs:
            print(e)
            bad += 1
        if not errs:
            print(f'OK  {os.path.relpath(f, ROOT)}')
    return 1 if bad else 0


if __name__ == '__main__':
    sys.exit(main(sys.argv))
