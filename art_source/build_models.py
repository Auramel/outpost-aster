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
    "DuneChitin": ("f4e9dd", 0.03, 0.51),
    "DuneSinew": ("583b29", 0.0, 0.70),
    "DuneEyeLamp": ("d8973a", 0.0, 0.41, 0.55),
    "DuneWing": ("ffffff", 0.0, 0.47),
    "IceLamp": ("78dcff", 0.0, 0.55, 0.8),
    "AmberLamp": ("ffc47c", 0.0, 0.54, 0.55),
    "CarbineSatin": ("a8b7c7", 0.45, 0.43),
    "CarbineAccent": ("ac5132", 0.26, 0.63),
    "GripPolymer": ("353b43", 0.0, 0.78),
    "GloveFabric": ("525c66", 0.0, 0.85),
    "ColdReceiver": ("5a6779", 0.42, 0.55),
    "Cowl": ("4d5648", 0.25, 0.66),
    "SignalLamp": ("db4637", 0.0, 0.53, 0.52),
    "TurretEnamel": ("788378", 0.28, 0.62),
    "TurretCast": ("818b91", 0.45, 0.49),
    "TurretScanLamp": ("53bcb3", 0.22, 0.29, 0.62),
    "CharredTurret": ("464034", 0.32, 0.78),
    "BarrelSteel": ("454b51", 0.48, 0.53),
    "ScuffedEdge": ("81868a", 0.46, 0.61),
    "OliveMetal": ("77725b", 0.43, 0.46),
    "CanyonLedge": ("e4dacd", 0.0, 0.89),
    "CanyonShade": ("b9a79b", 0.0, 0.92),
    "BunkerConcrete": ("c2c7c2", 0.0, 0.86),
    "BunkerArmor": ("b7bdc0", 0.28, 0.69),
    "BunkerRim": ("889ba2", 0.40, 0.55),
    "DryLeaf": ("625338", 0.0, 0.85),
    "RedLeaf": ("9e4c39", 0.0, 0.67),
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


def carbine_frame(model):
    """Beveled sidewalls around the open stock, with a real void through the mesh."""
    outer = [(.073, -.152), (.119, .092), (.107, .406), (.059, .498),
             (-.174, .508), (-.241, .440), (-.290, .127), (-.227, .015),
             (-.151, -.142), (-.041, -.235)]
    window = [(.009, -.092), (.029, .103), (.018, .353), (-.016, .399),
              (-.126, .408), (-.178, .365), (-.222, .141), (-.179, .049),
              (-.122, -.046), (-.040, -.123)]
    for i in range(len(outer)):
        j = (i + 1) % len(outer)
        for side in (-1, 1):
            outside = [(side * .084, *outer[k]) for k in (i, j)]
            rim = [(side * .110, *mix(outer[k], window[k], .19)) for k in (i, j)]
            lip = [(side * .105, *mix(window[k], outer[k], .16)) for k in (i, j)]
            inside = [(side * .081, *window[k]) for k in (i, j)]
            facing = (side, 0, 0)
            model.face("CarbineSatin", [*outside, *rim[::-1]], facing)
            model.face("CarbineSatin", [*rim, *lip[::-1]], facing)
            model.face("Black", [*lip, *inside[::-1]], facing)
        for profile, depth, orientation in ((outer, .084, 1), (window, .081, -1)):
            face = [(-depth, *profile[i]), (-depth, *profile[j]), (depth, *profile[j]), (depth, *profile[i])]
            model.face("Black" if orientation < 0 else "CarbineSatin", face,
                       mul(sub(mean(face), (0, *mean(profile))), orientation))


def carbine_glove(model, *, leading=False):
    """Sculpt one held pose used by the carbine's two viewmodel hands."""
    sign = -1 if leading else 1
    palm = (.026 * sign, -.010, .028)
    wrist = (sign * .015, -.064, .100)
    cuff = (sign * .065, -.115, .327 if leading else .249)
    model.tube("GloveFabric", wrist, cuff, .061, .084, sides=12, section=(.92, 1))
    model.tube("Graphite", mix(wrist, cuff, .67), mix(wrist, cuff, .96), .081, .093, sides=10, section=(.93, 1))
    model.ellipsoid("GripPolymer", palm, (.069, .049, .087), sides=12, rows=7)
    model.block("GloveFabric", (sign * .062, .008, .024), (.042, .070, .105), .014, axis=0)
    for digit in range(4):
        z = -.045 + digit * .023
        fold = (.007 if leading else -.007, .020 + .003 * digit, z)
        pad = (-sign * (.051 - digit * .004), .018, z + .013)
        model.tube("GripPolymer", (sign * .041, -.017, z - .010), fold, .016, .015, sides=8)
        model.tube("GripPolymer", fold, pad, .015, .012, sides=8)
        model.block("GloveFabric", (sign * .040, .010, z), (.028, .024, .021), .005)
    model.ellipsoid("GripPolymer", (sign * .057, .028, .061), (.021, .025, .053), sides=10, rows=5)


def carbine_sight(model):
    model.block("Black", (0, .173, -.081), (.177, .033, .139), .011)
    for side in (-1, 1):
        # A low fork leaves a clean line through the window and gives the halo its shape.
        model.profile("CarbineSatin", [(side * .053, .185), (side * .091, .181),
                                      (side * .074, .250), (side * .048, .270),
                                      (side * .038, .249), (side * .050, .224)],
                      .077, .005, axis=2, center=(0, 0, -.098))
        model.block("IceLamp", (side * .059, .206, -.051), (.010, .008, .005), .002)
        model.block("Black", (side * .023, .163, -.825), (.018, .036, .052), .006)
    model.block("CarbineSatin", (0, .262, -.104), (.117, .019, .070), .006)
    model.block("Black", (0, .170, -.831), (.068, .019, .060), .006)
    model.block("Steel", (0, .186, -.835), (.012, .022, .022), .003)
    model.block("IceLamp", (0, .197, -.836), (.009, .005, .017), .002)


