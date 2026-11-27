"""Bake the project's original hard-surface and creature meshes as glTF binaries."""

from collections import defaultdict
from math import cos, pi, sin, sqrt
from pathlib import Path
from random import Random
import json
import struct

OUTPUT = Path(__file__).resolve().parents[1] / "assets/art/models"

MATERIALS = {
    "Alloy": ("586674", 0.66, 0.40),
    "Graphite": ("263140", 0.50, 0.42),
    "Steel": ("91a1a8", 0.67, 0.31),
    "Ceramic": ("a7b2b8", 0.28, 0.49),
    "Black": ("151d26", 0.12, 0.75),
    "Rubber": ("253039", 0.0, 0.85),
    "Fabric": ("364450", 0.0, 0.86),
    "Hazard": ("d8893d", 0.25, 0.58),
    "Concrete": ("bdc4c2", 0.0, 0.87),
    "Rock": ("dcba94", 0.0, 0.91),
    "StoneDark": ("aa896d", 0.0, 0.94),
    "Shell": ("564639", 0.04, 0.49),
    "Ridge": ("986443", 0.06, 0.57),
    "Membrane": ("553936", 0.0, 0.66),
    "IceLamp": ("78dcff", 0.0, 0.55, 0.8),
    "AmberLamp": ("ffc47c", 0.0, 0.54, 0.55),
    "Horn": ("423e36", 0.0, 0.49),
    "ColdReceiver": ("5a6779", 0.42, 0.55),
    "Cowl": ("4d5648", 0.25, 0.66),
    "SignalLamp": ("db4637", 0.0, 0.53, 0.52),
    "BarrelSteel": ("454b51", 0.48, 0.53),
    "ScuffedEdge": ("81868a", 0.46, 0.61),
    "OliveMetal": ("77725b", 0.43, 0.46),
    "DryLeaf": ("625338", 0.0, 0.85),
    "RedLeaf": ("9e4c39", 0.0, 0.67),
    "Eye": ("f58c54", 0.0, 0.56, 0.55),
}


def add(a, b):
    return tuple(x + y for x, y in zip(a, b))


def sub(a, b):
    return tuple(x - y for x, y in zip(a, b))


def mul(a, value):
    return tuple(x * value for x in a)


def dot(a, b):
    return sum(x * y for x, y in zip(a, b))


def cross(a, b):
    x, y, z = a
    u, v, w = b
    return (y * w - z * v, z * u - x * w, x * v - y * u)


def norm(a):
    return mul(a, 1 / max(sqrt(dot(a, a)), 1e-8))


def mean(points):
    return tuple(sum(p[i] for p in points) / len(points) for i in range(len(points[0])))


def mix(a, b, amount):
    return add(mul(a, 1 - amount), mul(b, amount))


def srgb_to_linear(value):
    return value / 12.92 if value < 0.04045 else ((value + 0.055) / 1.055) ** 2.4


