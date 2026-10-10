#!/usr/bin/env python3
"""Копия движка (index.wasm) с другой начальной памятью.

На iPhone Safari память WebAssembly лучше всего даётся сразу при запуске:
каждое наращивание потом — новый сплошной кусок, и не нашлось — iOS молча
закрывает страницу. Движок Godot стартует с 32 МБ и растёт ступенями;
для iPhone делаем копию, где память с самого начала нужного размера.

    python3 tools/wasm_memory.py docs/index.wasm out.wasm 288   # МБ
    python3 tools/wasm_memory.py --show docs/index.wasm
"""
import sys

PAGE = 65536


def leb_read(b, i):
    r = s = 0
    while True:
        x = b[i]
        i += 1
        r |= (x & 0x7F) << s
        s += 7
        if x < 0x80:
            return r, i


def leb_write(v):
    out = bytearray()
    while True:
        x = v & 0x7F
        v >>= 7
        if v:
            out.append(x | 0x80)
        else:
            out.append(x)
            return bytes(out)


def memory_section(b):
    """(начало раздела, начало содержимого, конец, флаги, min, max) раздела памяти."""
    assert b[:4] == b"\0asm", "не wasm"
    i = 8
    while i < len(b):
        sid = b[i]
        size, j = leb_read(b, i + 1)
        if sid == 5:
            n, k = leb_read(b, j)
            assert n == 1, "ждали одну память"
            flags = b[k]
            mn, k = leb_read(b, k + 1)
            mx = None
            if flags & 1:
                mx, k = leb_read(b, k)
            return i, j, j + size, flags, mn, mx
        i = j + size
    raise SystemExit("в движке нет раздела памяти")


def patch(b, mb):
    start, body, end, flags, mn, mx = memory_section(b)
    pages = mb * 1024 * 1024 // PAGE
    assert mx is None or pages <= mx, "больше максимума движка"
    payload = leb_write(1) + bytes([flags]) + leb_write(pages) + (leb_write(mx) if mx is not None else b"")
    return b[:start] + bytes([5]) + leb_write(len(payload)) + payload + b[end:]


if __name__ == "__main__":
    if sys.argv[1] == "--show":
        _, _, _, flags, mn, mx = memory_section(open(sys.argv[2], "rb").read())
        print("память: начало %d МБ, максимум %s МБ" % (mn * PAGE >> 20, (mx * PAGE >> 20) if mx else "—"))
        sys.exit(0)
    src, dst, mb = sys.argv[1], sys.argv[2], int(sys.argv[3])
    data = patch(open(src, "rb").read(), mb)
    open(dst, "wb").write(data)
    _, _, _, _, mn, _ = memory_section(data)
    print("%s: память с начала %d МБ" % (dst, mn * PAGE >> 20))