def rifle():
    m = Model("aster_carbine", 4.5)
    # Continuous upper chassis and the two offset rails of the split front.
    m.profile("CarbineSatin", [(-.096, -.579), (.092, -.570), (.150, -.385),
                              (.149, .002), (.092, .137), (-.079, .110), (-.140, -.158)], .233, .024)
    m.profile("Graphite", [(-.129, -.480), (.034, -.459), (.061, -.300),
                           (-.010, -.153), (-.107, -.105), (-.158, -.174), (-.168, -.378)], .221, .018)
    m.profile("CarbineSatin", [(.068, -.975), (.119, -.972), (.159, -.912), (.166, -.555),
                              (.158, -.346), (.110, -.319), (.074, -.444)], .227, .017)
    m.profile("CarbineSatin", [(-.163, -.952), (-.110, -.984), (-.087, -.932),
                              (-.092, -.546), (-.105, -.451), (-.155, -.442),
                              (-.188, -.553), (-.185, -.855)], .228, .016)
    m.profile("Graphite", [(-.175, -.928), (-.132, -.900), (-.115, -.654),
                           (-.138, -.519), (-.183, -.527), (-.196, -.815)], .197, .011)
    m.block("Black", (0, -.122, -.633), (.144, .059, .388), .014, axis=1)
    m.tube("BarrelSteel", (0, .027, -.396), (0, .027, -.967), .057, .040, sides=14)
    for z in (-.826, -.691, -.545):
        m.tube("Graphite", (0, .027, z + .031), (0, .027, z - .022), .066, .063, sides=10, section=(1.05, 1))
        m.tube("BarrelSteel", (0, .027, z - .020), (0, .027, z - .035), .064, .060, sides=10)
    m.tube("BarrelSteel", (0, .027, -.947), (0, .027, -.987), .047, .042, sides=14)
    m.tube("Black", (0, .027, -.978), (0, .027, -.995), .033, .026, sides=12)
    carbine_frame(m)
    m.profile("Graphite", [(-.070, .014), (.009, .071), (-.006, .132),
                           (-.096, .143), (-.222, .224), (-.206, .120), (-.141, .060)], .109, .014)
    m.profile("GripPolymer", [(-.116, .071), (-.091, .111), (-.119, .167),
                              (-.208, .213), (-.217, .166), (-.168, .095)], .125, .014)
    m.profile("Black", [(-.161, .459), (.033, .450), (.067, .490),
                        (.050, .516), (-.179, .553), (-.204, .507)], .232, .020)
    m.block("GripPolymer", (0, .109, .270), (.173, .016, .243), .006, axis=1)
    for z in (.196, .222, .318, .344):
        m.block("Graphite", (0, .118, z), (.128, .004, .008), .0018, axis=1)
    m.block("Black", (0, -.103, -.268), (.191, .054, .234), .010, axis=1)
    m.block("CarbineAccent", (.005, -.080, -.012), (.026, .049, .018), .004)

    for side in (-1, 1):
        x = side * .12
        m.profile("Graphite", [(.095, -.922), (.126, -.902), (.137, -.466),
                               (.111, -.399), (.092, -.483)],
                  .010, .003, center=(x, 0, 0))
        m.profile("CarbineSatin", [(-.156, -.925), (-.121, -.941), (-.115, -.685),
                                  (-.090, -.607), (-.126, -.522), (-.152, -.586), (-.171, -.800)],
                  .032, .007, center=(side * .108, 0, 0))
        for z in (-.865, -.729, -.603):
            m.block("Black", (side * .130, -.131, z), (.015, .056, .063), .007, angle=-.32)
            m.block("IceLamp", (side * .139, -.119, z - .005), (.007, .008, .028), .0015, angle=-.28)
        for z in (-.820, -.684, -.547):
            m.profile("BarrelSteel", [(-.079, z - .04), (-.040, z - .027),
                                      (.077, z + .021), (.076, z + .054),
                                      (.028, z + .034), (-.085, z - .001)],
                      .022, .006, center=(side * .088, 0, 0))
        m.profile("CarbineSatin", [(.029, -.447), (.115, -.411), (.139, -.194), (.107, -.173),
                                  (.087, .061), (.046, .078), (-.017, .043), (-.017, -.324)],
                  .038, .010, center=(side * .116, 0, 0))
        m.profile("Graphite", [(-.070, -.423), (-.028, -.389), (-.028, -.198),
                               (-.063, -.083), (-.107, -.142), (-.109, -.325)],
                  .030, .009, center=(side * .115, 0, 0))
        m.block("Black", (side * .140, .074, -.291), (.014, .045, .207), .008)
        m.block("CarbineSatin", (side * .149, .081, -.296), (.006, .008, .174), .002)
        for lane in range(4):
            m.block("IceLamp", (side * .150, .073, -.351 + lane * .034),
                    (.006, .016, .013), .002, angle=-.31)
        m.block("Black", (side * .138, .050, -.049), (.015, .056, .132), .009)
        m.block("BarrelSteel", (side * .147, .047, -.048), (.007, .026, .090), .003)
        m.profile("CarbineAccent", [(-.012, .037), (.016, .038), (.041, .084), (.034, .116), (-.007, .085)],
                  .014, .004, center=(side * .121, 0, 0))
        m.block("ScuffedEdge", (side * .124, -.072, -.270), (.005, .009, .105), .002)
        m.block("ScuffedEdge", (side * .115, -.199, .195), (.006, .011, .116), .002, angle=.12)
        for z in (-.924, -.491, .169, .437):
            y = .109 if z < -.4 else (-.221 if z < .3 else -.158)
            rivet(m, (side * (.112 if z > 0 else .116), y, z), (side, 0, 0), .009, "ScuffedEdge")
    for z in (-.722, -.602, -.469, -.343, -.245):
        m.block("Graphite", (0, .157, z), (.104, .024, .060), .006, angle=.20, axis=1)
    m.block("Black", (-.077, .147, -.237), (.054, .010, .122), .005, axis=1)
    for z in (-.275, -.242, -.210):
        m.block("IceLamp", (-.073, .154, z), (.025, .005, .011), .002, axis=1)
    carbine_sight(m)
    return m


def rifle_magazine():
    m = Model("aster_carbine_magazine", 4.9)
    m.profile("CarbineSatin", [(.021, -.100), (.016, .087), (-.095, .102),
                              (-.178, .065), (-.213, -.057), (-.164, -.096)], .150, .014)
    m.profile("GripPolymer", [(-.153, -.108), (-.174, .057), (-.204, .074),
                              (-.229, .063), (-.246, -.064), (-.210, -.115)], .163, .015)
    for side in (-1, 1):
        m.profile("Graphite", [(-.026, -.059), (-.036, .062), (-.102, .074),
                               (-.162, .042), (-.175, -.046)], .018, .005,
                  center=(side * .076, 0, 0))
        for z in (-.033, .012, .054):
            m.block("BarrelSteel", (side * .088, -.086, z), (.009, .051, .019), .003, angle=-.25)
        m.block("ScuffedEdge", (side * .084, -.129, -.025), (.006, .009, .047), .002)
    return m


def rifle_hand(leading):
    m = Model("aster_carbine_support" if leading else "aster_carbine_grip", 4.5)
    carbine_glove(m, leading=leading)
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
    m = Model("turret_base", 2.45)
    m.tube("TurretCast", (0, .022, 0), (0, .063, 0), .737, .750, sides=20, smooth=False)
    m.tube("TurretEnamel", (0, .061, 0), (0, .114, 0), .750, .695, sides=20, smooth=False)
    m.tube("Black", (0, .114, 0), (0, .269, 0), .629, .514, sides=18, smooth=False)
    m.tube("TurretCast", (0, .254, 0), (0, .316, 0), .531, .565, sides=20)
    m.tube("ScuffedEdge", (0, .318, 0), (0, .344, 0), .573, .578, sides=24)
    m.tube("TurretEnamel", (0, .345, 0), (0, .400, 0), .579, .579, sides=24)
    m.tube("Black", (0, .400, 0), (0, .455, 0), .553, .529, sides=20)
    for index in range(14):
        angle = 2 * pi * index / 14
        radial = (sin(angle), 0, cos(angle))
        # Center each chiseled rib in a spoke of the supporting cone.
        inner = add(mul(radial, .535), (0, .245, 0))
        outer = add(mul(radial, .653), (0, .110, 0))
        tangent = (cos(angle), 0, -sin(angle))
        near = [add(outer, mul(tangent, side * .044)) for side in (-1, 1)]
        far = [add(inner, mul(tangent, side * .034)) for side in (-1, 1)]
        m.face("TurretEnamel", [*near, *far[::-1]], add(radial, (0, .62, 0)))
        rear = [sub(point, mul(radial, .042)) for point in near + far]
        for side in (0, 1):
            m.face("TurretCast", [near[side], far[side], rear[side + 2], rear[side]],
                   mul(tangent, 1 if side else -1))
        bolt = add(mul(radial, .703), (0, .101, 0))
        rivet(m, bolt, (0, 1, 0), .022, "ScuffedEdge")
    for index in range(8):
        angle = 2 * pi * (index + .5) / 8
        at = (sin(angle) * .577, .353, cos(angle) * .577)
        m.block("TurretCast", at, (.077, .139, .046), .010, angle=-angle, axis=1)
    m.block("Black", (0, .175, .623), (.215, .064, .043), .006, axis=2)
    for x in (-.065, 0, .065):
        m.block("Hazard", (x, .175, .646), (.036, .027, .007), .002, angle=.37, axis=2)
    return m