class Model:
    def __init__(self, name, density=1.0):
        self.name = name
        self.density = density
        self.faces = defaultdict(list)

    def face(self, finish, points, facing, normals=None, uv=None):
        area = cross(sub(points[1], points[0]), sub(points[2], points[0]))
        if dot(area, area) < 1e-16:
            return
        if dot(area, facing) < 0:
            points = points[::-1]
            area = mul(area, -1)
            if normals is not None:
                normals = normals[::-1]
            if uv is not None:
                uv = uv[::-1]
        normal = norm(area)
        if normals is None:
            normals = [normal] * len(points)
        if uv is None:
            axis = max(range(3), key=lambda i: abs(normal[i]))
            u, v = [(2, 1), (0, 2), (0, 1)][axis]
            uv = [(p[u] * self.density, -p[v] * self.density) for p in points]
        vertices = list(zip(points, normals, uv))
        for i in range(1, len(points) - 1):
            self.faces[finish].extend((vertices[0], vertices[i], vertices[i + 1]))

    def profile(self, finish, outline, thickness, bevel, axis=0, center=(0, 0, 0), angle=0.0):
        """Extrude an outline with chamfered front and rear edges, along the selected axis."""
        axes = [(1, 2), (0, 2), (0, 1)][axis]
        area = sum(a[0] * b[1] - a[1] * b[0] for a, b in zip(outline, outline[1:] + outline[:1]))
        if area < 0:
            outline = outline[::-1]
        inset = []
        bevel = min(bevel, thickness * 0.47)
        for i, point in enumerate(outline):
            following = outline[(i + 1) % len(outline)]
            left = norm((outline[i - 1][1] - point[1], point[0] - outline[i - 1][0]))
            right = norm((point[1] - following[1], following[0] - point[0]))
            inset.append(add(point, mul(add(left, right), bevel / max(0.25, 1 + dot(left, right)))))
        hinge = mean(outline)

        def lift(p, lane):
            u, v = sub(p, hinge)
            p = add(hinge, (u * cos(angle) - v * sin(angle), u * sin(angle) + v * cos(angle)))
            point = list(center)
            point[axis] += lane
            point[axes[0]] += p[0]
            point[axes[1]] += p[1]
            return tuple(point)

        radius = thickness / 2
        rows = [[lift(p, depth) for p in polygon] for polygon, depth in
                [(inset, -radius), (outline, -radius + bevel), (outline, radius - bevel), (inset, radius)]]
        mid = lift(hinge, 0)
        axis_vector = tuple(1 if i == axis else 0 for i in range(3))
        self.face(finish, rows[0], mul(axis_vector, -1))
        self.face(finish, rows[-1], axis_vector)
        for low, high in zip(rows, rows[1:]):
            for i in range(len(outline)):
                j = (i + 1) % len(outline)
                face = [low[i], low[j], high[j], high[i]]
                self.face(finish, face, sub(mean(face), mid))

    def block(self, finish, center, size, bevel=0.02, angle=0, axis=0):
        axes = [(1, 2), (0, 2), (0, 1)][axis]
        u, v = (size[i] / 2 for i in axes)
        clip = min(bevel * 1.6, u * 0.38, v * 0.38)
        outline = [(-u + clip, -v), (u - clip, -v), (u, -v + clip), (u, v - clip),
                   (u - clip, v), (-u + clip, v), (-u, v - clip), (-u, -v + clip)]
        self.profile(finish, outline, size[axis], min(bevel, clip / 2), axis, center, angle)

    def tube(self, finish, start, end, r1, r2=None, sides=12, section=(1, 1), smooth=True):
        r2 = r1 if r2 is None else r2
        axis = norm(sub(end, start))
        basis = (0, 1, 0) if abs(axis[1]) < 0.9 else (1, 0, 0)
        east = norm(cross(axis, basis))
        north = cross(axis, east)
        spokes = [add(mul(east, cos(i * 2 * pi / sides) * section[0]),
                      mul(north, sin(i * 2 * pi / sides) * section[1])) for i in range(sides)]
        a = [add(start, mul(spoke, r1)) for spoke in spokes]
        b = [add(end, mul(spoke, r2)) for spoke in spokes]
        self.face(finish, a, mul(axis, -1))
        self.face(finish, b, axis)
        for i in range(sides):
            j = (i + 1) % sides
            facing = add(spokes[i], spokes[j])
            slopes = [norm(spokes[n]) for n in (i, j, j, i)] if smooth else None
            self.face(finish, [a[i], a[j], b[j], b[i]], facing, slopes)

    def ellipsoid(self, finish, center, radii, sides=16, rows=8, seed=0, variation=0.0):
        rng = Random(seed)
        sections = []
        for row in range(rows + 1):
            t = min(pi - 0.001, max(0.001, row * pi / rows))
            ring = []
            for i in range(sides + 1):
                longitude = (i % sides) * 2 * pi / sides
                direction = (sin(t) * cos(longitude), cos(t), sin(t) * sin(longitude))
                jitter = [1 + rng.uniform(-variation, variation) for _ in range(3)] if i != sides else [1, 1, 1]
                point = add(center, tuple(d * r * n for d, r, n in zip(direction, radii, jitter)))
                normal = norm(tuple(d / r for d, r in zip(direction, radii)))
                ring.append((point, normal, (i / sides, row / rows)))
            ring[-1] = (*ring[0][:2], (1.0, row / rows))
            sections.append(ring)
        for current, following in zip(sections, sections[1:]):
            for i in range(sides):
                a, b, c, d = current[i], current[i + 1], following[i + 1], following[i]
                for tri in ((a, b, c), (a, c, d)):
                    p, n, uv = zip(*tri)
                    self.face(finish, list(p), sub(mean(p), center), list(n), list(uv))

    def write(self):
        storage = bytearray()
        views = []
        accessors = []
        primitives = []
        finishes = []
        for finish, vertices in self.faces.items():
            unique = {}
            rows = []
            indexes = []
            for point, normal, uv in vertices:
                key = (*point, *normal, *uv)
                if key not in unique:
                    unique[key] = len(rows)
                    rows.append(key)
                indexes.append(unique[key])
            stride = 32
            vertex_view = len(views)
            views.append({"buffer": 0, "byteOffset": len(storage), "byteLength": len(rows) * stride, "byteStride": stride, "target": 34962})
            for row in rows:
                storage.extend(struct.pack("<8f", *row))
            index_view = len(views)
            views.append({"buffer": 0, "byteOffset": len(storage), "byteLength": len(indexes) * 4, "target": 34963})
            storage.extend(struct.pack(f"<{len(indexes)}I", *indexes))
            bounds = {method.__name__: [method(row[i] for row in rows) for i in range(3)] for method in (min, max)}
            offset = len(accessors)
            accessors.extend([
                {"bufferView": vertex_view, "byteOffset": 0, "componentType": 5126, "count": len(rows), "type": "VEC3", **bounds},
                {"bufferView": vertex_view, "byteOffset": 12, "componentType": 5126, "count": len(rows), "type": "VEC3"},
                {"bufferView": vertex_view, "byteOffset": 24, "componentType": 5126, "count": len(rows), "type": "VEC2"},
                {"bufferView": index_view, "componentType": 5125, "count": len(indexes), "type": "SCALAR"},
            ])
            hex_color, metal, roughness, *glow = MATERIALS[finish]
            color = [srgb_to_linear(v / 255) for v in bytes.fromhex(hex_color)]
            base = {"name": finish, "pbrMetallicRoughness": {"baseColorFactor": color + [1.0], "metallicFactor": metal, "roughnessFactor": roughness}}
            if glow:
                base["emissiveFactor"] = [v * glow[0] for v in color]
            primitives.append({"attributes": {"POSITION": offset, "NORMAL": offset + 1, "TEXCOORD_0": offset + 2}, "indices": offset + 3, "material": len(finishes)})
            finishes.append(base)
        document = {"asset": {"version": "2.0", "generator": "Outpost Aster art source"},
                    "scene": 0, "scenes": [{"nodes": [0]}], "nodes": [{"name": self.name, "mesh": 0}],
                    "meshes": [{"name": self.name, "primitives": primitives}], "materials": finishes,
                    "buffers": [{"byteLength": len(storage)}], "bufferViews": views, "accessors": accessors}
        header = json.dumps(document, separators=(",", ":")).encode()
        header += b" " * (-len(header) % 4)
        content = struct.pack("<I4s", len(header), b"JSON") + header
        content += struct.pack("<I4s", len(storage), b"BIN\0") + storage
        with (OUTPUT / f"{self.name}.glb").open("wb") as handle:
            handle.write(struct.pack("<4sII", b"glTF", 2, 12 + len(content)))
            handle.write(content)
        print(f"{self.name:<20} {sum(len(f) // 3 for f in self.faces.values()):>6} tris  {len(primitives)} surfaces")


def rivet(model, center, axis, size, finish="Steel"):
    model.tube(finish, center, add(center, mul(axis, size * 0.30)), size, size * 0.83, sides=6, smooth=False)


def grip_hand(model, center, direction, support=False):
    x, y, z = center
    forearm = (x + direction * 0.055, y - 0.11, z + (0.27 if support else 0.24))
    model.tube("Fabric", (x, y - .025, z + .054), forearm, .059, .087, sides=10)
    model.tube("Graphite", mix(center, forearm, .67), mix(center, forearm, .83), .079, .084, sides=10)
    model.ellipsoid("Rubber", center, (.068, .079, .095), sides=12, rows=6)
    model.block("Fabric", (x + direction * .032, y + .019, z + .029), (.086, .076, .105), .013)
    for i in range(4):
        finger = (x - direction * (.025 + i * .012), y + .018 - i * .018, z - .044 + i * .013)
        model.ellipsoid("Rubber", finger, (.034, .023, .037), 9, 5)


