"""Bake the original carapaces and moving parts for the six special beetles."""

from math import cos, pi, sin
from random import Random

from bake_chitin import OUTPUT, SIZE, field, plate_field, smooth, write_png
from build_models import MATERIALS, Model, cuticle_loft, flying_beetle, mix, norm

MATERIALS.update({
    "DuneSiegeChitin": ("e5d4b9", 0.02, 0.53),
    "DunePlateEdge": ("fbdfbd", 0.02, 0.49),
    "DuneTendon": ("775136", 0.0, 0.72),
    "DuneSac": ("e8a359", 0.0, 0.34),
    "DuneSacVein": ("a45e34", 0.0, 0.44),
})


def grow(model, sections, **options):
    options.setdefault("finish", "DuneSiegeChitin")
    options.setdefault("sides", 16)
    options.setdefault("lip", True)
    cuticle_loft(model, sections, **options)


def armor_scute(model, side, z, crown, width, index):
    outline = [(.09, -.14), (.38, -.17), (.69, -.15), (.90, -.087), (1.02, .032),
               (1.075, .162), (1.03, .283), (.93, .233), (.81, .260), (.69, .219),
               (.53, .231), (.36, .197), (.19, .223), (.04, .107)]
    center_x, center_z = .47, .021
    rings = []
    for scale, relief in ((1.0, 0.025), (.94, .083), (.72, .122), (.35, .136)):
        ring = []
        for edge, (x, depth) in enumerate(outline):
            x = center_x + (x - center_x) * scale
            depth = center_z + (depth - center_z) * scale
            height = crown + relief - (.082 + .010 * cos(index)) * x - .16 * x ** 3 - .26 * max(0.0, depth)
            height += (.015 * sin(edge * 1.4 + index) + .009 * cos(edge * 4.1)) * scale
            ring.append((side * x * width, height, z + depth))
        rings.append(ring)
    for band, (outer, inner) in enumerate(zip(rings, rings[1:])):
        for edge in range(len(outline)):
            following = (edge + 1) % len(outline)
            points = [outer[edge], outer[following], inner[following], inner[edge]]
            if band == 0:
                model.face("DunePlateEdge", points, (side * .32, .8, .11))
            else:
                uvs = [(abs(point[0]) / width * .63 + .12 * side, (point[2] - z) * 1.58 + .16 + index * .067)
                       for point in points]
                model.face("DuneSiegeChitin", points, (0, 1, 0), normals=[(0, 1, 0)] * 4, uv=uvs)
    model.face("DuneSiegeChitin", rings[-1], (0, 1, 0), normals=[(0, 1, 0)] * len(outline),
               uv=[(abs(point[0]) / width * .63 + .12 * side, (point[2] - z) * 1.58 + .16 + index * .067) for point in rings[-1]])