def turret_head():
    m = Model("turret_head", 2.35)
    m.tube("TurretEnamel", (0, -.387, 0), (0, -.272, 0), .466, .496, sides=18)
    m.tube("ScuffedEdge", (0, -.269, 0), (0, -.244, 0), .495, .493, sides=22)
    m.profile("TurretEnamel", [(-.283, .405), (.078, .548), (.229, .413), (.285, -.084),
                               (.145, -.403), (-.104, -.479), (-.267, -.304)], .903, .050)
    m.block("TurretCast", (0, -.219, -.419), (.730, .218, .204), .037, axis=2)
    m.block("TurretEnamel", (0, .195, -.251), (.604, .216, .346), .044, axis=1)
    m.block("TurretCast", (0, .313, -.175), (.506, .062, .303), .017, axis=1)
    for side in (-1, 1):
        # Tall, swept trunnion cheeks give the elevation carriage a cradle.
        m.profile("TurretCast", [(-.220, -.243), (.296, -.119), (.424, .177), (.341, .452),
                                 (.032, .490), (-.251, .218)], .146, .026,
                  center=(side * .509, 0, 0))
        m.profile("TurretEnamel", [(-.177, -.236), (.278, -.096), (.358, .208), (.278, .374),
                                   (.021, .396), (-.210, .167)], .091, .021,
                  center=(side * .566, .040, 0))
        m.tube("Black", (side * .582, .014, 0), (side * .624, .014, 0), .224, .202, sides=16)
        m.tube("ScuffedEdge", (side * .623, .014, 0), (side * .641, .014, 0), .175, .167, sides=18)
        m.tube("TurretCast", (side * .642, .014, 0), (side * .669, .014, 0), .155, .138, sides=16)
        m.tube("TurretEnamel", (side * .669, .014, 0), (side * .684, .014, 0), .058, .047, sides=10)
        for z in (-.235, .12, .420):
            rivet(m, (side * .585, -.152 if z < 0 else .241, z), (side, 0, 0), .024, "ScuffedEdge")
        m.block("TurretCast", (side * .341, .344, .158), (.242, .177, .412), .038, axis=1)
        m.block("Black", (side * .342, .435, .167), (.157, .018, .284), .006, axis=1)
        for row in range(4):
            m.block("TurretEnamel", (side * .342, .452, .066 + row * .065), (.153, .027, .019), .004, axis=1)

        # Side cassettes carry rangefinder elements and inset louvers.
        cx = side * .724
        m.block("TurretCast", (cx, .096, .283), (.285, .420, .352), .035, axis=2)
        m.block("TurretEnamel", (cx, .109, .216), (.249, .367, .300), .025, axis=2)
        m.block("Black", (cx, .106, .061), (.219, .313, .026), .012, axis=2)
        if side < 0:
            for i in range(3):
                for j in range(2):
                    x, y = cx + (j - .5) * .096, .101 + (i - 1) * .090
                    m.tube("TurretCast", (x, y, .055), (x, y, .032), .039, .036, sides=9)
                    m.tube("Black", (x, y, .033), (x, y, .029), .025, .021, sides=9)
        else:
            for i in range(5):
                m.block("TurretCast", (cx, -.011 + i * .057, .042), (.174, .024, .025), .004, angle=.08, axis=2)
            m.block("TurretScanLamp", (cx, .251, .038), (.080, .011, .008), .002, axis=2)
        m.block("TurretScanLamp", (side * .871, .227, .207), (.009, .025, .042), .004)
        m.block("Black", (side * .862, .101, .283), (.029, .257, .131), .008)
        for z in (.205, .335):
            rivet(m, (side * .881, .042, z), (side, 0, 0), .016, "ScuffedEdge")

    # Faceted sensor with a cyan lens and a separate small red status light.
    m.block("TurretCast", (0, .219, -.452), (.365, .255, .182), .029, axis=2)
    m.block("Black", (0, .219, -.550), (.300, .192, .034), .019, axis=2)
    m.tube("ScuffedEdge", (0, .232, -.568), (0, .232, -.592), .080, .075, sides=12)
    m.ellipsoid("TurretScanLamp", (0, .232, -.589), (.062, .052, .024), sides=16, rows=6)
    m.block("SignalLamp", (.109, .175, -.578), (.031, .020, .009), .004, axis=2)
    m.block("Black", (0, -.264, .487), (.289, .107, .168), .019, axis=1)
    m.profile("TurretEnamel", [(.239, .157), (.316, .146), (.443, .211),
                               (.444, .356), (.288, .396), (.239, .346)], .207, .019)
    m.profile("TurretCast", [(.410, .169), (.557, .187), (.566, .358), (.484, .408), (.411, .384)], .282, .021)
    m.block("TurretEnamel", (0, .559, .273), (.303, .058, .240), .019, axis=1)
    m.block("TurretScanLamp", (0, .589, .214), (.132, .008, .023), .002, axis=1)
    return m