def bridge_rail(model, center):
    """Form one cheek of the bridge, with a beveled opening through the side."""
    outer = [(.129, -.561), (.221, -.525), (.310, -.382), (.321, .045),
             (.288, .231), (.140, .286)]
    opening = [(.170, -.473), (.217, -.448), (.265, -.348), (.277, .019),
               (.243, .176), (.172, .204)]
    width = .041
    bevel = .005
    for side in (-1, 1):
        face_x = center + side * width / 2
        shoulder_x = face_x - side * bevel
        for i in range(len(outer)):
            j = (i + 1) % len(outer)
            outer_edge = [outer[i], outer[j]]
            inner_edge = [opening[i], opening[j]]
            rim = [(face_x, *mix(outer[k], opening[k], .10)) for k in (i, j)]
            lip = [(face_x, *mix(opening[k], outer[k], .12)) for k in (i, j)]
            outside = [(shoulder_x, *point) for point in outer_edge]
            inside = [(shoulder_x, *point) for point in inner_edge]
            model.face("ColdReceiver", [rim[0], rim[1], lip[1], lip[0]], (side, 0, 0))
            model.face("ScuffedEdge" if i in (2, 3) and side * center > 0 else "ColdReceiver",
                       [outside[0], outside[1], rim[1], rim[0]], (side, 0, 0))
            model.face("ColdReceiver", [lip[0], lip[1], inside[1], inside[0]], (side, 0, 0))
    front = center - width / 2 + bevel
    back = center + width / 2 - bevel
    for outline, inward in ((outer, False), (opening, True)):
        centerline = (center, *mean(outline))
        for i in range(len(outline)):
            j = (i + 1) % len(outline)
            points = [(front, *outline[i]), (front, *outline[j]), (back, *outline[j]), (back, *outline[i])]
            normal = sub(centerline, mean(points)) if inward else sub(mean(points), centerline)
            model.face("Graphite" if inward else "ColdReceiver", points, normal)


def rifle():
    m = Model("aster_carbine", 4.6)
    m.profile("ColdReceiver", [(-.088, .286), (.108, .339), (.149, .167), (.128, -.471),
                              (.103, -.647), (.013, -.681), (-.100, -.526), (-.137, -.191),
                              (-.073, .109)], .267, .022)
    m.profile("Graphite", [(-.098, .266), (.092, .291), (.111, .419), (-.053, .447),
                           (-.122, .357)], .196, .021)
    m.block("Rubber", (0, -.006, .429), (.205, .175, .054), .017, axis=2)
    m.profile("Graphite", [(-.066, .024), (-.089, -.101), (-.203, -.042), (-.257, .050),
                          (-.232, .114), (-.152, .084)], .129, .014)
    m.block("Black", (0, -.076, -.152), (.159, .091, .250), .014, axis=1)
    for side in (-1, 1):
        m.profile("Cowl", [(-.080, -.207), (-.055, -.420), (-.093, -.526), (-.049, -.628),
                           (.030, -.664), (.114, -.584), (.113, -.302), (.079, -.224)],
                  .043, .014, center=(side * .132, 0, 0))
        # The outer frame and the recessed backing sit at different depths.
        m.block("Black", (side * .158, .047, -.451), (.018, .049, .286), .005, axis=0)
        for y in (.018, .076):
            m.block("ColdReceiver", (side * .165, y, -.451), (.016, .015, .286), .003, axis=0)
        for z in (-.589, -.530, -.474, -.423, -.365, -.312):
            m.block("ColdReceiver", (side * .166, .046, z), (.017, .060, .015), .003, angle=-.16)
        m.profile("ColdReceiver", [(-.042, -.191), (.103, -.219), (.134, -.146), (.116, .214),
                                   (.061, .276), (-.047, .241)], .033, .011,
                  center=(side * .139, 0, 0))
        m.block("Black", (side * .158, .056, .018), (.015, .052, .140), .006)
        if side > 0:
            m.block("Steel", (side * .167, .061, .025), (.013, .020, .098), .004)
        m.block("Hazard", (side * .161, -.012, -.140), (.006, .025, .064), .0018, angle=.39)
        m.block("ScuffedEdge", (side * .159, .100, .131), (.005, .010, .161), .0015)
        for z in (-.256, -.157, .166, .241):
            rivet(m, (side * .156, .078 if z < 0 else .048, z), (side, 0, 0), .010, "ScuffedEdge")
        for z in (.258, .296, .334):
            m.block("Rubber", (side * .107, -.035, z), (.018, .076, .015), .003, angle=.28)
        bridge_rail(m, side * .068)
    m.block("ColdReceiver", (0, .299, -.352), (.157, .024, .102), .008)
    m.block("ColdReceiver", (0, .306, .016), (.174, .035, .105), .010)
    m.block("Graphite", (0, .133, -.493), (.193, .030, .133), .010)
    for side in (-1, 1):
        m.block("ScuffedEdge", (side * .032, .180, -.572), (.019, .056, .052), .007)
        m.block("Black", (side * .036, .181, .218), (.023, .045, .034), .006)
    m.block("AmberLamp", (0, .203, -.576), (.008, .010, .011), .002)
    m.tube("Black", (0, .035, -.622), (0, .035, -.780), .042, .047, 12)
    m.tube("ColdReceiver", (0, .035, -.671), (0, .035, -.757), .063, .058, 10, section=(1.17, .90))
    m.tube("ScuffedEdge", (0, .035, -.756), (0, .035, -.772), .045, .041, 12)
    m.tube("Black", (0, .035, -.773), (0, .035, -.785), .028, .025, 12)
    grip_hand(m, (.043, -.148, .064), 1)
    return m


def rifle_magazine():
    m = Model("aster_carbine_magazine", 4.9)
    m.profile("ColdReceiver", [(.010, -.258), (.009, -.052), (-.164, -.019), (-.227, -.067),
                               (-.253, -.199), (-.207, -.252)], .130, .013)
    m.profile("Rubber", [(-.198, -.248), (-.191, -.142), (-.229, -.046), (-.267, -.066),
                         (-.284, -.195), (-.247, -.245)], .147, .011)
    for side in (-1, 1):
        for index in range(3):
            m.block("Graphite", (side * .069, -.118 - index * .027, -.111 + index * .019),
                    (.014, .016, .114), .003, angle=.12)
        m.block("ScuffedEdge", (side * .072, -.036, -.156), (.008, .014, .117), .002)
    return m


def rifle_support():
    m = Model("aster_carbine_support", 4.4)
    grip_hand(m, (0, 0, 0), -1, True)
    return m