def siege_shell(role):
    model = Model(f"{role}_shell", 1.7)
    tank, ram = role == "tank", role == "ram"
    scale = (2.4, 1.71, 1.83) if tank else (1.34, 1.13, 1.12) if ram else (1.02, .99, 1.04)
    brow = -1.39 if ram else -1.03 if tank else -.95
    back = .88 if tank else .71
    head = [
        ((0, .45, brow), .009, .008),
        ((0, .47, brow + .13), .16 if ram else .25, .065),
        ((0, .55, -.95 if ram else -.83), .31, .19),
        ((0, .66, -.60), .41, .27),
        ((0, .65, -.33), .37, .24),
    ]
    grow(model, head, sides=22, ridged=ram, uv_span=(.09, .55))
    if ram:
        for side in (-1, 1):
            grow(model, [((side * .035, .484, -1.40), .005, .004),
                         ((side * .13, .528, -1.23), .049, .071),
                         ((side * .24, .606, -.99), .092, .099),
                         ((side * .384, .729, -.69), .074, .139),
                         ((side * .415, .839, -.44), .005, .007)],
                 sides=18, ridged=True, finish="DunePlateEdge", uv_span=(.15, .62))
    grow(model, [
        ((0, .46, -.77), .26, .19), ((0, .48, -.43), .41, .29),
        ((0, .46, -.06), .53 if tank else .45, .355), ((0, .45, .43), .51 if tank else .41, .35),
        ((0, .45, back), .26, .18), ((0, .43, back + .12), .028, .10),
    ], sides=24, axis=(0, 0, 1), finish="DuneTendon", lip=False)
    count = 7 if tank else 5 if ram else 6
    for index in range(count):
        t = index / (count - 1)
        z = -.64 + t * (back + .56)
        wide = (.42 + sin((t + .16) * pi) * .14) * (1.10 if tank else 1.0)
        top = .71 + sin((t + .04) * pi) * (.24 if tank else .10)
        grow(model, [
            ((0, top - .13, z - .14), wide * .81, .16),
            ((0, top - .10, z - .065), wide * .98, .24),
            ((0, top - .085, z + .055), wide * 1.04, .24),
            ((0, top - .105, z + .17), wide * .99, .179),
            ((0, top - .16, z + .245), wide * .95, .102),
            ((0, top - .18, z + .285), wide * .79, .045),
        ], sides=28, axis=(0, 0, 1), ridged=ram, uv_span=(.16 + t * .40, .34 + t * .55))
        for side in (-1, 1):
            x = wide * side
            if tank or index > 1:
                armor_scute(model, side, z, top + (.068 if ram else .12), wide, index)
            grow(model, [
                ((x * .67, top + .05, z - .13), .066, .034),
                ((x * .91, top - .035, z - .075), .108, .085),
                ((x * 1.02, top - .17, z + .06), .134, .106),
                ((x * 1.02, top - .29, z + .16), .108, .066),
                ((x * 1.01, top - .32, z + .28 + .05 * cos(index)), .005, .005),
            ], sides=12, uv_span=(.07 + t * .44, .39 + t * .50))
            grow(model, [
                ((x * .94, .39, z - .05), .055, .022),
                ((x * 1.02, .32, z + .075), .065, .037),
                ((x * .94, .26, z + .169), .002, .006),
            ], sides=10, finish="DunePlateEdge", uv_span=(.53, .77))
            if tank:
                grow(model, [((x * .85, top - .09, z - .108), .040, .029),
                             ((x * 1.025, top - .193, z + .026), .093, .056),
                             ((x * 1.085, top - .240, z + .126), .093, .043),
                             ((x * 1.156, top - .277, z + .248), .009, .005)],
                     sides=12, ridged=True, finish="DunePlateEdge", uv_span=(.21 + t * .38, .43 + t * .48))
    for side in (-1, 1):
        for x, z in ((.29, -.51), (.39, -.09), (.35, .47)):
            model.ellipsoid("DuneTendon", (x * side, .49, z), (.16, .145, .147), sides=14, rows=8)
        grow(model, [
            ((side * .24, .48, -.81), .006, .006), ((side * .278, .493, -.737), .020, .019),
            ((side * .298, .515, -.670), .023, .017), ((side * .309, .522, -.638), .008, .006),
        ], sides=12, finish="DuneEyeLamp")
        grow(model, [
            ((side * .14, .33, -.76), .086, .060), ((side * .207, .302, -.86), .070, .068),
            ((side * .186, .245, -.984), .051, .038), ((side * .108, .190, -1.075), .006, .004),
        ], sides=12, uv_span=(.17, .68))
    for finish, vertices in model.faces.items():
        model.faces[finish] = [
            (tuple(value * factor for value, factor in zip(point, scale)),
             norm(tuple(value / factor for value, factor in zip(normal, scale))), uv)
            for point, normal, uv in vertices
        ]
    return model


def siege_limb(front):
    model = Model("siege_claw" if front else "siege_leg", 2.1)
    reach = -.25 if front else .08
    path = [
        ((-.085, -.037, .035), .083, .091), ((.04, -.029, .003), .126, .109),
        ((.22, -.063, reach * .30), .118, .097), ((.37, -.104, reach * .64), .118, .106),
        ((.47, -.205, reach * .84), .126, .101), ((.56, -.339, reach), .106, .071),
        ((.58, -.469, reach + .010), .053, .039), ((.62, -.53, reach - .040), .006, .008),
    ]
    grow(model, path, uv_span=(.12, .88), sides=22, finish="DuneTendon")
    for index, (near, far) in enumerate(zip(path[1:], path[2:])):
        a, width, height = near
        b, _, _ = far
        grow(model, [(mix(a, b, -.19), width * .76, height * .76),
                     (mix(a, b, .21), width * 1.16, height * 1.23),
                     (mix(a, b, .73), width * 1.10, height * 1.08),
                     (mix(a, b, 1.34), .018, .017)],
             up=(1, .4, .28), sides=18, ridged=True, uv_span=(.24 + index * .075, .47 + index * .075))
    return model