def turret_emitters():
    m = Model("turret_emitters", 2.8)
    m.block("TurretCast", (0, -.101, -.282), (.659, .123, .211), .028, axis=1)
    for side in (-1, 1):
        x, y = side * .410, .014
        m.profile("TurretEnamel", [(-.135, .124), (.083, .146), (.158, -.196), (.129, -.590),
                                   (.056, -.690), (-.096, -.478), (-.148, -.148)], .255, .025,
                  center=(x, 0, 0))
        m.block("TurretCast", (x, .123, -.420), (.184, .119, .395), .022, axis=1)
        m.block("Black", (x + side * .127, .081, -.211), (.019, .084, .146), .009)
        m.block("ScuffedEdge", (x + side * .140, .077, -.223), (.010, .040, .086), .005)
        for z in (-.045, -.536):
            rivet(m, (x + side * .134, .093, z), (side, 0, 0), .019, "ScuffedEdge")
        m.tube("TurretCast", (x, y, -.552), (x, y, -.754), .144, .132, sides=16)
        m.tube("ScuffedEdge", (x, y, -.733), (x, y, -.773), .135, .127, sides=16)
        m.tube("BarrelSteel", (x, y, -.755), (x, y, -1.328), .081, .065, sides=14)
        m.tube("TurretCast", (x, y, -1.152), (x, y, -1.204), .098, .101, sides=14)
        m.tube("BarrelSteel", (x, y, -1.203), (x, y, -1.550), .097, .096, sides=16)
        for ring in range(5):
            angle = 2 * pi * ring / 5
            for z in (-1.265, -1.377, -1.482):
                offset = (.094 * cos(angle), .094 * sin(angle), z)
                m.block("Black", add((x, y, 0), offset), (.029, .009, .063), .002, angle=angle - pi / 2, axis=2)
        # An inset dark face leaves a visible recess inside the chamfered outer rim.
        rim = [(1.544, .095), (1.574, .105), (1.612, .080), (1.613, .050),
               (1.587, .043), (1.556, .042)]
        for (a, ra), (b, rb) in zip(rim, rim[1:]):
            ring_a = [(x + ra * cos(i * pi / 9), y + ra * sin(i * pi / 9), -a) for i in range(18)]
            ring_b = [(x + rb * cos(i * pi / 9), y + rb * sin(i * pi / 9), -b) for i in range(18)]
            for i in range(18):
                j = (i + 1) % 18
                face = [ring_a[i], ring_a[j], ring_b[j], ring_b[i]]
                center = mean(face)
                radial = (center[0] - x, center[1] - y, 0)
                facing = add(radial, (0, 0, -.17)) if b > a else mul(radial, -1)
                m.face("BarrelSteel" if b > a else "Black", face, facing)
        m.tube("Black", (x, y, -1.536), (x, y, -1.555), .042, .042, sides=14)
        m.block("TurretEnamel", (x, .112, -1.003), (.105, .072, .353), .012, axis=1)
        m.block("Black", (x, .154, -1.009), (.075, .025, .303), .006, axis=1)
        m.block("TurretCast", (x, .117, -1.416), (.108, .081, .060), .016, axis=2)
    return m


def turret_cartridge():
    m = Model("turret_cartridge", 3.0)
    m.block("TurretEnamel", (0, .008, .049), (.392, .316, .318), .027, axis=2)
    m.block("TurretCast", (0, .147, .047), (.408, .075, .330), .019, axis=1)
    m.block("Black", (0, .072, .211), (.148, .038, .019), .008, axis=2)
    m.block("Hazard", (0, -.042, .215), (.130, .065, .008), .007, axis=2)
    for x in (-.133, .133):
        m.block("ScuffedEdge", (x, .014, .212), (.032, .139, .014), .004, axis=2)
    return m


def turret_wreck():
    m = Model("turret_wreck", 2.05)
    m.tube("TurretCast", (0, .403, 0), (0, .519, 0), .465, .456, sides=15)
    m.profile("TurretEnamel", [(.371, -.366), (.582, -.396), (.745, -.271),
                                (.769, .235), (.613, .462), (.445, .341)], .822, .050)
    m.block("TurretCast", (-.374, .571, -.174), (.290, .214, .345), .033, angle=-.41, axis=1)
    m.block("Hazard", (.225, .619, .270), (.348, .119, .353), .017, angle=-.23, axis=0)
    for side in (-1, 1):
        start = (side * .218, .60, -.234)
        m.tube("CharredTurret", start, (side * .438, .427, -.625), .108, .079, sides=10)
        m.tube("Black", (side * .438, .427, -.617), (side * .449, .417, -.644), .065, .064, sides=9)
    return m


def cuticle_loft(model, sections, *, sides=10, up=(0, 1, 0), axis=None,
                  uv_span=(0.0, 1.0), lip=False, ridged=False, finish="DuneChitin"):
    """Sweep a fitted section along an anatomical curve, with its UVs following the growth rings."""
    rings = []
    for index, (center, width, height) in enumerate(sections):
        if axis is None:
            before = sections[max(0, index - 1)][0]
            after = sections[min(len(sections) - 1, index + 1)][0]
            along = norm(sub(after, before))
        else:
            along = axis
        across = norm(cross(up, along))
        crown = cross(along, across)
        row = []
        for spoke in range(sides):
            angle = 2 * pi * spoke / sides
            x, y = sin(angle), cos(angle)
            if ridged and y > 0:
                y = (1 - abs(x)) ** .88
            if lip:
                x *= 1.11 - 0.11 * abs(y)
                y *= 1.0 if y >= 0 else 0.55
            row.append(add(center, add(mul(across, width * x), mul(crown, height * y))))
        rings.append(row)

    normals = []
    for index, row in enumerate(rings):
        before = rings[max(0, index - 1)]
        after = rings[min(len(rings) - 1, index + 1)]
        normals.append([
            norm(cross(sub(after[spoke], before[spoke]), sub(row[(spoke + 1) % sides], row[spoke - 1])))
            for spoke in range(sides)
        ])
    v0, v1 = uv_span
    for index, (near, far) in enumerate(zip(rings, rings[1:])):
        for spoke in range(sides):
            following = (spoke + 1) % sides
            corners = ((index, spoke), (index, following), (index + 1, following), (index + 1, spoke))
            points = [near[spoke], near[following], far[following], far[spoke]]
            face_normals = [normals[row][column] for row, column in corners]
            if dot(mean(face_normals), sub(mean(points), mix(sections[index][0], sections[index + 1][0], .5))) < 0:
                face_normals = [mul(normal, -1) for normal in face_normals]
            u0, u1 = spoke / sides, (spoke + 1) / sides
            va = v0 + (v1 - v0) * index / (len(rings) - 1)
            vb = v0 + (v1 - v0) * (index + 1) / (len(rings) - 1)
            model.face(finish, points, mean(face_normals), face_normals, [(u0, va), (u1, va), (u1, vb), (u0, vb)])
    for index, neighbor in ((0, 1), (-1, -2)):
        face_direction = sub(sections[index][0], sections[neighbor][0])
        cap_uv = [(.54 + sin(2 * pi * spoke / sides) * .045, .53 + cos(2 * pi * spoke / sides) * .045)
                  for spoke in range(sides)]
        model.face(finish, rings[index], face_direction, uv=cap_uv)


