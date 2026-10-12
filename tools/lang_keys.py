#!/usr/bin/env python3
"""Переводы игры: собирает scripts/core/lang_en.gd из tools/lang_en.tsv
и scripts/core/lang_uk.gd (украинский) из tools/lang_uk.tsv.

Перевод — таблица «русская строка<TAB>английская» (tools/lang_en.tsv). Ключ —
строка текста из кода, как её видит игрок, без отступов по краям; многострочные
тексты переводятся построчно. %s, %d и т. п. — места для подстановки: в переводе
те же и в том же порядке.

    python3 tools/lang_keys.py           # собрать оба словаря и показать, что не переведено
    python3 tools/lang_keys.py --missing # только список непереведённого
"""
import glob
import re
import sys

ROOT = __file__.rsplit('/tools/', 1)[0]
CYR = re.compile('[А-Яа-яЁёІіЇїЄє]')
PH = re.compile(r'%(%|[-+0 #]*\d*(?:\.\d+)?[sdfixXc])')
OUT = 'scripts/core/lang_en.gd'
LANGS = [('en', 'EN', 'Английский'), ('uk', 'UK', 'Украинский')]
## Не текст для игрока: буквы номеров, шаблоны, кусочки для проверки ответов.
SKIP = {'подпись|режим', 'абвгдежзиклмнопрстуфхцчшэюя', 'КМ', 'КИ', 'ХА', 'ДН', 'ЛВ', 'ОД',
        '^([а-яё])(\\d{4})([а-яё]{2})$', 'Сколько стоят', 'за %d', 'долили', 'а 12-34 КМ',
        'Русский', 'Українська',
        # Гласные — ключи формант голоса (sound_library.gd)
        'а', 'о', 'у', 'э', 'и'}


def unescape(t):
    if '\\' not in t:
        return t
    return t.encode('utf-8').decode('unicode_escape').encode('latin-1').decode('utf-8')


def keys():
    """Все русские строки из кода игры — по строкам текста."""
    found = {}
    for f in sorted(glob.glob(ROOT + '/scripts/**/*.gd', recursive=True)):
        if f.endswith('scripts/core/lang_en.gd') or f.endswith('scripts/core/lang_uk.gd') or f.endswith('scripts/core/lang.gd'):
            continue
        src = open(f, encoding='utf-8').read()
        for m in re.finditer(r'"""(.*?)"""', src, re.S):
            for ln in m.group(1).split('\n'):
                k = ln.strip()
                if CYR.search(k) and not k.startswith('//') and k not in SKIP:
                    found.setdefault(k, f)
        src = re.sub(r'"""(.*?)"""', '""', src, flags=re.S)
        in_uk = False
        for line in src.split('\n'):
            if line.strip().startswith('#'):
                continue
            # print() — журнал для разработчика, игрок его не видит
            if re.match(r'\s*print(err)?\(', line):
                continue
            # Готовый украинский текст в коде (const ..._UK := [...]) — не ключ
            if re.match(r'\s*const \w+_UK\b', line):
                in_uk = True
            if in_uk:
                if line.strip() == ']':
                    in_uk = False
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


def table(code='en'):
    out = {}
    for line in open(ROOT + '/tools/lang_%s.tsv' % code, encoding='utf-8'):
        line = line.rstrip('\n')
        if '\t' in line:
            ru, en = line.split('\t', 1)
            out[ru] = en
    return out


def gd(s):
    return '"' + s.replace('\\', '\\\\').replace('"', '\\"') + '"'


def main():
    ks = keys()
    for code, const, title in LANGS:
        tr = table(code)
        missing = [k for k in ks if k not in tr]
        print('== %s' % title)
        if '--missing' not in sys.argv:
            bad = 0
            for ru, en in tr.items():
                if PH.findall(ru) != PH.findall(en):
                    print('Подстановки не совпадают:', ru, '|', en)
                    bad += 1
            with open(ROOT + '/scripts/core/lang_%s.gd' % code, 'w', encoding='utf-8') as w:
                w.write('extends RefCounted\n'
                        '## %s перевод: русская строка (как в коде, строка текста без\n'
                        '## отступов по краям) → перевод. %%s, %%d — места для подстановки, по\n'
                        '## порядку как в русской. Собирается из tools/lang_%s.tsv:\n'
                        '## python3 tools/lang_keys.py\n\nconst %s := {\n' % (title, code, const))
                for ru, en in tr.items():
                    w.write('\t%s: %s,\n' % (gd(ru), gd(en)))
                w.write('}\n')
            print('Переведено строк: %d, ошибок подстановок: %d' % (len(tr), bad))
        print('Не переведено: %d' % len(missing))
        for k in missing[:400]:
            print('  %s\t(%s)' % (k, ks[k].split('/scripts/')[-1]))

main()
