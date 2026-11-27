"""Bake chitin color, chitin normals and wing membranes without dependencies."""

from math import cos, pi, sin, sqrt
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


def plate_field(grid, u, v):
    rows, columns = len(grid), len(grid[0])
    x, y = (u % 1.0) * columns, (v % 1.0) * rows
    i, j = int(x), int(y)
    nearest = following = 9.0
    tone = .5
    for row in range(j - 1, j + 2):
        for column in range(i - 1, i + 2):
            dx, dy, shade = grid[row % rows][column % columns]
            distance = (x - column - dx) ** 2 + (y - row - dy) ** 2
            if distance < nearest:
                nearest, following = distance, nearest
                tone = shade
            elif distance < following:
                following = distance
    return sqrt(following) - sqrt(nearest), tone


def write_png(path, pixels, alpha=False):
    def chunk(name, data):
        return struct.pack(">I", len(data)) + name + data + struct.pack(">I", zlib.crc32(name + data))

    stride = SIZE * (4 if alpha else 3)
    rows = b"".join(b"\0" + pixels[offset:offset + stride] for offset in range(0, len(pixels), stride))
    path.write_bytes(b"\x89PNG\r\n\x1a\n"
                     + chunk(b"IHDR", struct.pack(">IIBBBBB", SIZE, SIZE, 8, 6 if alpha else 2, 0, 0, 0))
                     + chunk(b"IDAT", zlib.compress(rows, 9)) + chunk(b"IEND", b""))


def bake():
    rng = Random(894257)
    broad, grain, pore = ([[rng.random() for _ in range(size)] for _ in range(size)]
                         for size in (9, 59, 151))
    plates = [[(rng.uniform(.16, .84), rng.uniform(.16, .84), rng.random())
               for _ in range(37)] for _ in range(27)]
    colors = bytearray()
    heights = []
    umber = (107, 68, 44)
    ochre = (195, 145, 100)
    for y in range(SIZE):
        v = (y + .5) / SIZE
        for x in range(SIZE):
            u = (x + .5) / SIZE
            mottle = field(broad, u, v)
            small = field(grain, u, v)
            fine = field(pore, u, v)
            margin, plate = plate_field(plates, u + .013 * (mottle - .5), v + .017 * (small - .5))
            groove = 1 - smooth(.012, .084, margin)
            rim = (1 - smooth(.073, .205, margin)) * (1 - groove)
            growth = sin(2 * pi * (v * 39 + .65 * sin(2 * pi * u * 5) + mottle * .61))
            ridges = smooth(.46, .99, growth) * smooth(.24, .75, small)
            pits = smooth(.77, .96, fine) * smooth(.32, .60, small)
            pigment = .24 + mottle * .40 + plate * .14 + .25 * cos(2 * pi * u)
            tone = (small - .50) * 17 + (fine - .50) * 8 + rim * 9 + ridges * 7
            tone -= groove * 15 + pits * 16
            colors.extend(round(min(255, max(0, blend(a, b, pigment) + tone)))
                          for a, b in zip(umber, ochre))
            heights.append(.15 * small + .10 * fine + .12 * ridges + .11 * rim - .18 * groove - .11 * pits)

    normals = bytearray()
    for y in range(SIZE):
        for x in range(SIZE):
            dx = heights[y * SIZE + (x - 1) % SIZE] - heights[y * SIZE + (x + 1) % SIZE]
            dy = heights[((y - 1) % SIZE) * SIZE + x] - heights[((y + 1) % SIZE) * SIZE + x]
            length = sqrt(dx * dx + dy * dy + .68 * .68)
            normals.extend(round(127.5 + 127.5 * value / length) for value in (dx, dy, .68))

    OUTPUT.mkdir(parents=True, exist_ok=True)
    write_png(OUTPUT / "dune_chitin.png", colors)
    write_png(OUTPUT / "dune_chitin_normal.png", normals)


def bake_wing():
    rng = Random(736218)
    grain = [[rng.random() for _ in range(19)] for _ in range(19)]
    cells = [[(rng.uniform(.19, .81), rng.uniform(.19, .81), rng.random())
              for _ in range(41)] for _ in range(24)]
    rgba = bytearray()
    for y in range(SIZE):
        v = (y + .5) / SIZE
        for x in range(SIZE):
            u = (x + .5) / SIZE
            grain_value = field(grain, u, v)
            margin, tint = plate_field(cells, u + .007 * sin(v * 18), v + .018 * sin(u * 23))
            vein = 1 - smooth(.013, .10, margin)
            edge = 1 - smooth(.006, .095, min(v, 1 - v))
            pigment = .48 * grain_value + .28 * tint + .24 * vein
            rgba.extend((round(158 + 61 * pigment), round(95 + 65 * pigment), round(49 + 46 * pigment),
                         round(53 + 40 * grain_value + 54 * vein + 61 * edge)))
    OUTPUT.mkdir(parents=True, exist_ok=True)
    write_png(OUTPUT / "dune_wing.png", rgba, alpha=True)


if __name__ == "__main__":
    bake()
    bake_wing()