def beetle():
    model = Model("dune_beetle", 1.9)
    # The carapace widens from a narrow brow to two swept-back shoulder points.
    cuticle_loft(model, [
        ((0, .552, -1.093), .006, .006), ((0, .570, -1.013), .097, .053),
        ((0, .595, -.816), .190, .140), ((0, .626, -.532), .302, .233),
        ((0, .661, -.220), .420, .325), ((0, .700, .110), .544, .406),
        ((0, .749, .360), .611, .455), ((0, .746, .446), .630, .371),
        ((0, .718, .512), .551, .235), ((0, .686, .625), .368, .129),
        ((0, .681, .741), .190, .075),
    ], sides=16, axis=(0, 0, 1), lip=True, ridged=True, uv_span=(.02, .98))
    model.ellipsoid("DuneSinew", (0, .518, .051), (.395, .239, .653), sides=16, rows=8)
    model.ellipsoid("DuneSinew", (0, .477, -.667), (.251, .143, .301), sides=12, rows=6)
    for side in (-1, 1):
        # The flank plates sit under the lip so the triangular brow stays continuous.
        cuticle_loft(model, [
            ((side * .210, .496, -.711), .032, .034),
            ((side * .322, .535, -.415), .074, .072),
            ((side * .413, .574, -.052), .097, .122),
            ((side * .478, .620, .287), .105, .133),
            ((side * .523, .679, .497), .073, .086),
            ((side * .640, .756, .581), .002, .003),
        ], sides=8, uv_span=(.11, .86), lip=True, ridged=True)
        for index in range(5):
            z = -.51 + index * .219
            x = .261 + index * .032
            cuticle_loft(model, [
                ((side * x, .338, z + .042), .034, .028),
                ((side * (x + .091), .414, z + .017), .064, .048),
                ((side * (x + .110), .508, z + .084), .061, .045),
                ((side * (x + .099), .574, z + .178), .014, .014),
            ], sides=8, uv_span=(.30 + index * .077, .64 + index * .052))
        for x, y, z in ((.260, .538, -.535), (.315, .579, -.155), (.295, .573, .403)):
            model.ellipsoid("DuneSinew", (side * x, y - .023, z), (.121, .115, .125), sides=10, rows=5)
        # A narrow amber eye sits between the brow and hooked mandibles.
        a = (side * .135, .533, -.938)
        b = (side * .203, .565, -.786)
        model.tube("DuneSinew", a, b, .034, .040, 8, section=(.83, .66))
        cuticle_loft(model, [
            ((side * .150, .541, -.940), .003, .003),
            ((side * .185, .543, -.880), .013, .014),
            ((side * .215, .553, -.817), .020, .013),
            ((side * .225, .562, -.788), .004, .004),
        ], sides=8, finish="DuneEyeLamp")
        for inset in (0.0, .069):
            cuticle_loft(model, [
                ((side * (.247 - inset), .469, -.702), .060, .068),
                ((side * (.244 - inset), .430, -.806), .060, .055),
                ((side * (.211 - inset), .392, -.904), .048, .043),
                ((side * (.161 - inset * .77), .344 + inset * .33, -1.006), .028, .027),
                ((side * (.085 - inset * .52), .297 + inset, -1.127 + inset), .002, .004),
            ], sides=8, uv_span=(.34, .87), lip=True, ridged=True)
    cuticle_loft(model, [
        ((0, .467, -.814), .062, .059), ((0, .403, -.941), .050, .034),
        ((0, .323, -1.049), .027, .028), ((0, .299, -1.096), .002, .003),
    ], sides=8, uv_span=(.32, .80))
    return model


def beetle_leg(side, foreclaw=False):
    suffix = "left" if side < 0 else "right"
    part = "claw" if foreclaw else "leg"
    model = Model(f"beetle_{part}_{suffix}", 2.1)
    if foreclaw:
        arm = [(0, .014, 0), (.146, -.120, -.045), (.264, -.114, -.117),
               (.387, .047, -.202), (.462, .174, -.263)]
        edge = [(.466, .436, -.429), (.472, .295, -.337), (.492, .180, -.293),
                (.569, .070, -.426), (.649, -.137, -.531), (.721, -.394, -.630), (.747, -.558, -.681)]
    else:
        arm = [(0, .008, 0), (.155, -.109, .021), (.295, -.116, .061),
               (.414, .013, .098), (.536, .163, .139)]
        edge = [(.536, .451, -.026), (.552, .296, .080), (.568, .183, .144),
                (.657, .099, .126), (.744, -.102, .059), (.809, -.348, -.025), (.837, -.579, -.128)]

    def mirrored(point):
        return (side * point[0], point[1], point[2])

    thigh = list(zip(map(mirrored, arm), (.080, .101, .081, .060, .066),
                     (.091, .106, .088, .066, .073)))
    tibia = list(zip(map(mirrored, edge), (.002, .044, .105, .116, .092, .051, .002),
                     (.003, .039, .083, .104, .076, .036, .003)))
    cuticle_loft(model, thigh, up=(0, 0, 1), uv_span=(.25, .71))
    cuticle_loft(model, tibia, up=(0, 0, 1), uv_span=(.12, .92), lip=True, ridged=True)
    for index, root in enumerate(edge[3:6]):
        scale = 1.0 - .18 * index
        offset = mul((.038, -.023, .075), scale)
        cuticle_loft(model, [
            (mirrored(sub(root, (.020, -.052, 0))), .051 * scale, .044 * scale),
            (mirrored(add(root, offset)), .049 * scale, .036 * scale),
            (mirrored(add(root, mul(offset, 1.63))), .002, .003),
        ], sides=7, up=(0, 0, 1), uv_span=(.31 + index * .12, .54 + index * .12), ridged=True)
    return model


def beetle_tail(upper=False):
    model = Model("beetle_sting" if upper else "beetle_tail", 2.2)
    if upper:
        path = [(0, -.043, -.006), (0, .162, .005), (-.012, .353, -.066),
                (-.023, .520, -.201), (-.039, .633, -.380), (-.048, .669, -.568),
                (-.051, .653, -.752), (-.052, .584, -.935)]
        widths = [.148, .139, .132, .120, .111, .101, .093, .080]
    else:
        path = [(0, -.020, -.042), (0, .015, .151), (0, .114, .306),
                (0, .282, .438), (0, .480, .510)]
        widths = [.198, .191, .176, .160, .144]
    spine = [(center, radius * .75, radius * .71) for center, radius in zip(path, widths)]
    cuticle_loft(model, spine, up=(1, 0, 0), sides=8, uv_span=(.53, .85))
    for index, (base, tip) in enumerate(zip(path, path[1:])):
        width = widths[index]
        along = norm(sub(tip, base))
        outside = norm(cross((1, 0, 0), along))
        mid = mix(base, tip, .48)
        cuticle_loft(model, [
            (mix(base, tip, -.08), width * .80, width * .79),
            (mix(base, tip, .27), width * .96, width * 1.00),
            (mix(base, tip, .73), width * .85, width * .89),
            (mix(base, tip, 1.05), width * .68, width * .73),
        ], up=(1, 0, 0), sides=10, uv_span=(.20 + index * .085, .34 + index * .085), lip=True)
        for side in (-1, 1):
            flank = add(mid, (side * width * .47, 0, 0))
            cuticle_loft(model, [
                (add(flank, mul(along, width * .50)), width * .36, width * .23),
                (add(flank, mul(outside, width * .57)), width * .51, width * .45),
                (add(add(flank, mul(along, -width * .51)), mul(outside, width * .89)), width * .36, width * .36),
                (add(add(flank, mul(along, -width * 1.26)), mul(outside, width * 1.31)), .002, .003),
            ], up=outside, sides=8, uv_span=(.30 + index * .085, .54 + index * .085), lip=True, ridged=True)
    if upper:
        # Separate, long blades leave a gap at the end of the arch.
        for side in (-1, 1):
            reach = .066 if side < 0 else 0
            cuticle_loft(model, [
                ((side * .044 - .050, .611, -.856), .056, .059),
                ((side * .099 - .051, .556, -.976), .055, .054),
                ((side * .128 - .056, .489, -1.097), .091, .076),
                ((side * .152 - .060, .402, -1.255), .081, .065),
                ((side * .164 - .065, .293, -1.418), .046, .039),
                ((side * .173 - .073, .182 - reach * .46, -1.572 - reach), .002, .003),
            ], sides=12, uv_span=(.31, .94), lip=True, ridged=True)
    return model


