"""Pasca-build web: beri nama font ikon sebuah hash isi filenya.

Flutter selalu menamai font ikon `MaterialIcons-Regular.otf`, padahal isinya
berbeda di tiap build (hanya berisi ikon yang dipakai). Browser yang masih
menyimpan versi lama akan kehilangan ikon baru. Dengan nama ber-hash, browser
pasti mengambil font yang sesuai dengan build-nya.

Pakai:  python tool/postbuild_web.py   (setelah `flutter build web`)
"""
import hashlib
import os
import re
import sys

ROOT = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), 'build', 'web')
FONT = os.path.join(ROOT, 'assets', 'fonts', 'MaterialIcons-Regular.otf')
MANIFEST = os.path.join(ROOT, 'assets', 'FontManifest.json')
SW = os.path.join(ROOT, 'flutter_service_worker.js')


def md5(data):
    return hashlib.md5(data).hexdigest()


if not os.path.exists(FONT):
    print('Font sudah ber-hash atau build belum dijalankan, dilewati.')
    sys.exit(0)

font_bytes = open(FONT, 'rb').read()
short = hashlib.sha1(font_bytes).hexdigest()[:10]
new_rel = f'fonts/MaterialIcons-Regular.{short}.otf'
new_path = os.path.join(ROOT, 'assets', new_rel.replace('/', os.sep))
os.replace(FONT, new_path)

# FontManifest.json
m = open(MANIFEST, encoding='utf-8').read()
assert 'fonts/MaterialIcons-Regular.otf' in m
m = m.replace('fonts/MaterialIcons-Regular.otf', new_rel)
open(MANIFEST, 'w', encoding='utf-8', newline='').write(m)

# Service worker: ganti kunci font dan perbarui md5 FontManifest.json
sw = open(SW, encoding='utf-8').read()
old_key = '"assets/fonts/MaterialIcons-Regular.otf"'
assert old_key in sw
sw = sw.replace(old_key, f'"assets/{new_rel}"')
sw = re.sub(r'("assets/FontManifest\.json": ")[0-9a-f]{32}(")',
            lambda mo: mo.group(1) + md5(m.encode('utf-8')) + mo.group(2), sw)
open(SW, 'w', encoding='utf-8', newline='').write(sw)

print(f'Font ikon diganti nama menjadi assets/{new_rel}')