def repair_tool():
    m = Model("field_repair_tool", 4.2)
    m.profile("Graphite", [(-.082, .18), (.104, .175), (.159, -.088), (.096, -.283),
                            (-.066, -.272), (-.121, -.049)], .222, .014)
    m.block("Hazard", (0, .127, -.067), (.204, .072, .262), .018)
    m.block("Alloy", (0, -.169, .057), (.122, .239, .137), .016, angle=.18)
    for side in (-1, 1):
        x = side * .087
        m.block("Ceramic", (x, .036, -.321), (.090, .103, .256), .013, angle=-.11)
        m.tube("Steel", (x, .028, -.368), (x, .028, -.519), .035, .026, 10)
        m.tube("IceLamp", (x, .028, -.511), (x, .028, -.523), .025, .019, 10)
        for i in range(3):
            m.block("Black", (side * .118, .015, -.18 + i * .042), (.009, .069, .014), .003)
    m.block("Black", (0, .168, -.05), (.096, .011, .115), .003)
    m.block("IceLamp", (0, .176, -.054), (.070, .006, .077), .002)
    grip_hand(m, (.047, -.153, .068), 1)
    return m


def turret_base():
    m = Model("turret_base", 2.0)
    m.tube("Graphite", (0, .026, 0), (0, .107, 0), .602, .602, 8, smooth=False)
    m.tube("Cowl", (0, .094, 0), (0, .210, 0), .623, .533, 8, smooth=False)
    m.tube("Steel", (0, .213, 0), (0, .247, 0), .437, .427, 16)
    m.tube("Black", (0, .239, 0), (0, .332, 0), .407, .405, 16)
    m.tube("Cowl", (0, .325, 0), (0, .378, 0), .468, .445, 10, smooth=False)
    for side in (-1, 1):
        for direction in (-1, 1):
            plate = (side * .550, .062, direction * .511)
            yaw = -side * direction * .684
            m.block("Cowl", plate, (.225, .110, .502), .026, angle=yaw, axis=1)
            m.block("ScuffedEdge", (side * .558, .121, direction * .517),
                    (.121, .024, .311), .006, angle=yaw, axis=1)
            rivet(m, (side * .693, .121, direction * .673), (0, 1, 0), .037, "ScuffedEdge")
        m.block("Cowl", (side * .306, .509, .058), (.171, .355, .364), .038, angle=-side * .14, axis=2)
        m.block("Graphite", (side * .337, .583, .080), (.158, .152, .315), .022)
        for direction in (-1, 1):
            rivet(m, (side * .390, .461, direction * .091 + .065), (side, 0, 0), .026)
    m.block("Graphite", (0, .422, .135), (.559, .137, .360), .029, axis=1)
    for x in (-.17, .17):
        m.block("Hazard", (x, .117, .533), (.064, .026, .089), .005, angle=.26, axis=1)
    return m


def turret_head():
    m = Model("turret_head", 2.1)
    m.profile("Graphite", [(-.211, .419), (.106, .504), (.228, .333), (.182, -.278),
                            (.034, -.386), (-.139, -.253), (-.211, .106)], .756, .042)
    # High outer armor and exposed coaxial motors frame the elevating carriage.
    m.profile("Cowl", [(.114, .455), (.259, .399), (.347, .206), (.299, -.239),
                        (.151, -.360), (.106, -.181)], .864, .040)
    for side in (-1, 1):
        m.profile("Cowl", [(-.034, .433), (.229, .398), (.270, .241), (.208, -.296),
                            (.029, -.360), (-.013, -.188)], .111, .025,
                  center=(side * .399, 0, 0))
        x = side * .401
        m.tube("Graphite", (x, -.019, .018), (side * .473, -.019, .018), .189, .182, 16)
        m.tube("ScuffedEdge", (side * .474, -.019, .018), (side * .492, -.019, .018), .155, .154, 16)
        m.tube("Black", (side * .491, -.019, .018), (side * .514, -.019, .018), .131, .129, 16)
        m.tube("Steel", (side * .512, -.019, .018), (side * .526, -.019, .018), .046, .043, 10)
        for z in (.281, .366):
            m.block("Black", (side * .462, .108, z), (.016, .036, .044), .004)
    m.block("Graphite", (0, .045, .467), (.519, .225, .111), .019, axis=2)
    for z in (.274, .350, .429):
        m.block("ScuffedEdge", (-.184, .284, z), (.179, .013, .034), .003, axis=1)
    m.profile("ColdReceiver", [(.167, -.251), (.335, -.198), (.378, -.095),
                               (.316, .011), (.183, -.087)], .274, .025,
              center=(.058, .001, 0))
    m.tube("Black", (.059, .286, -.246), (.059, .278, -.296), .089, .075, 14)
    m.tube("SignalLamp", (.059, .278, -.290), (.059, .276, -.305), .055, .056, 14)
    m.block("AmberLamp", (-.063, .244, -.273), (.027, .014, .021), .004)
    return m


def turret_emitters():
    m = Model("turret_emitters", 2.5)
    m.block("ColdReceiver", (0, -.078, -.350), (.446, .203, .311), .031, axis=1)
    for side in (-1, 1):
        x = side * .22
        m.profile("Cowl", [(-.104, -.303), (.088, -.228), (.152, -.341), (.113, -.602),
                            (-.056, -.690), (-.113, -.534)], .232, .021, center=(x, 0, 0))
        m.tube("ColdReceiver", (x, .023, -.534), (x, .023, -.716), .117, .112, 14)
        m.tube("ScuffedEdge", (x, .023, -.707), (x, .023, -.767), .114, .084, 14)
        m.tube("BarrelSteel", (x, .023, -.752), (x, .023, -1.092), .052, .049, 12)
        m.tube("BarrelSteel", (x, .023, -.965), (x, .023, -1.207), .076, .081, 12)
        m.tube("BarrelSteel", (x, .023, -1.193), (x, .023, -1.234), .090, .072, 12)
        m.tube("Black", (x, .023, -1.230), (x, .023, -1.237), .045, .040, 12)
        m.block("Black", (x + side * .117, .047, -.463), (.011, .064, .154), .007)
        for z in (-.514, -.469, -.419):
            m.block("ScuffedEdge", (x + side * .122, .047, z), (.008, .050, .012), .003, angle=.20)
    return m


def turret_wreck():
    m = Model("turret_wreck", 1.6)
    m.block("Graphite", (0, .208, 0), (.717, .361, .678), .059, angle=.19, axis=2)
    m.block("Alloy", (-.337, .223, .077), (.241, .195, .394), .031, angle=-.27, axis=1)
    m.block("Hazard", (.248, .319, -.131), (.374, .104, .337), .022, angle=-.52, axis=0)
    for side in (-1, 1):
        m.tube("Steel", (side * .150, .25, -.225), (side * .412, .161, -.487), .049, .029, 7)
    return m


