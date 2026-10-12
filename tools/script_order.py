#!/usr/bin/env python3
"""Порядок сборки скриптов при запуске: scripts/core/script_order.gd.

В браузере и на телефоне экран загрузки (boot.gd) собирает скрипты по одному
за кадр — иначе сборка всего мира разом замораживала страницу на десятки
секунд. Скрипт тянет за собой всё, на что ссылается (имена классов, preload),
поэтому порядок — от листьев к корню: зависимости раньше, чем те, кто их
использует. Тогда каждый кадр собирает один скрипт, а не полмира.

    python3 tools/script_order.py          # пересобрать список
    python3 tools/script_order.py --check  # только проверить, что он свежий
    python3 tools/script_order.py --groups # показать круги ссылок (собираются разом)

Зовётся из tools/build_release.sh; тест test_staged проверяет, что список
не отстал от скриптов.
"""
import glob
import os
import re
import sys

ROOT = __file__.rsplit('/tools/', 1)[0]
OUT = 'scripts/core/script_order.gd'


def deps_of():
    files = sorted(f for f in glob.glob('scripts/**/*.gd', recursive=True) if f != OUT)
    classes = {}
    for f in files:
        for line in open(f, encoding='utf-8'):
            m = re.match(r'class_name\s+(\w+)', line)
            if m:
                classes[m.group(1)] = f
    deps = {}
    for f in files:
        s = open(f, encoding='utf-8').read()
        # Строки и комментарии — не ссылки (кроме путей res://)
        s = re.sub(r'"(?:[^"\\\n]|\\.)*"', lambda m: m.group(0) if 'res://' in m.group(0) else '""', s)
        s = re.sub(r'#[^\n]*', '', s)
        words = set(re.findall(r'\b[A-Z]\w*\b', s))
        d = [classes[c] for c in sorted(words) if c in classes and classes[c] != f]
        d += [p for p in re.findall(r'preload\("res://([^"]+\.gd)"\)', s) if os.path.exists(p)]
        deps[f] = d
    return files, deps


def order():
    """Тарьян: группы скриптов, ссылающихся друг на друга по кругу, выходят
    после всех своих зависимостей. Такая группа собирается разом — когда
    грузится первый её скрипт."""
    files, deps = deps_of()
    index, low, stack, on_stack, out = {}, {}, [], set(), []

    def visit(f):
        index[f] = low[f] = len(index)
        stack.append(f)
        on_stack.add(f)
        for d in deps[f]:
            if d not in index:
                visit(d)
                low[f] = min(low[f], low[d])
            elif d in on_stack:
                low[f] = min(low[f], index[d])
        if low[f] == index[f]:
            group = []
            while True:
                g = stack.pop()
                on_stack.discard(g)
                group.append(g)
                if g == f:
                    break
            out.extend(sorted(group))
            if '--groups' in sys.argv and len(group) > 1:
                lines = sum(open(g, encoding='utf-8').read().count('\n') for g in group)
                print('круг из %d скриптов, %d строк: %s' % (len(group), lines, ' '.join(os.path.basename(g) for g in sorted(group))))

    sys.setrecursionlimit(10000)
    for f in files:
        if f not in index:
            visit(f)
    return out


def render(paths):
    lines = ['extends RefCounted',
             '## Порядок сборки скриптов на экране загрузки: зависимости раньше тех,',
             '## кто их использует. Создан tools/script_order.py — руками не править.',
             '',
             'const PATHS := [']
    lines += ['\t"res://%s",' % p for p in paths]
    lines += [']', '']
    return '\n'.join(lines)


def main():
    os.chdir(ROOT)
    text = render(order())
    old = open(OUT, encoding='utf-8').read() if os.path.exists(OUT) else ''
    if '--check' in sys.argv:
        if old != text:
            print('script_order.gd устарел: python3 tools/script_order.py')
            sys.exit(1)
        print('script_order.gd свежий')
        return
    if old != text:
        open(OUT, 'w', encoding='utf-8').write(text)
    print('%s: %d скриптов' % (OUT, text.count('"res://')))


main()
