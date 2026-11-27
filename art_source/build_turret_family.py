"""Bake the authored Stinger, Dragonfly and Bulba assemblies for Godot."""

from math import cos, pi, sin

from build_models import Model, OUTPUT, add, mul, sub


def fastener(model, center, axis=2, radius=0.026):
    offset = tuple(0.018 if i == axis else 0 for i in range(3))
    model.tube("Black", sub(center, offset), center, radius * 1.22, sides=16)
    model.tube("ScuffedEdge", center, add(center, offset), radius, radius * 0.78, sides=8, smooth=False)
    slot = (0.028, 0.009, 0.005) if axis == 2 else (0.005, 0.009, 0.028)
    model.block("Black", add(center, mul(offset, 1.02)), slot, 0.002)


def louver(model, x, y, z, width, rows, axis=2):
    if axis == 2:
        model.block("Black", (x, y, z), (width + 0.065, rows * 0.057 + 0.035, 0.045), 0.018)
        for index in range(rows):
            offset = (index - (rows - 1) / 2) * 0.057
            model.block("TurretCast", (x, y + offset, z - 0.024), (width, 0.023, 0.028), 0.008)
    else:
        side = 1 if x > 0 else -1
        model.block("Black", (x, y, z), (0.045, rows * 0.057 + 0.035, width + 0.065), 0.018)
        for index in range(rows):
            offset = (index - (rows - 1) / 2) * 0.057
            model.block("TurretCast", (x + side * 0.024, y + offset, z), (0.028, 0.023, width), 0.008)


def optic(model, x, y, face, radius):
    model.tube("TurretCast", (x, y, face + 0.08), (x, y, face), radius * 1.31, radius * 1.18, 32)
    model.tube("Black", (x, y, face), (x, y, face - 0.038), radius * 1.10, radius, 32)
    model.ellipsoid("TurretScanLamp", (x, y, face - 0.032), (radius * 0.78, radius * 0.78, radius * 0.25), 28, 10)


def bearing(model, radius):
    for finish, start, end, lower, upper in [
        ("Black", 0.00, 0.068, radius * 0.97, radius),
        ("TurretCast", 0.066, 0.14, radius, radius),
        ("TurretEnamel", 0.14, 0.25, radius, radius * 0.91),
        ("ScuffedEdge", 0.25, 0.272, radius * 0.91, radius * 0.89),
        ("Black", 0.272, 0.322, radius * 0.86, radius * 0.86),
        ("TurretCast", 0.322, 0.365, radius * 0.86, radius * 0.83),
    ]:
        model.tube(finish, (0, start, 0), (0, end, 0), lower, upper, 48)
    for index in range(10):
        angle = (index + 0.5) * 2 * pi / 10
        x, z = sin(angle) * radius * 0.965, cos(angle) * radius * 0.965
        model.block("TurretCast", (x, 0.145, z), (0.20, 0.255, 0.18), 0.035, angle, 1)
        model.tube("Black", (x, 0.266, z), (x, 0.285, z), 0.039, sides=8, smooth=False)
        model.tube("ScuffedEdge", (x, 0.285, z), (x, 0.298, z), 0.026, sides=8, smooth=False)
    for x in [-0.115, 0.0, 0.115]:
        model.block("Black", (x, 0.174, -radius * 0.975), (0.086, 0.105, 0.052), 0.010)
        model.block("AmberLamp", (x, 0.174, -radius), (0.052, 0.043, 0.021), 0.007)


def dock(model):
    x, z = 1.33, -0.96
    model.block("TurretCast", (x, 0.137, z), (0.77, 0.069, 0.66), 0.045)
    model.block("Black", (x, 0.099, z), (0.35, 0.17, 0.33), 0.026)
    for side in [-1, 1]:
        model.block("ScuffedEdge", (x + side * 0.31, 0.179, z), (0.07, 0.020, 0.54), 0.007)
        for row in range(3):
            model.block("Hazard", (x + side * 0.29, 0.19, z + (row - 1) * 0.14), (0.10, 0.008, 0.045), 0.003, side * 0.4, 1)


