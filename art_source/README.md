# Графика «Форпоста Астер»

Меши наземного жука и летуна запекаются из `build_models.py`. Команда `python3 art_source/bake_chitin.py` запекает карты цвета и нормалей хитина и полупрозрачную текстуру крыльев.

Команда `python3 art_source/build_special_beetles.py` запекает меши шести спецжуков и карты шероховатости и затенения их хитина. Концепты спецжуков лежат в `references/special_beetles`.

В игре используются оригинальные модели glTF из `assets/art/models` и материалы из `assets/art/materials`. Геометрия оружия, базы, турелей и жуков собрана специально для проекта. Импортированные меши используются как визуальные узлы над существующей физикой, а модель каждой турели разделена на основание, поворотный блок и наклоняемое оружие. В Godot включены упрощённые уровни детализации мешей. Для фактур используются карты нормалей, мип-уровни и VRAM-сжатие.

Карабин собран из корпуса со сквозным прикладом и открытым прицелом, съёмного магазина и двух отдельных рук. Верхняя и нижняя части цевья разнесены и оставляют видимым кожух ствола. Для корпуса используются карты сатинированной стали и полимера, для меток и прицела применяется холодное свечение. У турели отдельные меши для кольцевой опоры, поворотной брони с сенсорами, двухствольной каретки, сменной кассеты и обломков. Корпус покрыт потёртой эмалью, а каретка откатывается при стрельбе. У жука отдельные меши для опорных лап, хватательных конечностей и двух частей хвоста.

`python3 art_source/build_models.py` повторно собирает базовые модели. Команда `python3 art_source/build_fortifications.py` запекает фасад, консольный выступ для Т-2, госпиталь, детали Т-5 «Дредноут», открытые ящики, слои патронов, повреждения Т-1 и гнёзда. Команда `python3 art_source/build_turret_family.py` пересобирает меши основания, поворотного блока и оружия для Т-2, Т-3 и Т-4. Скрипт `art_source/bake_textures.gd` запекает атласы материалов и дневную панораму. Для запекания текстур каньона передайте исходный атлас:

```sh
"/Applications/Godot.app/Contents/MacOS/Godot" --headless --path . \
  --script res://art_source/bake_textures.gd -- --canyon-atlas /путь/к/атласу.png
```

## Промпты для встроенного ImageGen

### Каньон и укрепления

Команда `--canyon-atlas` у `bake_textures.gd` запекает четыре бесшовные фактуры с картами цвета, нормалей и шероховатости. Файлы `canyon_*` сохраняются в `assets/art/materials`. Средние скальные гряды имеют коллизию на базе видимой формы. Для дальнего хребта используются те же три модели в пакетах без физики. Поверхность долины и высоты появления жуков берутся из одной сетки рельефа.

> Use case: photorealistic-natural. Asset type: square four-material albedo atlas for the original game Outpost Aster. Fill four exactly square full-bleed quadrants meeting at the exact image center, no separators. Top left: sun-bleached pale beige packed canyon grit, weathered sandy mineral ground, small embedded angular pebbles and subtle ripples, even light. Top right: close orthographic face of Mojave-style eroded sedimentary rock, ochre-tan and dust-gray layers with hairline horizontal seams and irregular narrow vertical runnels, tiny granular pores, low to medium contrast. Bottom left: mottled cool gray poured military concrete, dust-lightened aggregate with very faint vertical streaks, pores and restrained chips at the grain scale. Bottom right: weathered blue-gray painted structural steel, slight amber mineral dust in creases, subdued fine silvery abrasions, flaking dark paint in modest speckling. PBR diffuse samples viewed straight on under perfectly flat diffuse light, no objects, no panel or paving seams, no sky, no typography, no perspective, no borders, no baked cast shadows. Photographic detail with consistent scale and palette.

### Сплав для оборудования

Команда `--field-atlas /путь/к/атласу.png` берёт нижний правый квадрат атласа и запекает `field_alloy.jpg` и `field_alloy_normal.png`.