def beetle():
    m = Model("dune_beetle", 2.0)
    m.ellipsoid("Membrane", (0, .562, .041), (.340, .268, .704), 16, 7)
    m.ellipsoid("Shell", (0, .669, -.240), (.420, .273, .430), 16, 7, 55, .053)
    m.ellipsoid("Shell", (0, .557, .428), (.329, .223, .327), 14, 6, 61, .036)
    for i in range(4):
        z = -.35 + i * .226
        y = .748 - i * .016
        for side in (-1, 1):
            width = .28 - abs(i - 1) * .034
            m.ellipsoid("Shell" if i % 2 else "Ridge", (side * .144, y, z), (width, .167, .261),
                        11, 5, seed=120 + i * 19 + side, variation=.06)
            m.tube("Ridge", (side * .209, y + .138, z + .054),
                   (side * (.382 - i * .028), y + .072, z + .218), .043, .011, 7, section=(1, .62))
    for side in (-1, 1):
        # Swept mineral fins are widest at the shoulders and lie against the spine.
        fin = [(side * .228, .780, -.411), (side * .185, .981, -.207),
               (side * .133, 1.045, .316), (side * .211, .818, .422)]
        ridge = (side * .289, .920, .161)
        root = (side * .128, .788, .036)
        for index in range(len(fin)):
            edge_a, edge_b = fin[index], fin[(index + 1) % len(fin)]
            m.face("Horn" if index == 1 else "Ridge", [edge_a, edge_b, ridge], (side, .4, 0))
            m.face("Shell", [edge_a, edge_b, root], (-side, .2, 0))
        m.tube("Shell", (side * .258, .866, -.190), ridge, .033, .012, 7, section=(1, .66))
        m.tube("Membrane", (side * .248, .602, -.284), (side * .329, .473, -.481), .103, .099, 8)
        m.tube("Membrane", (side * .245, .561, .286), (side * .313, .453, .413), .112, .095, 8)
    tail = [(0, .520, .567), (0, .467, .725), (0, .400, .899), (0, .428, 1.075), (0, .497, 1.167)]
    for i, (start, end) in enumerate(zip(tail, tail[1:])):
        m.tube("Shell" if i % 2 else "Ridge", start, end, .169 - i * .033, .144 - i * .044, 8)
    m.tube("Horn", tail[-1], (.103, .537, 1.235), .042, .004, 7)
    m.tube("Horn", tail[-1], (-.089, .530, 1.212), .039, .004, 7)
    m.ellipsoid("Membrane", (0, .477, -.743), (.251, .114, .334), 14, 6)
    m.ellipsoid("Ridge", (0, .614, -.758), (.278, .161, .310), 14, 7, 65, .032)
    m.ellipsoid("Shell", (0, .540, -1.014), (.185, .079, .166), 12, 6)
    m.ellipsoid("Horn", (0, .443, -.984), (.166, .051, .144), 10, 5)
    for side in (-1, 1):
        m.tube("Horn", (side * .207, .609, -.683), (side * .105, .565, -1.046), .075, .027, 8, section=(1, .63))
        m.ellipsoid("Horn", (side * .203, .558, -.936), (.067, .035, .059), 10, 5)
        m.ellipsoid("Eye", (side * .244, .556, -.951), (.028, .016, .035), 9, 4)
        m.ellipsoid("Eye", (side * .255, .562, -.856), (.021, .011, .022), 8, 4)
        for index in range(3):
            z = -.854 - .065 * index
            m.tube("Horn", (side * (.165 - .021 * index), .485, z),
                   (side * (.137 - .019 * index), .426, z - .033), .026, .006, 6)
        m.tube("Horn", (side * .186, .460, -1.003), (side * .166, .427, -1.190), .045, .009, 8, section=(1, .65))
    return m


def beetle_leg(side):
    m = Model("beetle_leg_left" if side < 0 else "beetle_leg_right", 2.1)
    knee = (side * .327, .112, .070)
    hock = (side * .405, -.211, .112)
    foot = (side * .446, -.472, -.018)
    m.tube("Membrane", (0, .015, 0), knee, .128, .117, 8, section=(1, .71))
    m.tube("Ridge", (side * .064, .068, .012), (side * .30, .145, .076), .112, .087, 8, section=(1, .73))
    m.ellipsoid("Shell", knee, (.107, .106, .116), 10, 5)
    m.tube("Membrane", knee, hock, .101, .066, 8)
    m.tube("Shell", (side * .350, .063, .124), (side * .423, -.330, .073), .084, .046, 8)
    m.tube("Membrane", hock, foot, .064, .058, 8)
    for x in (-.039, .043):
        m.tube("Horn", (foot[0] + x, -.437, -.020), (foot[0] + x * 1.23, -.499, -.207), .044, .006, 7, section=(1, .70))
    return m


def beetle_claw(side):
    m = Model("beetle_claw_left" if side < 0 else "beetle_claw_right", 2.4)
    joint = (side * .237, .209, -.128)
    wrist = (side * .320, .242, -.404)
    m.tube("Membrane", (0, 0, 0), joint, .098, .085, 8)
    m.tube("Shell", joint, wrist, .089, .080, 8, section=(1, .69))
    m.ellipsoid("Ridge", wrist, (.100, .067, .105), 10, 5)
    for shift in (-.036, .046):
        knuckle = (wrist[0] + shift, .237, -.424)
        bend = (wrist[0] + shift * .53, .168, -.563)
        tip = (wrist[0] - shift * .16, .036, -.658)
        m.tube("Horn", knuckle, bend, .045, .033, 7, section=(1, .58))
        m.tube("Horn", bend, tip, .034, .004, 7, section=(1, .58))
    return m