def flying_beetle():
    model = Model("flying_beetle", 2.1)
    cuticle_loft(model, [
        ((0, .594, -.906), .006, .006), ((0, .630, -.782), .130, .056),
        ((0, .667, -.576), .235, .129), ((0, .681, -.348), .287, .195),
        ((0, .681, -.094), .302, .229), ((0, .670, .192), .258, .206),
        ((0, .640, .415), .204, .157), ((0, .616, .597), .125, .088),
    ], sides=16, axis=(0, 0, 1), lip=True, ridged=True, uv_span=(.09, .92))
    model.ellipsoid("DuneSinew", (0, .535, -.043), (.239, .158, .572), sides=14, rows=7)
    for side in (-1, 1):
        model.ellipsoid("DuneSinew", (side * .207, .709, -.079), (.111, .131, .167), sides=10, rows=6)
        cuticle_loft(model, [
            ((side * .169, .601, -.700), .005, .004),
            ((side * .218, .615, -.621), .014, .017),
            ((side * .253, .627, -.548), .016, .017),
            ((side * .252, .641, -.493), .003, .004),
        ], sides=8, finish="DuneEyeLamp")
        for i in range(2):
            inset = i * .067
            cuticle_loft(model, [
                ((side * (.202 - inset), .559, -.583), .047, .048),
                ((side * (.230 - inset), .505, -.704), .051, .041),
                ((side * (.189 - inset), .424, -.825), .039, .031),
                ((side * (.132 - inset), .281 + .08 * i, -.950), .002, .004),
            ], sides=8, lip=True, ridged=True, uv_span=(.24, .74))
        for index, z in enumerate((-.32, -.01, .265)):
            cuticle_loft(model, [
                ((side * .15, .54, z), .043, .044),
                ((side * .259, .393, z + .079), .055, .044),
                ((side * .372, .327, z + .025), .046, .042),
                ((side * .344, .219, z - .112), .024, .026),
                ((side * (.259 - .029 * index), .075 + .025 * index, z - .230), .002, .003),
            ], sides=8, lip=True, ridged=True, uv_span=(.24 + .07 * index, .74 + .06 * index))
        for index in range(3):
            z = .03 + index * .181
            cuticle_loft(model, [
                ((side * .169, .724 - .019 * index, z - .129), .050, .051),
                ((side * .240, .719 - .027 * index, z), .073, .073),
                ((side * .229, .690 - .030 * index, z + .106), .042, .048),
                ((side * .181, .634 - .019 * index, z + .231), .002, .003),
            ], sides=8, lip=True, ridged=True, uv_span=(.43, .85))
    return model


def flying_beetle_tail():
    model = Model("flying_beetle_tail", 2.2)
    path = [(0, .01, -.057), (0, -.046, .144), (0, -.171, .302), (.015, -.359, .386),
            (.026, -.563, .390), (.037, -.758, .326), (.045, -.921, .193), (.051, -1.019, .025)]
    widths = [.140, .144, .136, .119, .106, .088, .067, .043]
    spine = [(point, radius * .64, radius * .62) for point, radius in zip(path, widths)]
    cuticle_loft(model, spine, up=(1, 0, 0), sides=8, uv_span=(.51, .81), finish="DuneSinew")
    for index, (base, tip) in enumerate(zip(path, path[1:])):
        radius = widths[index]
        outside = norm(cross(sub(tip, base), (1, 0, 0)))
        cuticle_loft(model, [
            (mix(base, tip, -.09), radius * .81, radius * .77),
            (mix(base, tip, .23), radius, radius * .97),
            (mix(base, tip, .79), radius * .91, radius * .85),
            (add(mix(base, tip, 1.21), mul(outside, radius * .22)), radius * .50, radius * .48),
            (add(mix(base, tip, 1.43), mul(outside, radius * .47)), .003, .004),
        ], up=outside, sides=10, lip=True, ridged=True, uv_span=(.17 + .09 * index, .36 + .09 * index))
    cuticle_loft(model, [
        ((.047, -.982, .089), .040, .036), ((.052, -1.043, -.029), .069, .058),
        ((.056, -1.105, -.168), .055, .047), ((.055, -1.146, -.298), .036, .029),
        ((.053, -1.184, -.487), .002, .003),
    ], sides=10, lip=True, ridged=True, uv_span=(.32, .93))
    return model


def flying_beetle_wing():
    model = Model("flying_beetle_wing", 2.4)
    sections = [
        (.000, .008, .081, .000), (.235, -.081, .311, .068), (.536, -.186, .588, .113),
        (.864, -.245, .793, .142), (1.208, -.239, .895, .167), (1.545, -.174, .910, .203),
        (1.842, -.066, .856, .243), (2.093, .092, .748, .290), (2.291, .281, .648, .348),
        (2.436, .496, .579, .420), (2.483, .555, .556, .449),
    ]

    def point(index, chord):
        x, front, back, height = sections[index]
        width = back - front
        return (x, height + width * (.075 * sin(pi * chord) - .39 * chord), front + width * chord)

    columns = 8
    for index in range(len(sections) - 1):
        for column in range(columns):
            coordinates = [(index, column), (index + 1, column), (index + 1, column + 1), (index, column + 1)]
            points = [point(row, chord / columns) for row, chord in coordinates]
            uv = [(sections[row][0] / sections[-1][0], chord / columns) for row, chord in coordinates]
            model.face("DuneWing", points, (0, 1, 0), uv=uv)
    for fraction, end, bend, start_width in ((.0, 10, .0, .026), (.28, 10, .075, .016),
                                             (.53, 9, -.080, .015), (.75, 8, -.058, .013), (.99, 6, -.04, .011)):
        for index in range(end):
            u, v = index / end, (index + 1) / end
            a = point(index, fraction + bend * sin(pi * u))
            b = point(index + 1, fraction + bend * sin(pi * v))
            model.tube("DuneChitin", a, b, start_width * (1 - u) + .0035 * u, start_width * (1 - v) + .0025 * v, sides=6)
    for start, end, section in ((.56, .97, 3), (.50, .96, 5), (.29, .72, 5), (.30, .61, 7), (.06, .32, 6)):
        a = point(section, start)
        b = point(section + 1, (start + end) * .5)
        c = point(section + 2, end)
        model.tube("DuneChitin", a, b, .0055, .0041, sides=5)
        model.tube("DuneChitin", b, c, .0041, .0028, sides=5)
    return model


