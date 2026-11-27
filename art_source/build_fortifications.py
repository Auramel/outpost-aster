"""Bake the outpost's new structures, ammunition and cliff nests."""

from math import cos, pi, sin
from random import Random

from build_models import MATERIALS, Model, rivet, turret_cartridge

MATERIALS.update({
    "Brass": ("ba8961", .68, .48),
    "ShellTip": ("9e5846", .56, .53),
    "HospitalEnamel": ("bdc8c3", .36, .61),
    "HospitalRed": ("9e5148", .21, .70),
})


def facade():
    m = Model("fortification_facade", .44)
    m.profile("BunkerConcrete", [(0, .28), (1.05, .48), (5.68, .10),
                                 (9.81, -.66), (11.39, -1.14), (11.61, -4.78),
                                 (0, -4.78)], 6.64, .11)
    m.block("BunkerRim", (0, 10.77, -.94), (6.70, .25, .62), .053, axis=1)
    m.block("BunkerArmor", (0, 9.45, -.43), (6.70, .48, .51), .069, axis=1)
    m.block("Graphite", (0, 9.12, -.24), (6.56, .16, .29), .022, axis=1)
    for x in (-2.92, 0, 2.92):
        m.profile("BunkerArmor", [(.06, .30), (.22, .79), (1.51, .73), (5.07, .24),
                                   (8.46, -.10), (9.73, -.37), (9.86, -.67), (.04, -.33)],
                  .62 if x else .46, .071, center=(x, 0, 0))
        for height, z in ((1.32, .76), (4.83, .29), (8.41, -.08)):
            m.block("BunkerRim", (x, height, z), (.40, .13, .055), .012, axis=2)
            for side in (-1, 1):
                rivet(m, (x + side * .165, height, z + .035), (0, 0, 1), .033)
    for x in (-1.54, 1.54):
        m.block("Graphite", (x, 2.13, .397), (2.34, 2.77, .13), .11, axis=2)
        m.block("BunkerArmor", (x, 2.08, .478), (2.15, 2.55, .115), .09, axis=2)
        for side in (-1, 1):
            m.block("BunkerRim", (x + side * .91, 2.10, .55), (.105, 2.18, .055), .013, axis=2)
            for y in (1.26, 2.09, 3.04):
                rivet(m, (x + side * .89, y, .59), (0, 0, 1), .026)
        m.block("Graphite", (x, 7.54, -.103), (2.15, .81, .18), .057, axis=2)
        for row in range(5):
            m.block("BunkerRim", (x, 7.29 + row * .108, .013), (1.89, .053, .083), .010, axis=2)
        m.block("BunkerArmor", (x, 4.97, .21), (2.56, .27, .50), .033, axis=1)
        for dx in (-.78, .78):
            m.tube("Graphite", (x + dx, .58, .57), (x + dx, 1.06, .57), .044, .044, sides=10)
    for x in (-2.41, 2.41):
        m.tube("Graphite", (x, 4.02, .20), (x, 8.65, -.15), .060, .057, sides=12)
        for y in (4.41, 5.36, 6.51, 7.89):
            m.block("BunkerRim", (x, y, .29 - (y - 4) * .073), (.24, .11, .12), .016, axis=2)
    return m


def turret_platform():
    m = Model("facade_turret_platform", .78)
    m.block("Graphite", (0, -.31, 0), (3.78, .23, 3.72), .075, axis=1)
    m.block("BunkerArmor", (0, -.115, 0), (3.68, .23, 3.68), .065, axis=1)
    m.block("BunkerRim", (0, -.152, 1.84), (3.40, .145, .124), .025, axis=2)
    for x in (-1.26, 1.26):
        m.profile("BunkerArmor", [(-1.97, -2.07), (-1.97, -1.75), (-.71, .83),
                                   (-.42, 1.51), (-.24, 1.53), (-.28, -1.99)],
                  .27, .046, center=(x, 0, 0))
        m.profile("BunkerRim", [(-1.65, -1.81), (-.69, .45), (-.58, .43), (-1.56, -1.92)],
                  .035, .008, center=(x + (0.145 if x > 0 else -0.145), 0, 0))
        m.block("Graphite", (x, -1.17, -1.96), (.54, 1.93, .30), .056, axis=2)
        for y in (-.50, -1.22, -1.91):
            for offset in (-.15, .15):
                rivet(m, (x + offset, y, -1.79), (0, 0, 1), .035)
    for x in (-1.47, 1.47):
        m.block("Graphite", (x, -.013, -.60), (.23, .036, 1.52), .014, axis=1)
        for index in range(9):
            z = -1.24 + index * .16
            m.block("BunkerRim", (x, .008, z), (.170, .017, .045), .006, axis=1)
        m.block("BunkerRim", (x, -.18, 1.84), (.32, .22, .125), .025, axis=2)
        rivet(m, (x, -.17, 1.92), (0, 0, 1), .044)
    for x in (-.98, 0, .98):
        m.block("Hazard", (x, -.21, 1.912), (.16, .046, .016), .006, axis=2)
    return m