def wall():
    m = Model("wall_segment", .62)
    m.profile("Concrete", [(.065, -3.31), (2.77, -3.31), (3.056, -3.26), (3.164, .376),
                           (2.8, .389), (.062, .389)], 3.94, .078, axis=0)
    m.block("Alloy", (0, 3.057, -1.459), (3.99, .244, 3.704), .040, axis=1)
    for z in (-2.998, -2.302, -1.606, -.91, -.214):
        m.block("Graphite", (0, 3.178, z), (3.82, .004, .029), .0008, axis=1)
    for x in (-1.56, 1.56):
        m.block("Graphite", (x, 3.177, -2.985), (.317, .008, .175), .0015, axis=1)
        for offset in (-.105, -.04, .04, .105):
            m.block("Steel", (x + offset, 3.184, -2.985), (.026, .008, .150), .0015, axis=1)
    m.profile("Concrete", [(.07, -.339), (.16, -.385), (2.24, -.385), (2.68, -.309),
                            (3.06, -.282), (3.12, .242), (2.71, .362), (.086, .367)],
              3.94, .059, axis=0)
    m.block("Graphite", (0, .145, 0), (3.955, .269, .938), .049, axis=1)
    m.block("Alloy", (0, 3.064, 0), (3.956, .185, .869), .045, axis=1)
    for side in (-1, 1):
        z = side * .386 if side > 0 else -3.315
        for x in (-1.20, 0, 1.20):
            m.block("Concrete", (x, 1.421, z), (1.101, 2.21, .202), .075, axis=2)
            m.block("Black", (x, 2.486, z + side * .079), (.897, .149, .064), .028, axis=2)
            m.block("Alloy", (x, 2.507, z + side * .120), (.798, .063, .026), .013, axis=2)
        m.block("Graphite", (0, 2.897, z + side * .055), (3.89, .227, .203), .023, axis=2)
        for end in (-1, 1):
            x = end * 1.32
            m.block("OliveMetal", (x, 1.74, z + side * .102), (.62, .62, .127), .033, axis=2)
            m.block("Black", (x, 1.743, z + side * .177), (.48, .43, .052), .018, axis=2)
            for slat in range(5):
                m.block("Steel", (x, 1.595 + slat * .074, z + side * .209), (.40, .027, .035), .004, axis=2)
            rivet(m, (x + .257, 1.96, z + side * .171), (0, 0, side), .018)
        for x in (-1.80, -.60, .60, 1.80):
            m.profile("Graphite", [(x - .091, .24), (x + .081, .24), (x + .092, 2.76),
                                    (x + .030, 2.90), (x - .102, 2.76)],
                      .187, .026, axis=2, center=(0, 0, z + side * .026))
            for y in (.40, 1.616, 2.744):
                rivet(m, (x, y, z + side * .126), (0, 0, side), .032)
        m.block("Hazard", (0, .398, z + side * .113), (3.42, .103, .023), .012, axis=2)
        for x in [-1.45 + .25 * index for index in range(12)]:
            m.block("Graphite", (x, .399, z + side * .129), (.074, .114, .012), .008, angle=-.53, axis=2)
    return m


def blocker():
    m = Model("gate_frame", .6)
    m.block("Graphite", (0, .027, 0), (3.98, .052, 1.145), .014, axis=1)
    m.block("Alloy", (0, 3.331, 0), (3.991, .42, 1.013), .084, axis=1)
    m.block("Black", (0, 3.423, .519), (2.053, .237, .036), .018, axis=2)
    m.block("Black", (0, 3.423, -.519), (2.053, .237, .036), .018, axis=2)
    for sign in (-1, 1):
        x = sign * 1.87
        m.block("Graphite", (x, 1.677, 0), (.238, 3.295, 1.054), .037)
        m.block("Alloy", (x, .516, 0), (.244, .94, 1.078), .033)
        m.block("Steel", (x, 2.806, 0), (.247, .188, 1.094), .024)
        for k in (-1, 1):
            m.block("Hazard", (x, 1.77, k * .541), (.202, .404, .036), .014, axis=2)
            rivet(m, (x, .351, k * .562), (0, 0, k), .045)
    return m


def gate_panels():
    m = Model("gate_panels", .68)
    for wing in (-1, 1):
        x = wing * .872
        m.block("Graphite", (x, 1.602, 0), (1.714, 3.121, .647), .086, axis=2)
        for depth in (-1, 1):
            side = depth * .350
            m.profile("Alloy", [(x - .716, .324), (x + .71, .324), (x + .73, 2.537),
                                (x + .59, 2.84), (x - .573, 2.828), (x - .74, 2.58)],
                      .118, .046, axis=2, center=(0, 0, side))
            m.block("Ceramic", (x, 2.264, depth * .424), (1.24, .74, .046), .082, axis=2)
            m.block("Black", (x, .874, depth * .432), (1.296, .285, .039), .021, axis=2)
            for i in range(5):
                m.block("Steel", (x - .48 + i * .24, .865, depth * .461), (.076, .11, .020), .004, angle=.37, axis=2)
            m.block("Hazard", (x, .506, depth * .424), (1.30, .142, .025), .024, axis=2)
            for y in (.644, 1.746, 2.80):
                rivet(m, (x + wing * .608, y, depth * .430), (0, 0, depth), .038)
    return m


def relay():
    m = Model("relay_bunker", .51)
    m.profile("Concrete", [(-2.585, -2.213), (2.58, -2.214), (2.59, 1.83),
                            (2.211, 2.223), (-2.231, 2.22), (-2.59, 1.864)],
              3.86, .114, axis=1, center=(0, 1.971, 0))
    m.block("Graphite", (0, .245, 0), (5.287, .326, 4.533), .083, axis=1)
    m.block("Alloy", (0, 3.848, 0), (5.563, .325, 4.716), .128, axis=1)
    m.block("Black", (0, 1.423, 2.237), (2.122, 2.36, .175), .092, axis=2)
    for x in (-.467, .467):
        m.profile("Graphite", [(x - .405, .289), (x + .401, .289), (x + .417, 2.096),
                                (x + .258, 2.385), (x - .268, 2.396), (x - .418, 2.092)],
                  .159, .056, axis=2, center=(0, 0, 2.343))
        m.block("Alloy", (x, 1.41, 2.438), (.601, 1.387, .066), .079, axis=2)
        m.block("Hazard", (x, .647, 2.491), (.63, .157, .045), .026, axis=2)
    m.block("Black", (0, 2.825, 2.269), (2.158, .336, .094), .046, axis=2)
    for side in (-1, 1):
        x = side * 1.801
        for edge in (-1, 1):
            m.block("Graphite", (x, 1.733, edge * 2.249), (1.07, 2.768, .18), .097, axis=2)
            m.block("Alloy", (x, 2.009, edge * 2.354), (.858, 1.374, .065), .056, axis=2)
            for n in range(6):
                m.block("Black", (x, 1.534 + n * .175, edge * 2.400), (.674, .073, .035), .013, axis=2)
        m.block("IceLamp", (x, 3.007, 2.339), (.69, .050, .034), .011, axis=2)
        m.block("Graphite", (side * 2.568, 1.9, -.1), (.197, 2.517, 2.773), .056)
        for z in (-1.183, .871):
            m.tube("Alloy", (side * 2.674, .352, z), (side * 2.674, 3.637, z), .066, .053, 10)
            for y in (.52, 1.3, 2.9, 3.47):
                m.tube("Steel", (side * 2.674, y, z), (side * 2.674, y + .078, z), .087, .081, 10)
    m.block("Graphite", (.837, 4.13, -.702), (1.08, .318, 1.375), .08, axis=1)
    for n in range(5):
        m.block("Steel", (.45 + n * .18, 4.326, -.701), (.066, .08, .99), .019)
    m.tube("Alloy", (-1.1, 4.005, 0), (-1.1, 4.40, 0), .451, .269, 14)
    m.tube("Graphite", (-1.1, 4.31, 0), (-1.1, 6.455, 0), .107, .050, 12)
    for y in (4.78, 5.31, 5.71):
        m.tube("Steel", (-1.1, y, 0), (-1.1, y + .075, 0), .116, .086, 12)
    m.ellipsoid("IceLamp", (-1.1, 6.486, 0), (.103, .078, .103), 10, 5)
    return m