def hollow_barrel(model, x, y, front, inner, outer, length=0.22):
    back = front + length
    model.tube("BarrelSteel", (x, y, back), (x, y, front + 0.045), outer * 0.96, outer, 40, cap=False)
    model.tube("ScuffedEdge", (x, y, front + 0.045), (x, y, front), outer, outer * 0.91, 40, cap=False)
    for index in range(40):
        a = 2 * pi * index / 40
        b = 2 * pi * (index + 1) / 40

        def point(angle, radius, z):
            return (x + cos(angle) * radius, y + sin(angle) * radius, z)

        model.face("TurretCast", [point(a, outer * 0.91, front), point(b, outer * 0.91, front),
                                  point(b, inner, front), point(a, inner, front)], (0, 0, -1))
        model.face("Black", [point(a, inner, front), point(b, inner, front),
                             point(b, inner * 0.89, back), point(a, inner * 0.89, back)], (-cos((a + b) / 2), -sin((a + b) / 2), 0))
    model.tube("Black", (x, y, back + 0.018), (x, y, back), inner * 0.93, sides=40)


def pod_cell(model, x, y, front):
    radius = 0.108
    hollow_barrel(model, x, y, front, 0.075, radius, 0.124)
    for index in range(40):
        square = []
        circle = []
        for angle in (2 * pi * index / 40, 2 * pi * (index + 1) / 40):
            dx, dy = cos(angle), sin(angle)
            edge = 0.12 / max(abs(dx), abs(dy))
            square.append((x + dx * edge, y + dy * edge, front + 0.025))
            circle.append((x + dx * radius, y + dy * radius, front + 0.025))
        model.face("TurretCast", [square[0], square[1], circle[1], circle[0]], (0, 0, -1))


def insignia(model, x, y, z, side):
    for direction in (-1, 1):
        for row in range(3):
            start = z + direction * (0.035 + row * 0.023)
            tip = z + direction * (0.175 - row * 0.018)
            height = y - row * 0.036
            model.face("Ceramic", [(x, height + 0.016, start), (x, height + 0.076, tip),
                                    (x, height + 0.035, tip), (x, height - 0.012, start)], (side, 0, 0))


def stinger():
    base = Model("stinger_base", 2.40)
    bearing(base, 0.72)
    for index in range(4):
        angle = pi * 0.25 + index * pi * 0.5
        x, z = cos(angle), sin(angle)
        base.profile("TurretEnamel", [(-0.36, -0.10), (-0.21, -0.18), (0.33, -0.17), (0.46, -0.10), (0.46, 0.10),
                                      (0.33, 0.17), (-0.21, 0.18), (-0.36, 0.10)],
                     0.125, 0.025, 1, (x * 0.99, 0.145, z * 0.99), angle)
        base.block("TurretCast", (x * 1.39, 0.066, z * 1.39), (0.32, 0.118, 0.40), 0.044, angle, 1)
        base.tube("TurretCast", (x * 1.37, 0.12, z * 1.37), (x * 1.13, 0.37, z * 1.13), 0.064, 0.079, 24)
        base.tube("ScuffedEdge", (x * 1.13, 0.37, z * 1.13), (x * 1.01, 0.45, z * 1.01), 0.041, sides=24)
    base.tube("Black", (0, 0.35, 0), (0, 0.84, 0), 0.39, sides=48)
    for index in range(7):
        y = 0.385 + index * 0.065
        base.tube("TurretCast", (0, y, 0), (0, y + 0.036, 0), 0.45, 0.44, 48)
    base.tube("TurretEnamel", (0, 0.83, 0), (0, 0.94, 0), 0.53, 0.56, 48)
    base.tube("ScuffedEdge", (0, 0.94, 0), (0, 0.991, 0), 0.56, 0.53, 48)
    dock(base)

    head = Model("stinger_head", 2.7)
    head.profile("TurretEnamel", [(-0.27, -0.53), (-0.34, 0.25), (-0.24, 0.61), (0.018, 0.71),
                                  (0.37, 0.62), (0.52, 0.33), (0.52, -0.20), (0.30, -0.55)],
                 1.06, 0.094)
    head.profile("TurretCast", [(0.07, 0.47), (0.0, 0.65), (0.07, 0.74), (0.35, 0.70), (0.42, 0.47)], 0.96, 0.041)
    head.block("TurretCast", (0, 0.541, 0.17), (0.96, 0.106, 0.70), 0.038)
    head.block("TurretEnamel", (0, 0.589, 0.26), (0.58, 0.065, 0.37), 0.024)
    for side in [-1, 1]:
        x = side * 0.532
        louver(head, x, 0.26, 0.24, 0.31, 4, axis=0)
        for z in [-0.26, 0.50]:
            fastener(head, (x, 0.12, z), axis=0)
        optic(head, side * 0.35, 0.28, -0.54, 0.074)
        head.block("TurretScanLamp", (side * 0.34, 0.405, -0.499), (0.095, 0.019, 0.024), 0.005)
    head.tube("Black", (0, 0.015, 0.38), (0, 0.015, -0.61), 0.29, 0.25, 40)
    barrel = Model("stinger_barrel", 3.2)
    barrel.profile("TurretEnamel", [(-0.16, -1.12), (-0.19, -0.43), (-0.16, -0.29), (0.17, -0.29),
                                    (0.25, -0.49), (0.22, -0.85), (0.12, -1.12)], 0.55, 0.052)
    barrel.block("TurretCast", (0, 0.22, -0.71), (0.48, 0.12, 0.66), 0.04)
    barrel.block("BarrelSteel", (0, 0.015, -1.65), (0.295, 0.25, 1.34), 0.034)
    barrel.profile("TurretEnamel", [(-0.20, -2.59), (-0.22, -2.05), (-0.12, -1.91),
                                    (0.13, -1.91), (0.23, -2.08), (0.225, -2.55)],
                   0.49, 0.046)
    barrel.block("Black", (0, 0.015, -2.587), (0.37, 0.32, 0.048), 0.039)
    hollow_barrel(barrel, 0, 0.015, -2.61, 0.076, 0.120, 0.17)
    for side in [-1, 1]:
        for index in range(3):
            barrel.block("Black", (side * 0.239, 0.02, -2.19 - index * 0.13), (0.021, 0.112, 0.035), 0.007, -0.44)
        for z in [-0.51, -0.87]:
            fastener(barrel, (side * 0.278, 0.055, z), axis=0)
    return base, head, barrel