def hospital():
    m = Model("field_hospital", 1.13)
    m.profile("HospitalEnamel", [(.06, -.98), (1.99, -.98), (2.42, -.62), (2.42, .38),
                                 (2.15, .61), (.19, .63)], 3.22, .086, center=(0, 0, 0))
    m.block("Graphite", (0, .15, -.22), (3.34, .26, 1.72), .043, axis=1)
    m.block("BunkerArmor", (0, 2.25, .16), (3.41, .19, 1.06), .046, axis=1)
    m.block("Graphite", (0, 1.13, .65), (1.52, 1.55, .12), .051, axis=2)
    m.block("Black", (0, 1.14, .726), (1.31, 1.34, .065), .033, axis=2)
    for side in (-1, 1):
        x = side * 1.07
        m.block("HospitalRed", (x, 1.22, .66), (.58, 1.51, .16), .033, axis=2)
        m.block("HospitalEnamel", (x, 1.54, .756), (.37, .133, .021), .011, axis=2)
        m.block("HospitalEnamel", (x, 1.54, .756), (.133, .37, .021), .011, axis=2)
        m.block("Graphite", (x, .85, .758), (.35, .18, .031), .013, axis=2)
        for y in (.67, 1.06, 1.84):
            rivet(m, (x + side * .203, y, .739), (0, 0, 1), .025)
        m.tube("Steel", (x, 2.35, -.18), (x, 2.49, -.18), .16, .146, sides=16)
        m.tube("Black", (x, 2.47, -.18), (x, 2.53, -.18), .123, .114, sides=16)
        m.block("IceLamp", (x, 2.19, .68), (.37, .055, .051), .013, axis=2)
    m.block("TurretCast", (0, .90, .776), (.77, .30, .14), .030, axis=2)
    for x in (-.28, -.14, 0, .14, .28):
        m.block("IceLamp", (x, 1.39, .772), (.075, .077, .033), .008, axis=2)
    return m


def ammunition_layer():
    m = Model("turret_ammo_layer", 4.4)
    for x in (-.105, -.053, 0, .053, .105):
        m.tube("Brass", (x, 0, .153), (x, 0, -.038), .020, .018, sides=12)
        m.tube("Brass", (x, 0, .148), (x, 0, .158), .021, .021, sides=12)
        m.tube("ShellTip", (x, 0, -.034), (x, 0, -.069), .017, .010, sides=12)
        m.tube("ShellTip", (x, 0, -.069), (x, 0, -.079), .010, .004, sides=12)
    return m


def dreadnought_ring():
    m = Model("dreadnought_ring", .9)
    for y0, y1, r0, r1, finish in ((.02, .16, 2.18, 2.25, "BunkerRim"),
                                    (.16, .30, 2.25, 2.19, "BunkerArmor"),
                                    (.30, .43, 1.74, 1.75, "Graphite"),
                                    (.43, .67, 1.68, 1.60, "TurretCast")):
        m.tube(finish, (0, y0, 0), (0, y1, 0), r0, r1, sides=44)
    for index in range(22):
        angle = index * pi / 11
        at = (cos(angle), 0, sin(angle))
        rivet(m, (at[0] * 1.89, .31, at[2] * 1.89), (0, 1, 0), .058)
        next_angle = angle + pi / 11
        m.tube("Hazard", (at[0] * 2.14, .52, at[2] * 2.14),
               (cos(next_angle) * 2.14, .52, sin(next_angle) * 2.14), .024, .024, sides=8)
        m.tube("TurretCast", (at[0] * 2.14, .27, at[2] * 2.14),
               (at[0] * 2.14, .53, at[2] * 2.14), .030, .027, sides=8)
        if index % 4 == 0:
            m.block("AmberLamp", (at[0] * 2.16, .234, at[2] * 2.16), (.092, .042, .092), .013, axis=1)
    return m