def catapult_parts():
    tail = Model("catapult_tail", 1.8)
    path = [(0, -.025, -.08), (0, .038, .14), (0, .16, .33), (0, .305, .52),
            (0, .423, .67), (0, .504, .82), (0, .53, .96)]
    for index, (a, b) in enumerate(zip(path, path[1:])):
        width = .23 - .018 * index
        grow(tail, [(mix(a, b, -.24), width * .73, width * .71), (mix(a, b, .18), width, width * .88),
                    (mix(a, b, .73), width * .91, width * .72), (mix(a, b, 1.27), width * .61, width * .54)],
             sides=22, uv_span=(.21 + index * .062, .47 + index * .052), ridged=True)
        for side in (-1, 1):
            p = mix(a, b, .62)
            grow(tail, [((side * width * .67, p[1], p[2]), .044, .035),
                        ((side * width * .98, p[1] + .012, p[2] + .075), .037, .043),
                        ((side * width * .79, p[1] + .065, p[2] + .17), .002, .002)],
                 sides=10, finish="DunePlateEdge", uv_span=(.41, .72))
    scoop = Model("catapult_scoop", 1.85)
    rings = []
    for breadth, length, height in ((.052, .074, -.045), (.18, .28, -.065), (.27, .40, .04),
                                     (.29, .44, .14), (.241, .37, .13), (.16, .26, .036), (.035, .05, .025)):
        rings.append([(cos(a) * breadth * (1.0 + .08 * sin(5 * a)),
                       height + (0.036 * cos(5 * a) + .085 * sin(a)) * breadth / .29,
                       .135 + sin(a) * length) for a in (i * 2 * pi / 30 for i in range(30))])
    for row, (lower, upper) in enumerate(zip(rings, rings[1:])):
        for index in range(len(lower)):
            adjacent = (index + 1) % len(lower)
            facing = (lower[index][0], -1 if row == 0 else 1 if row > 2 else -.25, lower[index][2] - .135)
            scoop.face("DunePlateEdge" if row == 3 else "DuneSiegeChitin",
                       [lower[index], lower[adjacent], upper[adjacent], upper[index]], facing)
    return tail, scoop


def quill(model, base, direction, length, width):
    tip = tuple(a + b * length for a, b in zip(base, direction))
    curve = tuple(a + b for a, b in zip(mix(base, tip, .74), (0, .023, 0)))
    grow(model, [(base, width * .78, width * .74), (mix(base, tip, .19), width, width),
                 (mix(base, tip, .43), width * .82, width * .72), (curve, width * .43, width * .39),
                 (tip, .0018, .0014)], sides=14, ridged=True, finish="DunePlateEdge", uv_span=(.14, .91))


def shooter_parts():
    organs = Model("shooter_quills", 2.2)
    for side in (-1, 1):
        for index in range(4):
            x = .21 + .027 * index
            z = -.31 + .227 * index
            y = .83 + .035 * sin(index * .93)
            grow(organs, [((x * side, y - .17, z - .11), .060, .067),
                          ((x * side, y - .02, z - .02), .096, .090),
                          (((x + .034) * side, y + .095, z + .07), .086, .069),
                          (((x + .045) * side, y + .11, z + .11), .030, .027)],
                 finish="DuneTendon", sides=16, uv_span=(.30, .70))
            quill(organs, ((x + .028) * side, y + .067, z + .056), (.23 * side, .68, .64), .50 - index * .045, .064)
    dart = Model("bug_quill", 2.1)
    quill(dart, (0, 0, .15), (0, 0, -1), .52, .022)
    return organs, dart


def winged_shell(small):
    model = flying_beetle()
    model.name = "kamikaze_shell" if small else "transporter_shell"
    scale = (.76, .95, .81) if small else (1.79, 1.29, 1.58)
    for finish, vertices in model.faces.items():
        model.faces[finish] = [
            ((x * scale[0], .64 + (y - .64) * scale[1], z * scale[2]),
             norm((nx / scale[0], ny / scale[1], nz / scale[2])), uv)
            for (x, y, z), (nx, ny, nz), uv in vertices
        ]
    for side in (-1, 1):
        for index in range(3):
            z = -.31 + index * (.20 if small else .34)
            x = side * (.20 if small else .41)
            grow(model, [((x * .78, .78, z - .16), .039, .038),
                         ((x * .98, .789, z - .045), .089, .079),
                         ((x * 1.18, .762, z + .10), .085, .076),
                         ((x * 1.15, .69, z + .245), .005, .006)],
                 sides=14, uv_span=(.20 + index * .13, .56 + index * .14), ridged=True)
            if not small:
                grow(model, [((x * .33, 1.02, z - .15), .036, .032),
                             ((x * .63, 1.02, z - .09), .124, .075),
                             ((x * 1.06, .961, z + .04), .146, .084),
                             ((x * 1.42, .847, z + .22), .080, .059),
                             ((x * 1.67, .789, z + .31), .007, .007)],
                     sides=20, finish="DunePlateEdge", uv_span=(.08 + index * .18, .54 + index * .16))
    return model