def dragonfly():
    base = Model("dragonfly_base", 2.60)
    bearing(base, 0.97)
    base.tube("TurretCast", (0, 0.36, 0), (0, 0.50, 0), 0.62, 0.59, 48)
    base.tube("Black", (0, 0.50, 0), (0, 0.64, 0), 0.59, 0.54, 48)
    dock(base)

    head = Model("dragonfly_head", 2.95)
    head.profile("TurretEnamel", [(-0.50, 0.24), (-0.42, -0.45), (-0.04, -0.57), (0.32, -0.52),
                                  (0.48, -0.31), (0.47, 0.46), (0.30, 0.60), (-0.23, 0.53)],
                 1.20, 0.080)
    head.profile("Black", [(-0.35, 0.29), (-0.27, -0.17), (0.29, -0.38), (0.37, -0.15),
                            (0.29, 0.38), (-0.19, 0.43)],
                 1.27, 0.064)
    for side in [-1, 1]:
        head.profile("TurretCast", [(-0.43, 0.28), (-0.24, -0.30), (0.34, -0.46), (0.45, -0.33),
                                    (0.42, -0.27), (-0.16, -0.16), (-0.29, 0.31)],
                     0.09, 0.025, center=(side * 0.615, 0, 0))
        louver(head, side * 0.647, -0.045, 0.17, 0.32, 5, axis=0)
        head.tube("TurretCast", (side * 0.54, 0.15, 0.04), (side * 0.80, 0.15, 0.04), 0.23, 0.21, 32)
    head.block("TurretEnamel", (0, 0.23, -0.57), (0.62, 0.36, 0.25), 0.049)
    optic(head, -0.10, 0.24, -0.71, 0.091)
    optic(head, 0.17, 0.20, -0.71, 0.053)
    for x in [-0.39, 0.39]:
        head.block("TurretScanLamp", (x, 0.44, -0.395), (0.17, 0.026, 0.035), 0.007)
    guns = Model("dragonfly_guns", 3.12)
    for side in [-1, 1]:
        x = side * 0.72
        guns.profile("TurretEnamel", [(-0.08, -0.63), (-0.14, 0.38), (-0.01, 0.57), (0.39, 0.54),
                                      (0.58, 0.26), (0.59, -0.44), (0.45, -0.67), (0.11, -0.70)],
                     0.49, 0.044, center=(x, 0, 0))
        guns.block("TurretCast", (x, 0.285, -0.635), (0.45, 0.66, 0.20), 0.052)
        guns.block("Black", (x, 0.285, -0.735), (0.33, 0.58, 0.035), 0.039)
        louver(guns, x + side * 0.247, 0.45, 0.04, 0.44, 3, axis=0)
        guns.block("TurretCast", (x, 0.582, 0.03), (0.34, 0.089, 0.62), 0.026)
        for z in [-0.38, 0.42]:
            for y in [0.05, 0.36]:
                fastener(guns, (x + side * 0.249, y, z), axis=0, radius=0.021)
        for row in range(3):
            y = 0.12 + row * 0.16
            front = -1.67 + row * 0.06
            guns.tube("TurretCast", (x, y, -0.69), (x, y, -0.91), 0.081, 0.064, 32)
            guns.tube("BarrelSteel", (x, y, -0.86), (x, y, front + 0.16), 0.051, 0.040, 32, cap=False)
            hollow_barrel(guns, x, y, front, 0.028, 0.056, 0.19)
        insignia(guns, x + side * 0.247, 0.20, 0.08, side)
        for index in range(3):
            guns.block("Hazard", (x + side * 0.252, 0.026, -0.22 + index * 0.12), (0.012, 0.063, 0.047), 0.005, 0.41)
    return base, head, guns