def dreadnought_housing():
    m = Model("dreadnought_housing", .81)
    m.profile("TurretCast", [(-.21, -1.72), (.23, -1.72), (1.31, -1.15),
                             (1.61, .48), (1.48, 1.53), (1.15, 1.84),
                             (.04, 1.92), (-.29, 1.41)], 3.15, .19)
    for side in (-1, 1):
        x = side * 1.55
        m.profile("BunkerArmor", [(-.08, -1.48), (.43, -1.58), (1.41, -.86), (1.43, .32),
                                   (1.18, 1.67), (.92, 1.76), (.05, 1.29)],
                  .53, .085, center=(x, 0, 0))
        m.block("Graphite", (side * 1.80, .76, 1.16), (.10, .56, .45), .035)
        for level in range(5):
            m.block("ScuffedEdge", (side * 1.864, .55 + level * .095, 1.15), (.042, .043, .35), .009)
        m.block("Black", (side * .73, .56, -1.56), (.69, .61, .25), .08, axis=2)
        m.tube("Steel", (side * 1.49, 1.18, 1.38), (side * 1.49, 2.40, 1.38), .036, .012, sides=12)
        for y, z in ((.24, -1.05), (.75, -.78), (1.18, -.43), (.20, .82), (1.04, 1.41)):
            rivet(m, (side * 1.829, y, z), (side, 0, 0), .043)
    m.block("TurretEnamel", (0, 1.57, .38), (1.51, .15, .82), .073, axis=1)
    m.block("TurretCast", (.52, 1.68, .71), (.55, .19, .55), .061, axis=1)
    m.block("Graphite", (-.45, 1.65, .45), (.46, .15, .62), .030, axis=1)
    m.block("AmberLamp", (0, 1.69, -.35), (.26, .16, .17), .040, axis=2)
    return m


def dreadnought_barrels():
    m = Model("dreadnought_barrels", .9)
    for x in (-.73, .73):
        sections = ((.83, -.99, .333, .306, "TurretCast"),
                    (-.99, -1.78, .302, .259, "Graphite"),
                    (-1.78, -3.45, .258, .188, "BarrelSteel"),
                    (-3.45, -4.70, .188, .165, "BarrelSteel"))
        for z0, z1, r0, r1, finish in sections:
            m.tube(finish, (x, 0, z0), (x, 0, z1), r0, r1, sides=32, cap=False)
        for z, radius in ((-1.08, .309), (-1.85, .265), (-3.51, .196)):
            m.tube("ScuffedEdge", (x, 0, z), (x, 0, z - .061), radius, radius * .986, sides=32, cap=False)
        m.tube("Black", (x, 0, -4.68), (x, 0, -4.37), .125, .116, sides=32, cap=False)
        for index in range(32):
            a, b = index * pi / 16, (index + 1) * pi / 16
            edge = lambda t, r: (x + cos(t) * r, sin(t) * r, -4.70)
            m.face("Steel", [edge(a, .165), edge(b, .165), edge(b, .125), edge(a, .125)], (0, 0, -1))
    return m


def turret_damage(severe):
    m = Model("turret_damage_heavy" if severe else "turret_damage_light", 3.2)
    for side in (-1, 1):
        x = side * (.492 if severe else .503)
        outline = [(.093, -.33), (.17, -.245), (.315, -.291), (.304, -.021), (.205, .112), (.115, .018)]
        m.profile("CharredTurret", outline, .038, .010, center=(x, 0, 0))
        m.profile("ScuffedEdge", [(.173, -.226), (.205, -.302), (.237, -.159), (.216, -.05), (.190, -.096)],
                  .012, .003, center=(x + side * .026, 0, 0))
        if severe:
            m.profile("Graphite", [(-.08, -.25), (-.05, -.36), (.12, -.32), (.15, -.19), (.022, -.09)],
                      .095, .026, center=(x + side * .06, 0, 0))
            for z in (-.27, -.16):
                m.tube("Hazard", (x, .14, z), (x + side * .12, -.057, z - .025), .023, .014, sides=8)
    return m


def nest():
    m = Model("cliff_nest", .85)
    rng = Random(14261)
    for n in range(17):
        a = n * 2 * pi / 17
        radius = rng.uniform(1.55, 2.10)
        x, z = cos(a) * radius, sin(a) * radius
        m.ellipsoid("DuneSinew", (x, .14, z), (rng.uniform(.50, .76), rng.uniform(.28, .57), rng.uniform(.49, .68)),
                    sides=12, rows=7, seed=n, variation=.14)
        at = (x * 1.04, .22, z * 1.04)
        tip = (x * 1.13, rng.uniform(.49, .90), z * 1.13)
        m.tube("DuneSinew", at, tip, .191, .036, sides=9)
    for n in range(9):
        a = n * 2 * pi / 9 + .24
        x, z = cos(a) * 2.0, sin(a) * 1.85
        m.ellipsoid("DuneChitin", (x, .37, z), (.23, .48, .30),
                    sides=16, rows=9, seed=n + 35, variation=.13)
    m.ellipsoid("StoneDark", (0, -.13, 0), (2.33, .24, 2.34), sides=32, rows=8, seed=24, variation=.09)
    return m


if __name__ == "__main__":
    models = (facade(), turret_platform(), hospital(), turret_cartridge(), ammunition_layer(), dreadnought_ring(), dreadnought_housing(),
              dreadnought_barrels(), turret_damage(False), turret_damage(True), nest())
    for model in models:
        model.write()