def canyon_formation(family):
    name = ("canyon_ridge", "canyon_spur", "canyon_cut")[family]
    m = Model(name, .24)
    rng = Random(4171 + family * 271)
    count = 32
    perimeter = []
    for index in range(count):
        angle = index * 2 * pi / count
        rib = 1.0 + .12 * sin(angle * 5 + family) + .076 * sin(angle * 11 - family * 2)
        x = cos(angle) * rib
        z = sin(angle) * (rib + .07 * cos(angle * 9))
        perimeter.append((x, z, rng.uniform(-.12, .12)))

    bands = (
        (-.025, 1.11), (.066, 1.03), (.15, .97), (.22, .87), (.25, .81),
        (.294, .92), (.359, .90), (.414, .78), (.437, .73), (.493, .80),
        (.562, .76), (.61, .64), (.632, .60), (.665, .68), (.736, .63),
        (.781, .56), (.80, .52), (.845, .53), (.911, .48), (.96, .41),
        (1.0, .36),
    )
    top = (10.0, 12.7, 8.75)[family]
    width = (7.0, 6.6, 7.1)[family]
    depth = (3.63, 3.28, 3.84)[family]
    rows = []
    for index, (height, size) in enumerate(bands):
        ring = []
        for spoke, (x, z, notch) in enumerate(perimeter):
            angle = spoke * 2 * pi / count
            tilt = (.14 * x + .07 * z if family == 0 else (-.20 * x + .06 * z if family == 1 else .11 * cos(angle * 2.0)))
            erosion = sin(angle * 5 + family * 3) * .43 + sin(angle * 13 + 1.5) * .31
            # Beds dip across the ridge and break into narrower vertical gullies near the crown.
            y = top * (height + tilt * max(0, height) ** 1.53) + (erosion + notch) * min(1.0, max(0, height * 9))
            y += rng.uniform(-.09, .09) if index > 0 else -.21
            if index > 0:
                y = max(y, rows[-1][spoke][1] + .053)
            shift = (-.8 if family == 1 else .65) * height + sin(height * 9 + family) * height * .78
            xx = x * width * size + shift + notch * .92
            zz = z * (depth * size) + cos(height * 8 + family) * .69 * height
            zz += .18 * sin(angle * 17 + index * .81) * min(1.0, max(0, height * 12))
            ring.append((xx, y, zz))
        rows.append(ring)
    circumference = [0.0]
    for index in range(count):
        a, b = rows[0][index], rows[0][(index + 1) % count]
        circumference.append(circumference[-1] + sqrt((a[0] - b[0]) ** 2 + (a[2] - b[2]) ** 2))
    for band, (base, roof) in enumerate(zip(rows, rows[1:])):
        for index in range(count):
            following = (index + 1) % count
            a, b, c, d = base[index], base[following], roof[following], roof[index]
            finish = "CanyonShade" if band in (4, 8, 12, 15) and rng.random() < .65 else "CanyonLedge"
            ua, ub = circumference[index] * .23, circumference[index + 1] * .23
            m.face(finish, [a, c, b], cross(sub(c, a), sub(b, a)),
                   uv=[(ua, -a[1] * .29), (ub, -c[1] * .29), (ub, -b[1] * .29)])
            m.face(finish, [a, d, c], cross(sub(d, a), sub(c, a)),
                   uv=[(ua, -a[1] * .29), (ua, -d[1] * .29), (ub, -c[1] * .29)])
    crown = rows[-1]
    crest = add(mean(crown), (.16, .58 if family == 1 else .35, -.22))
    for index in range(count):
        a, b = crown[index], crown[(index + 1) % count]
        m.face("CanyonLedge", [a, crest, b], cross(sub(crest, a), sub(b, a)))
    return m


def approach_bastion():
    m = Model("canyon_bastion", .47)
    m.profile("BunkerConcrete", [(.02, -.15), (8.46, -1.12), (8.69, -1.32),
                                  (8.20, -4.14), (.02, -4.69)], 5.21, .146)
    m.profile("BunkerArmor", [(.12, .02), (2.32, .12), (7.32, -.39),
                               (8.06, -.57), (8.28, -.91), (.10, -1.32)], 4.10, .097)
    m.block("BunkerRim", (0, 8.43, -2.15), (5.32, .35, 4.14), .115, axis=1)
    m.block("BunkerArmor", (0, 8.71, -2.05), (4.72, .33, 3.34), .083, axis=1)
    for x in (-1.78, 1.78):
        m.profile("BunkerRim", [(.21, .35), (1.04, .35), (7.75, -.36),
                                 (8.16, -.81), (7.41, -1.11), (.49, -.61)],
                  .52, .078, center=(x, 0, 0))
        m.block("Black", (x * .83, 3.21, .027), (.427, 3.44, .10), .028, axis=2)
        for y in (2.00, 3.11, 4.22, 5.32):
            m.block("BunkerArmor", (x * .83, y, .094), (.36, .29, .094), .039, axis=2)
    m.block("Black", (0, 7.53, -.259), (2.83, .386, .156), .023, axis=2)
    for x in (-.96, -.48, 0, .48, .96):
        m.block("AmberLamp", (x, 7.54, -.169), (.346, .033, .049), .006)
    for x in (-1.48, 1.58):
        m.tube("Graphite", (x, 8.74, -2.26), (x, 9.21, -2.26), .085, .061, sides=8)
    return m


def command_superstructure(model):
    m = model
    m.profile("BunkerConcrete", [(3.87, -1.95), (6.25, -1.75), (7.27, -1.07),
                                  (6.26, 1.77), (4.12, 1.97)], 3.29, .126)
    m.profile("BunkerRim", [(6.10, -1.71), (7.26, -1.94), (7.94, -1.63),
                             (7.93, 1.52), (7.49, 1.91), (6.86, 1.67)], 4.85, .15)
    m.profile("BunkerArmor", [(7.36, -1.57), (7.98, -1.72), (8.18, -1.45),
                               (8.18, 1.30), (7.92, 1.61), (7.39, 1.42)], 4.32, .085)
    m.block("Black", (0, 7.73, 1.66), (3.68, .49, .113), .026, axis=2)
    for x in (-1.47, -.735, 0.0, .735, 1.47):
        m.block("BunkerRim", (x, 7.74, 1.726), (.029, .476, .031), .006)
        m.block("AmberLamp", (x - .26, 7.73, 1.736), (.292, .039, .013), .004)
    for side in (-1, 1):
        m.profile("BunkerArmor", [(4.04, 1.43), (6.87, 1.30), (7.19, .97),
                                   (6.69, .52), (4.36, .73)], .372, .059,
                  center=(side * 1.66, 0, 0))
        m.block("BunkerArmor", (side * 2.19, 7.64, -.27), (.134, .38, 2.74), .025)
    m.block("BunkerArmor", (0, 8.17, -.02), (4.12, .198, 3.13), .071, axis=1)
    m.block("BunkerRim", (-.62, 8.51, -.39), (2.02, .54, 1.73), .089, axis=1)
    m.tube("BunkerArmor", (.58, 8.25, -.47), (.58, 9.02, -.47), .64, .59, sides=16)
    m.tube("BunkerRim", (.58, 8.99, -.47), (.58, 9.07, -.47), .593, .521, sides=16)
    for x, height in ((-1.25, 11.3), (-.79, 10.14), (1.53, 9.87)):
        m.tube("BunkerRim", (x, 8.72, -.68), (x, height, -.68), .066, .022, sides=8)
        m.ellipsoid("IceLamp", (x, height, -.68), (.037, .047, .037), sides=8, rows=4)
    for y in (9.51, 10.35):
        m.tube("BunkerRim", (-1.50, y, -.68), (-.91, y, -.68), .019, .016, sides=6)