def kamikaze_sac():
    model = Model("kamikaze_sac", 1.7)
    grow(model, [((0, .005, -.035), .086, .088), ((0, -.012, .11), .13, .132),
                 ((0, -.060, .29), .205, .176), ((0, -.12, .46), .29, .245),
                 ((0, -.152, .63), .295, .257), ((0, -.189, .80), .241, .204),
                 ((0, -.24, .96), .145, .115), ((0, -.278, 1.099), .008, .007)],
         sides=32, axis=(0, 0, 1), lip=False, finish="DuneSac", uv_span=(.18, .91))
    for index in range(5):
        z = .12 + index * .145
        w = (.13, .186, .263, .294, .245)[index]
        for side in (-1, 1):
            grow(model, [((0, w * .44 + .056, z - .045), .028, .022), ((side * w * .65, w * .23 + .04, z), .037, .028),
                         ((side * w * .97, -w * .43, z + .047), .023, .022),
                         ((side * w * .73, -w * .98, z + .104), .005, .005)],
                 sides=10, finish="DuneSacVein", uv_span=(.33, .70))
    return model


def transporter_parts():
    tail = Model("transporter_tail", 1.9)
    points = [(0, 0, -.10), (0, -.035, .11), (0, -.106, .36), (0, -.221, .59),
              (0, -.36, .74), (0, -.54, .79), (0, -.72, .75)]
    for index, (a, b) in enumerate(zip(points, points[1:])):
        w = .30 - .032 * index
        grow(tail, [(mix(a, b, -.23), w * .72, w * .59), (mix(a, b, .13), w, w * .77),
                    (mix(a, b, .76), w * .91, w * .70), (mix(a, b, 1.30), w * .55, w * .43)],
             sides=20, uv_span=(.20 + index * .08, .44 + index * .07), ridged=True)
    grip = Model("transporter_grip", 2.2)
    grow(grip, [((-.08, .03, .02), .090, .086), ((.08, -.12, .076), .108, .103),
                ((.245, -.31, .16), .119, .100), ((.22, -.49, .12), .085, .083),
                ((.146, -.61, .02), .066, .066), ((.015, -.70, -.04), .025, .026)],
         sides=20, uv_span=(.23, .80), finish="DuneTendon")
    grow(grip, [((.06, -.10, .049), .067, .071), ((.21, -.24, .149), .102, .092),
                ((.263, -.34, .167), .119, .111), ((.252, -.42, .107), .074, .060),
                ((.159, -.48, .061), .005, .005)], sides=18, ridged=True, uv_span=(.28, .91))
    for z in (-.056, .095):
        grow(grip, [((.206, -.49, z), .056, .058), ((.14, -.635, z - .04), .069, .061),
                    ((.038, -.752, z - .145), .054, .050), ((-.102, -.786, z - .21), .007, .006)],
            sides=16, finish="DunePlateEdge", uv_span=(.14, .86))
    return tail, grip


def surface_maps():
    rng = Random(894257)
    broad, grain, pore = ([[rng.random() for _ in range(size)] for _ in range(size)] for size in (9, 59, 151))
    plates = [[(rng.uniform(.16, .84), rng.uniform(.16, .84), rng.random()) for _ in range(37)] for _ in range(27)]
    roughness, occlusion = bytearray(), bytearray()
    for y in range(SIZE):
        v = (y + .5) / SIZE
        for x in range(SIZE):
            u = (x + .5) / SIZE
            mottle, small, fine = field(broad, u, v), field(grain, u, v), field(pore, u, v)
            margin, _ = plate_field(plates, u + .013 * (mottle - .5), v + .017 * (small - .5))
            seam = 1.0 - smooth(.012, .165, margin)
            roughness.extend([round(103 + mottle * 42 + seam * 20 + fine * 16)] * 3)
            occlusion.extend([round(251 - seam * 67 - max(0.0, fine - .74) * 63)] * 3)
    write_png(OUTPUT / "dune_siege_roughness.png", roughness)
    write_png(OUTPUT / "dune_siege_occlusion.png", occlusion)


if __name__ == "__main__":
    for asset in (siege_shell("tank"), siege_shell("ram"), siege_shell("catapult"), siege_limb(False),
                  siege_limb(True), *catapult_parts(), *shooter_parts(), winged_shell(True),
                  kamikaze_sac(), winged_shell(False), *transporter_parts()):
        asset.write()
    surface_maps()
