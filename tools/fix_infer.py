"""Repeatedly runs the project headless and relaxes `var x :=` declarations that
GDScript cannot type-infer, until the parser is happy.

Usage: python tools/fix_infer.py
"""
import os
import re
import subprocess

ROOT = os.path.join(os.path.dirname(__file__), '..')
ERR = re.compile(r'Cannot infer the type of "(\w+)".*?\n\s*at: GDScript::reload \(res://([^:]+):(\d+)\)', re.S)

for it in range(40):
    out = subprocess.run(['godot', '--headless', '--path', ROOT, '--quit-after', '2', '--', '--level=forest1', '--peace'],
                         stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True, encoding='utf-8', errors='replace').stdout
    out += ''
    found = ERR.findall(out)
    if not found:
        print('clean after', it, 'passes')
        break
    for var, path, line in found:
        fp = os.path.join(ROOT, path)
        lines = open(fp, encoding='utf-8').read().split('\n')
        i = int(line) - 1
        new = lines[i].replace(f'var {var} := ', f'var {var} = ', 1)
        if new == lines[i]:
            print('could not fix', path, line, lines[i].strip())
            raise SystemExit(1)
        lines[i] = new
        open(fp, 'w', encoding='utf-8').write('\n'.join(lines))
        print('relaxed', path, line, var)
