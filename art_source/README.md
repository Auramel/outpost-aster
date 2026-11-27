# Графика «Форпоста Астер»

В игре используются оригинальные модели glTF из `assets/art/models` и материалы из `assets/art/materials`. Геометрия оружия, базы, турелей и жуков собрана специально для проекта. Импортированные меши используются как визуальные узлы над существующей физикой, а модель каждой турели разделена на основание, поворотный блок и наклоняемое оружие. В Godot включены упрощённые уровни детализации мешей. Для фактур используются карты нормалей, мип-уровни и VRAM-сжатие.

Карабин собран из корпуса со сквозной верхней рукоятью, магазина и поддерживающей руки. Турель разделена на основание, поворотный кожух и подвижную пару стволов. У жука опорные лапы и хватательные конечности используют отдельные меши и движения. Карабин, турели и постройки используют общие карты потёртой стали и оливкового покрытия. На панцире жуков применяется фактура песка из окружения.

`python3 art_source/build_models.py` повторно собирает модели. Скрипт `art_source/bake_textures.gd` разделяет исходный атлас на четыре материала, подготавливает края для повторения, строит карты нормалей и приводит панораму к формату 2:1. Для повторного запекания передайте ему два исходных PNG:

```sh
.tools/Godot.app/Contents/MacOS/Godot --headless --path . \
  --script res://art_source/bake_textures.gd -- /путь/к/атласу.png /путь/к/панораме.png
```

## Промпты для встроенного ImageGen

### Атлас материалов

> Use case: photorealistic-natural\
> Asset type: a square base-color material atlas for an original real-time science-fiction desert outpost video game.\
> Make a precise 2-by-2 grid with four evenly sized square texture swatches that meet at the exact image center. Top left: warm grey-brown packed desert dust, small irregular scattered gravel, fine wind erosion, no large rocks. Top right: dark mauve-grey and muted ochre eroded sedimentary canyon wall, visible thin nearly horizontal strata, fractured real stone at a close enough scale to read. Bottom left: medium cool grey industrial cast concrete, subtle formwork pores and concrete runoff stains, mostly even in value. Bottom right: neutral grey worn machined metal with a fine even blasted texture, sparse subtle scratches and smudges, no pattern of manufactured parts.\
> All are realistic orthographic surface scans for tile sampling, with unlit-looking flat diffuse color and microdetail, each material fills its quadrant edge to edge. Preserve low contrast without losing surface detail. The image has no perspective, objects, shadows, specular highlights, logos, labels, writing, borders or padding. The quadrant split is a straight horizontal and straight vertical line; keep each material contained in its exact quadrant.

### Панорама неба

> Use case: photorealistic-natural\
> Asset type: an equirectangular 2:1 panorama sky texture for an original first-person sci-fi desert outpost game, full 360 degree longitude, realistic clouds with a dusty atmosphere. The sky is the entire image. Top represents the zenith in subdued dark steel blue; horizon should be a faint continuous hazy pale peach-grey band precisely around the vertical midpoint; the bottom hemisphere is a flat softly shaded warm slate haze with no visible ground objects. Upper half has elongated irregular stratocumulus fingers and delicate wisps, with softer brighter backlit edges on part of the horizon; cool navy upper shadows and subtle amber support, dry cinematic light at late afternoon. Keep the left and right edges close in color and brightness to minimize the wrap seam. Natural realistic sky, no discernible sun disk, no ground, rocks, mountains, buildings, stars, objects, text, borders or watermarks.


### Атлас каньона и базы

Сгенерирован встроенным ImageGen. Подготовленные карты лежат в `assets/art/materials` под именами `field_*.jpg` и `field_*_normal.png`. Для повторного запекания передайте скрипту `bake_textures.gd` аргументы `--field-atlas /путь/к/атласу.png`.

> Use case: photorealistic-natural. Asset type: pure square PBR base-color texture atlas for an original first-person science-fiction desert defense video game. Compose exactly four square texture tiles filling their quadrants, splitting straight in the center, no borders or grid lines. Top left: an orthographic surface sample of packed warm pale sandstone sand, fine ripple striations, abrasion streaks, irregular subtle gravel, matte sun-bleached ochre and cream, no dunes or objects, low contrast. Top right: an orthographic close flat view of sedimentary cliff, distinctly horizontal thin fractured tan sandstone ledges and dark brown compressed seams, natural sharp abrasion, subtly muted honey beige. Bottom left: orthographic porous medium gray military precast concrete, warm gray aggregate, dusty pores and restrained vertical mineral run-off, slight fine grime, no panel seams. Bottom right: orthographic dark gray worn manganese steel, restrained fine brushed texture, abrasion, sparse irregular medium silver scratches, orange mineral dust in pores, uniform medium-dark gray, no panels no bolts. Photoreal actual material, flat diffuse albedo, no lighting gradients, ambient occlusion only in finest crevices, full-bleed physically-based textures. No labels, text, composition elements, perspective, strong shadows, background, object props, or large features. Tiles intended for PBR repeat sampling in game.

