"""CarCare - توليد أيقونة إطلاق تكيّفية (Adaptive Icon) من صورة الشعار.

الاستخدام:  python3 docs/make_launcher_icons.py
المصدر:     assets/icon/app_icon.png  (مربع، خلفية داكنة، رسم في الوسط)
"""
from PIL import Image, ImageDraw
import os

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, 'assets', 'icon', 'app_icon.png')
RES = os.path.join(ROOT, 'android', 'app', 'src', 'main', 'res')
WEB = os.path.join(ROOT, 'web')

src = Image.open(SRC).convert('RGBA')
S = 1024
src = src.resize((S, S), Image.LANCZOS)
px = src.load()

# لون الخلفية: نأخذه من نقطة داخل البلاطة قرب الحافة (وليس الزاوية المدوّرة)
BG = px[S // 2, 30][:3]

def solid(size, color=BG):
    return Image.new('RGBA', (size, size), color + (255,))

# طبقة الرسم: كل ما يختلف عن لون الخلفية داخل المنطقة المركزية (نستبعد الزوايا)
art = Image.new('RGBA', (S, S), (0, 0, 0, 0))
ap = art.load()
margin = int(S * 0.08)
for y in range(margin, S - margin):
    for x in range(margin, S - margin):
        r, g, b, a = px[x, y]
        if a < 10:
            continue
        if abs(r - BG[0]) + abs(g - BG[1]) + abs(b - BG[2]) > 45:
            ap[x, y] = (r, g, b, 255)
bbox = art.getbbox()
art = art.crop(bbox)

def place(canvas, scale):
    t = int(canvas.width * scale)
    k = min(t / art.width, t / art.height)
    a = art.resize((max(1, int(art.width * k)), max(1, int(art.height * k))), Image.LANCZOS)
    canvas.paste(a, ((canvas.width - a.width) // 2, (canvas.height - a.height) // 2), a)
    return canvas

def masked(img, shape):
    m = Image.new('L', img.size, 0)
    d = ImageDraw.Draw(m)
    if shape == 'circle':
        d.ellipse((0, 0, img.width - 1, img.height - 1), fill=255)
    else:
        d.rounded_rectangle((0, 0, img.width - 1, img.height - 1), radius=int(img.width * 0.22), fill=255)
    out = Image.new('RGBA', img.size, (0, 0, 0, 0))
    out.paste(img, (0, 0), m)
    return out

DENSITIES = {'mdpi': 48, 'hdpi': 72, 'xhdpi': 96, 'xxhdpi': 144, 'xxxhdpi': 192}
for name, dp in DENSITIES.items():
    folder = os.path.join(RES, f'mipmap-{name}')
    os.makedirs(folder, exist_ok=True)
    masked(place(solid(dp), 0.72), 'rounded').save(os.path.join(folder, 'ic_launcher.png'))
    masked(place(solid(dp), 0.66), 'circle').save(os.path.join(folder, 'ic_launcher_round.png'))
    adaptive = dp * 108 // 48
    solid(adaptive).save(os.path.join(folder, 'ic_launcher_background.png'))
    fg = Image.new('RGBA', (adaptive, adaptive), (0, 0, 0, 0))
    place(fg, 0.50).save(os.path.join(folder, 'ic_launcher_foreground.png'))

xml_dir = os.path.join(RES, 'mipmap-anydpi-v26')
os.makedirs(xml_dir, exist_ok=True)
XML = '''<?xml version="1.0" encoding="utf-8"?>
<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">
    <background android:drawable="@mipmap/ic_launcher_background"/>
    <foreground android:drawable="@mipmap/ic_launcher_foreground"/>
</adaptive-icon>
'''
for f in ('ic_launcher.xml', 'ic_launcher_round.xml'):
    with open(os.path.join(xml_dir, f), 'w') as fh:
        fh.write(XML)

# الويب
icons = os.path.join(WEB, 'icons')
os.makedirs(icons, exist_ok=True)
masked(place(solid(192), 0.72), 'rounded').save(os.path.join(icons, 'Icon-192.png'))
masked(place(solid(512), 0.72), 'rounded').save(os.path.join(icons, 'Icon-512.png'))
place(solid(192), 0.6).save(os.path.join(icons, 'Icon-maskable-192.png'))
place(solid(512), 0.6).save(os.path.join(icons, 'Icon-maskable-512.png'))
masked(place(solid(64), 0.72), 'rounded').save(os.path.join(WEB, 'favicon.png'))

# معاينة: كيف يقصّ المشغّل الأيقونة التكيّفية (دائرة/مربع) + القديمة
prev_bg = place(solid(432), 0.50)
inner = prev_bg.crop((54, 54, 378, 378))
row = Image.new('RGBA', (324 * 3 + 40, 324), (235, 235, 235, 255))
row.paste(masked(inner, 'circle'), (0, 0), masked(inner, 'circle'))
row.paste(masked(inner, 'rounded'), (344, 0), masked(inner, 'rounded'))
leg = masked(place(solid(324), 0.72), 'rounded')
row.paste(leg, (688, 0), leg)
row.save('/tmp/carcare_icon_preview.png')
print('BG colour', BG, '- done')