> Use case: photorealistic-natural. Asset type: pure square PBR base-color texture atlas for an original first-person science-fiction desert defense video game. Compose exactly four square texture tiles filling their quadrants, splitting straight in the center, no borders or grid lines. Top left: an orthographic surface sample of packed warm pale sandstone sand, fine ripple striations, abrasion streaks, irregular subtle gravel, matte sun-bleached ochre and cream, no dunes or objects, low contrast. Top right: an orthographic close flat view of sedimentary cliff, distinctly horizontal thin fractured tan sandstone ledges and dark brown compressed seams, natural sharp abrasion, subtly muted honey beige. Bottom left: orthographic porous medium gray military precast concrete, warm gray aggregate, dusty pores and restrained vertical mineral run-off, slight fine grime, no panel seams. Bottom right: orthographic dark gray worn manganese steel, restrained fine brushed texture, abrasion, sparse irregular medium silver scratches, orange mineral dust in pores, uniform medium-dark gray, no panels no bolts. Photoreal actual material, flat diffuse albedo, no lighting gradients, ambient occlusion only in finest crevices, full-bleed physically-based textures. No labels, text, composition elements, perspective, strong shadows, background, object props, or large features. Tiles intended for PBR repeat sampling in game.

### Дневная панорама

Встроенный ImageGen, файл в проекте `assets/art/materials/day_panorama.jpg`. Чтобы запечь 2:1-панораму повторно, передайте скрипту `bake_textures.gd` один аргумент с исходным PNG.

> Use case: photorealistic-natural. Asset type: original 2:1 equirectangular panorama sky texture for a modern-looking first-person sci-fi game in a dry desert canyon. Render ONLY the sky and aerial haze, without terrain or objects, as a full 360-degree long-latitude panorama. Bright dusty afternoon, clear muted cerulean-blue zenith, several long irregular very soft white cloud streaks and thin high wisps, progressively pale blue and warm ivory dust haze towards the thin horizontal horizon at vertical midpoint. Below the midpoint is warm flat sandy aerial haze. No sun disk, no burning objects, no mountains, buildings, characters, typography or borders. Left and right edges should match for a subtle wrap seam. Use realistic outdoor color, neutral white balanced cinematic day, bright enough for a desert battle, natural soft lighting.


### Сталь, краска, полимер и бетон

Атлас создан встроенным ImageGen. Запекание через `bake_textures.gd -- --workshop-atlas /путь/к/атласу.png` создаёт цветовые карты, нормали и шероховатость для материалов `parkerized`, `painted`, `polymer` и `armory`. Карты сохраняются в `assets/art/materials`.

> Use case: photorealistic-natural. Asset type: production albedo texture atlas for an original grounded post-apocalyptic science fiction first-person game, used at arm's length. Perfect 2x2 grid with edges meeting at the exact center. Each tile is a continuous 100 percent full-bleed flat orthographic material surface photographed with even cross-polarized light. Top-left: charcoal blue-black parkerized bare steel typical of decades-old industrial machinery, fine gray metal grain, many very fine directionally consistent marks, short silver abrasion gouges, clusters of handling wear and subtle brown oxidation around scratches. Top-right: worn, subdued green-grey painted metal. Mostly intact matte olive-drab coating with small irregular metallic chips that reveal faint cold gray substrate, powdery ochre dirt in scuffs, moderate wear coverage 15 to 25 percent, no panel edges. Bottom-left: dark gray textured engineering polymer with dense tactile stipple, short rub marks, patchy desaturated hand grime, tiny dust trapped in the texture, no repeating stamped shape. Bottom-right: ageing light-to-medium olive-gray concrete armory wall with visible pores, sooty muted damp streaks and patches of embedded sand, very restrained rusty bleed, no wall geometry or seams. Worn, analog, hand-used realism, neutral dark values, physically plausible colors for repeatable PBR textures. Fine and medium scale texture with no camera perspective. No lighting falloff, objects, borders, weapons, assembled props, lettering, layout marks, cast shadows, logo, tiles within a quadrant, or background.

## Фотограмметрия

Модель [Rock Face 02](https://polyhaven.com/a/rock_face_02) от Dario Barresi и Rico Cilliers взята из Poly Haven под [CC0](https://polyhaven.com/license). В `assets/art/models/rock_face_02.glb` упакованы исходный меш и карты цвета, нормалей, шероховатости и AO в разрешении 1K. Godot импортирует текстуры в Basis Universal и генерирует LOD.