def station():
    m = Model("field_terminal", 1.09)
    m.block("Graphite", (0, .079, 0), (1.306, .14, .824), .048, axis=1)
    m.block("Concrete", (0, .171, 0), (1.119, .149, .647), .043, axis=1)
    m.profile("Alloy", [(.218, -.268), (.243, .230), (.618, .232), (.888, .157),
                         (1.047, -.249), (.513, -.293)], .613, .047)
    m.block("Graphite", (0, 1.05, 0), (1.238, .190, .772), .045, angle=-.61)
    m.block("Black", (0, 1.136, -.055), (1.068, .047, .583), .034, angle=-.61)
    for sign in (-1, 1):
        m.block("Ceramic", (sign * .329, .566, -.011), (.091, .535, .354), .035)
        for y in (.401, .55, .65):
            rivet(m, (sign * .379, y, .091), (sign, 0, 0), .025)
    return m


def supply_rack():
    m = Model("supply_rack", 1.16)
    m.block("Graphite", (0, .087, 0), (2.65, .153, 1.506), .043, axis=1)
    for x in (-.80, .80):
        m.block("Steel", (x, .144, 0), (.158, .094, 1.379), .024, axis=1)
    for x in (-.78, 0, .78):
        for level in range(2):
            c = (x, .397 + level * .531, 0)
            m.block("Graphite" if level == 0 else "Alloy", c, (.734, .482, 1.268), .057, axis=1)
            m.block("Ceramic", add(c, (0, .200, 0)), (.689, .117, 1.202), .037, axis=1)
            for side in (-1, 1):
                m.block("Black", add(c, (0, -.063, side * .643)), (.554, .174, .046), .023, axis=2)
                m.block("Hazard", add(c, (0, .011, side * .678)), (.413, .067, .025), .009, axis=2)
                m.block("Steel", add(c, (0, -.073, side * .695)), (.162, .052, .039), .012, axis=2)
                for foot in (-1, 1):
                    m.block("Alloy", add(c, (foot * .240, -.193, side * .627)), (.155, .089, .082), .021, axis=1)
    for x in (-1.044, 1.044):
        m.block("Alloy", (x, 1.428, .213), (.106, .532, .099), .024)
    m.block("Graphite", (0, 1.692, .218), (2.27, .374, .112), .038, axis=2)
    m.block("Hazard", (0, 1.515, .285), (2.18, .018, .021), .004, axis=2)
    return m


def drone():
    m = Model("supply_drone", 2.0)
    m.profile("Graphite", [(-.217, -.18), (-.111, -.272), (.143, -.266), (.220, -.139),
                            (.198, .171), (.103, .259), (-.131, .249), (-.222, .112)],
              .219, .046, axis=1)
    m.block("Ceramic", (0, .133, .008), (.327, .076, .388), .031, axis=1)
    m.block("Black", (0, .007, -.250), (.262, .095, .097), .023, axis=2)
    m.block("IceLamp", (0, .008, -.308), (.162, .044, .023), .007, axis=2)
    for side in (-1, 1):
        m.block("Hazard", (side * .209, .050, .042), (.064, .072, .209), .014)
        for direction in (-1, 1):
            m.tube("Alloy", (side * .151, .024, direction * .139), (side * .30, .025, direction * .27), .059, .038, 8)
    return m


def boulder(index):
    m = Model(f"eroded_boulder_{index}", 1.14)
    rng = Random(45 + index * 79)
    sides = 12
    angles = [(i + rng.uniform(-.35, .35)) * 2 * pi / sides for i in range(sides)]
    ridges = [rng.uniform(.72, 1.16) for _ in angles]
    rings = []
    for y, width in ((-.081, .75), (.10, 1.0), (.39, .89), (.64, .68), (.81, .41), (.88, .14)):
        shift = (rng.uniform(-.10, .10), 0, rng.uniform(-.18, .15))
        perimeter = [add((cos(a) * ramp * width * .60,
                          y + rng.uniform(-.085, .085),
                          sin(a) * ramp * width * .54), shift) for a, ramp in zip(angles, ridges)]
        rings.append(perimeter)
    for row, (low, high) in enumerate(zip(rings, rings[1:])):
        for i in range(sides):
            j = (i + 1) % sides
            a, b, c, d = low[i], low[j], high[j], high[i]
            facing = (a[0] + b[0], .21 if row > 2 else 0, a[2] + b[2])
            mat = "StoneDark" if row in (0, 2) and rng.random() > .30 else "Rock"
            m.face(mat, [a, b, c], facing)
            m.face(mat, [a, c, d], facing)
    m.face("Rock", rings[-1], (0, 1, 0))
    m.face("StoneDark", rings[0], (0, -1, 0))
    return m


def breach():
    m = Model("breach_debris", .72)
    rng = Random(281)
    for i in range(10):
        x = -1.72 + i * .37 + rng.uniform(-.10, .10)
        y = rng.uniform(.055, .17)
        z = rng.uniform(-.31, .31)
        m.block("Concrete", (x, y, z), (rng.uniform(.17, .48), rng.uniform(.12, .28), rng.uniform(.18, .44)),
                .044, angle=rng.uniform(-.90, .82), axis=2)
    for side in (-1, 1):
        m.tube("Alloy", (side * 1.65, .12, .21), (side * 1.02, .26, .29), .022, .017, 8)
    return m