def bulba():
    base = Model("bulba_base", 2.58)
    bearing(base, 1.00)
    base.tube("TurretCast", (0, 0.36, 0), (0, 0.49, 0), 0.63, 0.62, 48)
    base.tube("Black", (0, 0.49, 0), (0, 0.56, 0), 0.57, 0.55, 48)
    dock(base)

    head = Model("bulba_head", 2.82)
    for side in [-1, 1]:
        head.profile("TurretCast", [(-0.46, 0.47), (-0.44, -0.33), (-0.26, -0.45), (-0.025, -0.26),
                                    (0.29, -0.08), (0.35, 0.18), (0.08, 0.37)],
                     0.20, 0.055, center=(side * 0.345, 0, 0))
        head.tube("Black", (side * 0.41, 0.0, 0.0), (side * 0.70, 0.0, 0.0), 0.23, 0.21, 40)
        head.tube("TurretCast", (side * 0.69, 0.0, 0.0), (side * 0.75, 0.0, 0.0), 0.205, 0.172, 40)
    head.profile("TurretEnamel", [(-0.29, 0.25), (-0.26, -0.48), (-0.12, -0.57), (0.30, -0.55),
                                  (0.46, -0.31), (0.39, 0.22), (0.24, 0.40)],
                 0.65, 0.062)
    head.block("TurretCast", (0, 0.08, -0.554), (0.45, 0.47, 0.114), 0.032)
    head.block("Black", (0, 0.11, -0.62), (0.11, 0.38, 0.031), 0.021)
    head.block("TurretScanLamp", (0, 0.14, -0.639), (0.035, 0.24, 0.019), 0.008)
    for x in [-0.20, 0.20]:
        for y in [-0.08, 0.24]:
            fastener(head, (x, y, -0.615))
    pods = Model("bulba_pods", 3.08)
    outline = [(-0.33, -0.59), (-0.34, 0.54), (-0.24, 0.71), (0.14, 0.70),
               (0.44, 0.55), (0.53, 0.20), (0.53, -0.57), (0.39, -0.71), (-0.19, -0.71)]
    for side in [-1, 1]:
        x = side * 0.61
        pods.profile("TurretEnamel", outline, 0.61, 0.055, center=(x, 0, 0))
        pods.block("Black", (x, 0.13, -0.704), (0.56, 0.78, 0.024), 0.030)
        for column in [-1, 1]:
            pods.block("TurretCast", (x + column * 0.277, 0.125, -0.706), (0.089, 0.79, 0.144), 0.025)
            for row in range(3):
                pod_cell(pods, x + column * 0.12, 0.37 - row * 0.24, -0.795)
        for y in [-0.26, 0.515]:
            pods.block("TurretCast", (x, y, -0.710), (0.57, 0.090, 0.144), 0.025)
            pods.block("Black", (x, y, -0.784), (0.23, 0.053, 0.025), 0.009)
            pods.block("TurretScanLamp", (x, y, -0.795), (0.16, 0.022, 0.019), 0.007)
        louver(pods, x + side * 0.306, 0.23, 0.02, 0.63, 5, axis=0)
        insignia(pods, x + side * 0.307, 0.017, 0.20, side)
        for index in range(4):
            pods.block("Hazard", (x + side * 0.309, -0.15, -0.36 + index * 0.15), (0.014, 0.096, 0.071), 0.005, side * 0.46)
        for z in [-0.52, 0.52]:
            fastener(pods, (x + side * 0.309, 0.07, z), axis=0)
        pods.block("TurretCast", (x, 0.49, 0.20), (0.40, 0.081, 0.63), 0.026)
        pods.block("Black", (x, 0.04, 0.655), (0.43, 0.54, 0.11), 0.028)
    return base, head, pods


if __name__ == "__main__":
    OUTPUT.mkdir(parents=True, exist_ok=True)
    for model in (*stinger(), *dragonfly(), *bulba()):
        model.write()