def wall():
    m = Model("wall_segment", .48)
    m.profile("BunkerConcrete", [(.065, -3.31), (2.77, -3.31), (3.056, -3.26), (3.164, .376),
                           (2.8, .389), (.062, .389)], 3.94, .078, axis=0)
    m.block("BunkerArmor", (0, 3.057, -1.459), (3.99, .244, 3.704), .040, axis=1)
    for z in (-2.998, -2.302, -1.606, -.91, -.214):
        m.block("Graphite", (0, 3.178, z), (3.82, .004, .029), .0008, axis=1)
    for x in (-1.56, 1.56):
        m.block("Graphite", (x, 3.177, -2.985), (.317, .008, .175), .0015, axis=1)
        for offset in (-.105, -.04, .04, .105):
            m.block("Steel", (x + offset, 3.184, -2.985), (.026, .008, .150), .0015, axis=1)
    m.profile("BunkerConcrete", [(.07, -.339), (.16, -.385), (2.24, -.385), (2.68, -.309),
                            (3.06, -.282), (3.12, .242), (2.71, .362), (.086, .367)],
              3.94, .059, axis=0)
    m.block("Graphite", (0, .145, 0), (3.955, .269, .938), .049, axis=1)
    m.block("BunkerArmor", (0, 3.064, 0), (3.956, .185, .869), .045, axis=1)
    for side in (-1, 1):
        z = side * .386 if side > 0 else -3.315
        for x in (-1.20, 0, 1.20):
            m.block("BunkerConcrete", (x, 1.421, z), (1.101, 2.21, .202), .075, axis=2)
            m.block("Black", (x, 2.486, z + side * .079), (.897, .149, .064), .028, axis=2)
            m.block("BunkerArmor", (x, 2.507, z + side * .120), (.798, .063, .026), .013, axis=2)
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
    for x in (-1.77, 1.77):
        # Only the flanking ribs project past the panels used for visible wall damage.
        m.profile("BunkerArmor", [(.030, .540), (.281, .790), (1.169, .732),
                                   (2.672, .483), (2.937, .438), (.13, .375)],
                  .355, .043, center=(x, 0, 0))
        m.profile("BunkerRim", [(.304, .750), (.547, .753), (2.437, .563),
                                 (2.698, .501), (2.426, .456), (.373, .660)],
                  .153, .019, center=(x, 0, 0))
    m.block("BunkerRim", (0, 2.907, .514), (3.72, .104, .117), .018, axis=2)
    return m


def blocker():
    m = Model("gate_frame", .6)
    m.block("Graphite", (0, .027, 0), (3.98, .052, 1.145), .014, axis=1)
    m.block("BunkerArmor", (0, 3.331, 0), (3.991, .42, 1.013), .084, axis=1)
    m.block("Black", (0, 3.423, .519), (2.053, .237, .036), .018, axis=2)
    m.block("Black", (0, 3.423, -.519), (2.053, .237, .036), .018, axis=2)
    for sign in (-1, 1):
        x = sign * 1.87
        m.block("Graphite", (x, 1.677, 0), (.238, 3.295, 1.054), .037)
        m.block("BunkerArmor", (x, .516, 0), (.244, .94, 1.078), .033)
        m.block("Steel", (x, 2.806, 0), (.247, .188, 1.094), .024)
        for k in (-1, 1):
            m.block("Hazard", (x, 1.77, k * .541), (.202, .404, .036), .014, axis=2)
            rivet(m, (x, .351, k * .562), (0, 0, k), .045)
    for side in (-1, 1):
        m.profile("BunkerRim", [(.131, .272), (.361, .601), (2.938, .445),
                                 (3.310, .388), (3.144, .222), (.225, .191)],
                  .212, .046, center=(side * 1.90, 0, 0))
    m.block("BunkerRim", (0, 3.49, .322), (3.63, .295, .365), .037, axis=2)
    return m


def gate_panels():
    m = Model("gate_panels", .68)
    for wing in (-1, 1):
        x = wing * .872
        m.block("Graphite", (x, 1.602, 0), (1.714, 3.121, .647), .086, axis=2)
        for depth in (-1, 1):
            side = depth * .350
            m.profile("BunkerArmor", [(x - .716, .324), (x + .71, .324), (x + .73, 2.537),
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
    m.profile("BunkerConcrete", [(-2.585, -2.213), (2.58, -2.214), (2.59, 1.83),
                            (2.211, 2.223), (-2.231, 2.22), (-2.59, 1.864)],
              3.86, .114, axis=1, center=(0, 1.971, 0))
    m.block("Graphite", (0, .245, 0), (5.287, .326, 4.533), .083, axis=1)
    m.block("BunkerArmor", (0, 3.848, 0), (5.563, .325, 4.716), .128, axis=1)
    m.block("Black", (0, 1.423, 2.237), (2.122, 2.36, .175), .092, axis=2)
    for x in (-.467, .467):
        m.profile("Graphite", [(x - .405, .289), (x + .401, .289), (x + .417, 2.096),
                                (x + .258, 2.385), (x - .268, 2.396), (x - .418, 2.092)],
                  .159, .056, axis=2, center=(0, 0, 2.343))
        m.block("BunkerArmor", (x, 1.41, 2.438), (.601, 1.387, .066), .079, axis=2)
        m.block("Hazard", (x, .647, 2.491), (.63, .157, .045), .026, axis=2)
    m.block("Black", (0, 2.825, 2.269), (2.158, .336, .094), .046, axis=2)
    for side in (-1, 1):
        x = side * 1.801
        for edge in (-1, 1):
            m.block("Graphite", (x, 1.733, edge * 2.249), (1.07, 2.768, .18), .097, axis=2)
            m.block("BunkerArmor", (x, 2.009, edge * 2.354), (.858, 1.374, .065), .056, axis=2)
            for n in range(6):
                m.block("Black", (x, 1.534 + n * .175, edge * 2.400), (.674, .073, .035), .013, axis=2)
        m.block("IceLamp", (x, 3.007, 2.339), (.69, .050, .034), .011, axis=2)
        m.block("Graphite", (side * 2.568, 1.9, -.1), (.197, 2.517, 2.773), .056)
        for z in (-1.183, .871):
            m.tube("BunkerArmor", (side * 2.674, .352, z), (side * 2.674, 3.637, z), .066, .053, 10)
            for y in (.52, 1.3, 2.9, 3.47):
                m.tube("Steel", (side * 2.674, y, z), (side * 2.674, y + .078, z), .087, .081, 10)
    m.block("Graphite", (.837, 4.13, -.702), (1.08, .318, 1.375), .08, axis=1)
    for n in range(5):
        m.block("Steel", (.45 + n * .18, 4.326, -.701), (.066, .08, .99), .019)
    command_superstructure(m)
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
    models = (rifle(), rifle_magazine(), rifle_hand(True), rifle_hand(False), repair_tool(), turret_base(), turret_head(), turret_emitters(), turret_cartridge(), turret_wreck(),
              beetle(), beetle_leg(-1), beetle_leg(1), beetle_leg(-1, foreclaw=True), beetle_leg(1, foreclaw=True),
              beetle_tail(), beetle_tail(upper=True), flying_beetle(), flying_beetle_tail(), flying_beetle_wing(),
              wall(), blocker(), gate_panels(), relay(), station(),
              supply_rack(), drone(), breach(), scrub(), approach_bastion(), *(canyon_formation(i) for i in range(3)), *(boulder(i) for i in range(1, 4)))
    for model in models:
        model.write()


if __name__ == "__main__":
    main()
