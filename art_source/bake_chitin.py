"""Bake the original dune beetle's chitin color and normal maps without dependencies."""

from math import pi, sin, sqrt
from pathlib import Path
from random import Random
import struct
import zlib

OUTPUT = Path(__file__).resolve().parents[1] / "assets/art/materials"
SIZE = 512


def blend(a, b, t):
    return a + (b - a) * t


def smooth(a, b, value):
    t = min(1, max(0, (value - a) / (b - a)))
    return t * t * (3 - 2 * t)


def field(grid, u, v):
    size = len(grid)
    x, y = (u % 1.0) * size, (v % 1.0) * size
    i, j = int(x), int(y)
    u = smooth(0, 1, x - i)
    v = smooth(0, 1, y - j)
    left, right = i, (i + 1) % size
    return blend(blend(grid[j][left], grid[j][right], u),
                 blend(grid[(j + 1) % size][left], grid[(j + 1) % size][right], u), v)


def write_png(path, pixels):
    def chunk(name, data):
        return struct.pack(">I", len(data)) + name + data + struct.pack(">I", zlib.crc32(name + data))

    rows = b"".join(b"\0" + pixels[offset:offset + SIZE * 3] for offset in range(0, len(pixels), SIZE * 3))
    path.write_bytes(b"\x89PNG\r\n\x1a\n"
                     + chunk(b"IHDR", struct.pack(">IIBBBBB", SIZE, SIZE, 8, 2, 0, 0, 0))
                     + chunk(b"IDAT", zlib.compress(rows, 9)) + chunk(b"IEND", b""))


def bake():
    rng = Random(894257)
    broad, grain, pore = ([[rng.random() for _ in range(size)] for _ in range(size)]
                         for size in (12, 51, 127))
    colors = bytearray()
    heights = []
    slate = (45, 57, 64)
    cinnabar = (132, 49, 48)
    for y in range(SIZE):
        v = (y + .5) / SIZE
        for x in range(SIZE):
            u = (x + .5) / SIZE
            mottle = field(broad, u, v)
            small = field(grain, u, v)
            fine = field(pore, u, v)
            warp = .023 * sin(2 * pi * (v * 1.1 + .14)) + .031 * (mottle - .5)
            flank = min(abs(u - .20 - warp), abs(u - .79 - warp))
            stain = (1 - smooth(.027, .135, flank)) * smooth(.10, .68, v)
            stain *= smooth(.16, .62, .72 * small + .28 * fine)
            seam = sin(2 * pi * (v * 43 + .48 * sin(2 * pi * u * 14) + mottle * .70))
            ridges = smooth(.38, .99, seam) * (.44 + .56 * small)
            minerals = smooth(.74, .95, fine) * smooth(.29, .58, small)
            tone = (mottle - .50) * 17 + (small - .46) * 19 + (fine - .50) * 12
            tone += ridges * 8 + minerals * 15
            colors.extend(round(min(255, max(0, blend(a, b, stain) + tone)))
                          for a, b in zip(slate, cinnabar))
            heights.append(.37 * small + .21 * fine + .15 * ridges + .14 * minerals)

    normals = bytearray()
    for y in range(SIZE):
        for x in range(SIZE):
            dx = heights[y * SIZE + (x - 1) % SIZE] - heights[y * SIZE + (x + 1) % SIZE]
            dy = heights[((y - 1) % SIZE) * SIZE + x] - heights[((y + 1) % SIZE) * SIZE + x]
            length = sqrt(dx * dx + dy * dy + .73 * .73)
            normals.extend(round(127.5 + 127.5 * value / length) for value in (dx, dy, .73))

    OUTPUT.mkdir(parents=True, exist_ok=True)
    write_png(OUTPUT / "dune_chitin.png", colors)
    write_png(OUTPUT / "dune_chitin_normal.png", normals)


if __name__ == "__main__":
    bake()