def watchtower():
    m = Model("watchtower_frame", .54)
    for x in (-1.32, 1.32):
        for z in (-1.20, 1.20):
            m.block("Concrete", (x, .19, z), (.80, .37, .76), .082, axis=1)
            m.block("Graphite", (x, 3.72, z), (.262, 7.18, .258), .054)
            m.block("Alloy", (x, .82, z), (.295, .91, .287), .059)
            for y in (2.31, 4.60, 6.87):
                m.block("Ceramic", (x, y, z), (.314, .202, .316), .032)
                rivet(m, (x, y, z + .170), (0, 0, 1), .042)
    for y in (2.50, 4.74, 7.14):
        for z in (-1.20, 1.20):
            m.block("Graphite", (0, y, z), (2.73, .19, .188), .037, axis=1)
        for x in (-1.32, 1.32):
            m.block("Graphite", (x, y, 0), (.195, .205, 2.50), .037, axis=1)
    for z in (-1.18, 1.18):
        for lower, high in ((.62, 2.36), (2.65, 4.64), (4.86, 6.95)):
            m.tube("Alloy", (-1.31, lower, z), (1.31, high, z), .074, .072, 6, smooth=False)
    for x in (-1.29, 1.29):
        for z in (-1.0, 1.0):
            m.block("Hazard", (x, 7.00, z), (.29, .143, .18), .041)
        m.tube("Alloy", (x, 2.61, 1.16), (x, 4.62, -1.16), .073, .073, 6, smooth=False)
        m.tube("Alloy", (x, 4.83, -1.16), (x, 6.95, 1.16), .073, .073, 6, smooth=False)
    m.block("Alloy", (0, 7.212, 0), (3.48, .263, 3.245), .052, axis=1)
    m.block("Graphite", (0, 7.102, 0), (3.51, .138, 3.285), .039, axis=1)
    for j in range(12):
        m.block("Steel", (0, 7.345, -1.395 + j * .253), (3.33, .013, .051), .004, axis=1)
    for x in (-1.575, 1.575):
        m.block("Hazard", (x, 7.367, 0), (.091, .015, 2.97), .004, axis=1)
    return m


def screen_rock():
    m = Model("sandstone_screen", .27)
    rng = Random(702)
    perimeter = [(-1, -.70), (-.90, -1), (-.36, -.94), (.05, -1), (.51, -.92),
                 (.86, -.98), (1, -.64), (1, .73), (.84, 1), (.32, .95), (-.14, 1),
                 (-.62, .92), (-.89, 1), (-1, .65)]
    rings = []
    for height, width, depth in ((-.17, 7.45, 3.15), (1.48, 7.18, 3.14), (1.92, 7.09, 2.79),
                                 (3.29, 7.21, 2.91), (3.77, 6.94, 2.60), (5.46, 7.13, 2.84),
                                 (5.92, 6.96, 2.63), (7.02, 6.77, 2.53), (7.58, 6.29, 2.34),
                                 (8.35, 5.49, 2.04), (8.89, 4.20, 1.57)):
        rings.append([(x * width + rng.uniform(-.15, .15),
                       height + rng.uniform(-.38, .43), z * depth + rng.uniform(-.16, .16))
                      for x, z in perimeter])
    for band, (bottom, top) in enumerate(zip(rings, rings[1:])):
        for i in range(len(perimeter)):
            j = (i + 1) % len(perimeter)
            a, b, c, d = bottom[i], bottom[j], top[j], top[i]
            facing = (a[0] + b[0], .22 if band > 3 else 0, a[2] + b[2])
            finish = "StoneDark" if band in (1, 3, 5) and rng.random() > .12 else "Rock"
            m.face(finish, [a, b, c], facing)
            m.face(finish, [a, c, d], facing)
    m.face("Rock", rings[-1], (0, 1, 0))
    return m


def mesa():
    m = Model("tabletop_mesa", .86)
    rng = Random(1829)
    angles = [(i + rng.uniform(-.17, .17)) * pi / 8 for i in range(16)]
    perimeter = [(cos(a) * rng.uniform(.46, .59), sin(a) * rng.uniform(.42, .59)) for a in angles]
    rims = ((-.04, 1.18), (.17, 1.03), (.34, .91), (.42, .87), (.46, .77),
            (.61, .74), (.67, .66), (.72, .69), (.94, .56), (.99, .43))
    rings = []
    for y, width in rims:
        rings.append([(x * width + .09 * sin(y * 6.3), y + rng.uniform(-.052, .052), z * width)
                      for x, z in perimeter])
    sides = len(perimeter)
    for band, (base, top) in enumerate(zip(rings, rings[1:])):
        for i in range(sides):
            j = (i + 1) % sides
            a, b, c, d = base[i], base[j], top[j], top[i]
            facing = (a[0] + b[0], .10, a[2] + b[2])
            finish = "StoneDark" if band in (3, 6) else "Rock"
            u = .26 * i
            v = -rims[band][0] * 2.0
            upper = -rims[band + 1][0] * 2.0
            m.face(finish, [a, b, c, d], facing, uv=[(u, v), (u + .26, v), (u + .26, upper), (u, upper)])
    m.face("Rock", rings[-1], (0, 1, 0))
    return m


def scrub():
    m = Model("ironleaf_scrub", 1.0)
    rng = Random(7103)
    for i in range(12):
        yaw = i * 2.399
        axis = (sin(yaw), 0, cos(yaw))
        side = (cos(yaw), 0, -sin(yaw))
        length = rng.uniform(.22, .51)
        height = rng.uniform(.24, .71)
        width = rng.uniform(.042, .097)
        root = add(mul(axis, .055), (0, .031, 0))
        middle = add(mul(axis, length * .53), (0, height * .65, 0))
        blade = add(mul(axis, length), (0, height, 0))
        left, right = add(middle, mul(side, width)), add(middle, mul(side, -width))
        keel = add(middle, (0, -.04, 0))
        for a, b, c in ((root, left, keel), (root, keel, right)):
            m.face("DryLeaf", [a, b, c], (0, 1, 0))
        m.face("RedLeaf", [left, blade, keel], (0, 1, 0))
        m.face("RedLeaf", [right, keel, blade], (0, 1, 0))
    return m


def main():
    OUTPUT.mkdir(parents=True, exist_ok=True)
    models = (rifle(), rifle_magazine(), rifle_support(), repair_tool(), turret_base(), turret_head(), turret_emitters(), turret_wreck(),
              beetle(), beetle_leg(-1), beetle_leg(1), beetle_claw(-1), beetle_claw(1), wall(), blocker(), gate_panels(), relay(), station(),
              supply_rack(), drone(), breach(), watchtower(), screen_rock(), mesa(), scrub(), *(boulder(i) for i in range(1, 4)))
    for model in models:
        model.write()


if __name__ == "__main__":
    main()