### Дневная панорама

Встроенный ImageGen, файл в проекте `assets/art/materials/day_panorama.jpg`. Чтобы запечь 2:1-панораму повторно, передайте скрипту `bake_textures.gd` один аргумент с исходным PNG.

> Use case: photorealistic-natural. Asset type: original 2:1 equirectangular panorama sky texture for a modern-looking first-person sci-fi game in a dry desert canyon. Render ONLY the sky and aerial haze, without terrain or objects, as a full 360-degree long-latitude panorama. Bright dusty afternoon, clear muted cerulean-blue zenith, several long irregular very soft white cloud streaks and thin high wisps, progressively pale blue and warm ivory dust haze towards the thin horizontal horizon at vertical midpoint. Below the midpoint is warm flat sandy aerial haze. No sun disk, no burning objects, no mountains, buildings, characters, typography or borders. Left and right edges should match for a subtle wrap seam. Use realistic outdoor color, neutral white balanced cinematic day, bright enough for a desert battle, natural soft lighting.


### Сталь, краска, полимер и бетон

Атлас создан встроенным ImageGen. Запекание через `bake_textures.gd -- --workshop-atlas /путь/к/атласу.png` создаёт цветовые карты, нормали и шероховатость для материалов `parkerized`, `painted`, `polymer` и `armory`. Карты сохраняются в `assets/art/materials`.

> Use case: photorealistic-natural. Asset type: production albedo texture atlas for an original grounded post-apocalyptic science fiction first-person game, used at arm's length. Perfect 2x2 grid with edges meeting at the exact center. Each tile is a continuous 100 percent full-bleed flat orthographic material surface photographed with even cross-polarized light. Top-left: charcoal blue-black parkerized bare steel typical of decades-old industrial machinery, fine gray metal grain, many very fine directionally consistent marks, short silver abrasion gouges, clusters of handling wear and subtle brown oxidation around scratches. Top-right: worn, subdued green-grey painted metal. Mostly intact matte olive-drab coating with small irregular metallic chips that reveal faint cold gray substrate, powdery ochre dirt in scuffs, moderate wear coverage 15 to 25 percent, no panel edges. Bottom-left: dark gray textured engineering polymer with dense tactile stipple, short rub marks, patchy desaturated hand grime, tiny dust trapped in the texture, no repeating stamped shape. Bottom-right: ageing light-to-medium olive-gray concrete armory wall with visible pores, sooty muted damp streaks and patches of embedded sand, very restrained rusty bleed, no wall geometry or seams. Worn, analog, hand-used realism, neutral dark values, physically plausible colors for repeatable PBR textures. Fine and medium scale texture with no camera perspective. No lighting falloff, objects, borders, weapons, assembled props, lettering, layout marks, cast shadows, logo, tiles within a quadrant, or background.

### Янтарная панорама

Создана встроенным ImageGen. `bake_textures.gd -- --amber-panorama /путь/к/панораме.png` сохраняет `assets/art/materials/amber_panorama.jpg`.

> Use case: photorealistic-natural. Asset type: exact 2:1 equirectangular 360-degree panorama sky texture for an original first-person desert sci-fi defense game, full longitude. Paint only a massive, photographic atmosphere hanging over a sandstone canyon. A sun above frame strongly diffused by fine mineral dust. Late day but fully bright enough for outdoor combat: a warm ochre, burnished tawny amber, understated clay-peach sky, with elongated pale silky thin cirrus streaks faintly fanning across the sky, NO storm wall. Higher sky softly dusky warm tan, horizon near exact horizontal midpoint glows diffuse dusty pale cream-gold, low contrast. Below the midpoint pure atmosphere only, a soft monotone amber-gray fade into the nadir. Sweeping, coherent atmosphere, quality of a realistic light-field reference panorama, physical dust scattering. No visible sun disk, mountains, ground, trees, structures, artificial highlights, typography, watermark or pasted objects. Seamless match between left and right extreme edges. Avoid blue sky or magenta sunset. Landscape 2:1.
