#!/usr/bin/env python3
"""Английский перевод игры: собирает scripts/core/lang_en.gd из tools/lang_en.tsv.

Перевод — таблица «русская строка<TAB>английская» (tools/lang_en.tsv). Ключ —
строка текста из кода, как её видит игрок, без отступов по краям; многострочные
тексты переводятся построчно. %s, %d и т. п. — места для подстановки: в переводе
те же и в том же порядке.

    python3 tools/lang_keys.py           # собрать lang_en.gd и показать, что не переведено
    python3 tools/lang_keys.py --missing # только список непереведённого
"""
import glob
import re
import sys

ROOT = __file__.rsplit('/tools/', 1)[0]
CYR = re.compile('[А-Яа-яЁёІіЇїЄє]')
PH = re.compile(r'%(%|[-+0 #]*\d*(?:\.\d+)?[sdfixXc])')
OUT = 'scripts/core/lang_en.gd'
## Не текст для игрока: буквы номеров, шаблоны, кусочки для проверки ответов.
SKIP = {'подпись|режим', 'абвгдежзиклмнопрстуфхцчшэюя', 'КМ', 'КИ', 'ХА', 'ДН', 'ЛВ', 'ОД',
        '^([а-яё])(\\d{4})([а-яё]{2})$', 'Сколько стоят', 'за %d', 'долили', 'а 12-34 КМ',
        'Русский'}


def unescape(t):
    if '\\' not in t:
        return t
    return t.encode('utf-8').decode('unicode_escape').encode('latin-1').decode('utf-8')


def keys():
    """Все русские строки из кода игры — по строкам текста."""
    found = {}
    for f in sorted(glob.glob(ROOT + '/scripts/**/*.gd', recursive=True)):
        if f.endswith(OUT) or f.endswith('scripts/core/lang.gd'):
            continue
        src = open(f, encoding='utf-8').read()
        for m in re.finditer(r'"""(.*?)"""', src, re.S):
            for ln in m.group(1).split('\n'):
                k = ln.strip()
                if CYR.search(k) and not k.startswith('//') and k not in SKIP:
                    found.setdefault(k, f)
        src = re.sub(r'"""(.*?)"""', '""', src, flags=re.S)
        for line in src.split('\n'):
            if line.strip().startswith('#'):
                continue
            for m in re.finditer(r'"((?:[^"\\]|\\.)*)"', line):
                t = m.group(1)
                if not CYR.search(t):
                    continue
                try:
                    t = unescape(t)
                except Exception:
                    pass
                for ln in t.split('\n'):
                    k = ln.strip()
                    if CYR.search(k) and not k.startswith('//') and k not in SKIP:
                        found.setdefault(k, f)
    return found


def table():
    out = {}
    for line in open(ROOT + '/tools/lang_en.tsv', encoding='utf-8'):
        line = line.rstrip('\n')
        if '\t' in line:
            ru, en = line.split('\t', 1)
            out[ru] = en
    return out


def gd(s):
    return '"' + s.replace('\\', '\\\\').replace('"', '\\"') + '"'


def main():
    tr = table()
    ks = keys()
    missing = [k for k in ks if k not in tr]
    if '--missing' not in sys.argv:
        bad = 0
        for ru, en in tr.items():
            if PH.findall(ru) != PH.findall(en):
                print('Подстановки не совпадают:', ru, '|', en)
                bad += 1
        with open(ROOT + '/' + OUT, 'w', encoding='utf-8') as w:
            w.write('extends RefCounted\n'
                    '## Английский перевод: русская строка (как в коде, строка текста без\n'
                    '## отступов по краям) → английская. %s, %d — места для подстановки, по\n'
                    '## порядку как в русской. Собирается из tools/lang_en.tsv:\n'
                    '## python3 tools/lang_keys.py\n\nconst EN := {\n')
            for ru, en in tr.items():
                w.write('\t%s: %s,\n' % (gd(ru), gd(en)))
            w.write('}\n')
        print('Переведено строк: %d, ошибок подстановок: %d' % (len(tr), bad))
    print('Не переведено: %d' % len(missing))
    for k in missing:
        print('  %s\t(%s)' % (k, ks[k].split('/scripts/')[-1]))


main()
