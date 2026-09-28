"""Build local-only bilingual policy previews; deliberately has no publish mode."""
from pathlib import Path
from html import escape
import hashlib
import json

ROOT = Path(__file__).resolve().parent
TITLES = {
    'en': {'privacy-policy': 'Privacy Policy', 'terms-of-use': 'Terms of Use', 'data-deletion': 'Account and Data Deletion'},
    'es': {'privacy-policy': 'Política de privacidad', 'terms-of-use': 'Condiciones de uso', 'data-deletion': 'Eliminación de cuenta y datos'},
}
CSS = '''*{box-sizing:border-box}body{margin:0;background:#f6f8fa;color:#172b3a;font:1.05rem/1.7 system-ui,sans-serif}header,main,footer{max-width:850px;margin:auto;padding:1.5rem}header{border-bottom:1px solid #c9d6df}nav{display:flex;flex-wrap:wrap;gap:1rem}a{color:#124e85;text-underline-offset:.2em}a:focus-visible{outline:3px solid #925500;outline-offset:4px}h1{font-size:clamp(2rem,6vw,3rem);line-height:1.15}h2{line-height:1.35;margin-top:2.3rem}li{margin:.75rem 0}.draft{background:#fff3cc;border:2px solid #856000;padding:1rem}.brand{font-weight:750;letter-spacing:.03em}.skip{position:absolute;left:-10000px}.skip:focus{left:1rem;top:1rem;background:white;padding:.6rem}footer{border-top:1px solid #c9d6df;font-size:.95rem}p,li,a{overflow-wrap:anywhere}@media(prefers-color-scheme:dark){body{background:#111b25;color:#e3eaf0}a{color:#8cc7ff}header,footer{border-color:#496176}.draft{background:#342b0f;color:#ffe6a3}}@media print{body{background:white;color:black}nav,.skip{display:none}a{color:inherit}}'''
manifest = {'status': 'DRAFT_NOT_FOR_DEPLOYMENT', 'reviewDate': '2026-09-28', 'files': {}}
for lang, pages in TITLES.items():
    prefix = '' if lang == 'en' else '/es'
    for slug, title in pages.items():
        fragment = (ROOT / 'content' / lang / (slug + '.html')).read_text()
        other = 'es' if lang == 'en' else 'en'
        alternate = ('/es' if other == 'es' else '') + '/' + slug + '/'
        nav = ' '.join(f'<a href="{prefix}/{key}/">{escape(value)}</a>' for key,value in pages.items())
        nav += f' <a href="{alternate}" lang="{other}" hreflang="{other}">{"Español" if other == "es" else "English"}</a>'
        banner = ('Draft for review — not effective and not published. Review date: September 28, 2026.' if lang == 'en' else 'Borrador para revisión — sin vigencia y sin publicar. Fecha de revisión: 28 de septiembre de 2026.')
        skip = 'Skip to content' if lang == 'en' else 'Ir al contenido'
        navlabel = 'Policy navigation and language' if lang == 'en' else 'Navegación de políticas e idioma'
        html = f'''<!doctype html>
<html lang="{lang}"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1"><meta name="robots" content="noindex,nofollow"><title>{escape(title)} | TrustCheck Radar — DRAFT</title><style>{CSS}</style></head>
<body><a class="skip" href="#content">{skip}</a><header><p class="brand">TrustCheck Radar</p><nav aria-label="{navlabel}">{nav}</nav></header>
<main id="content"><p class="draft">{banner}</p><h1>{escape(title)}</h1>{fragment}</main>
<footer>AndMoreThings Labs LLC · <a href="mailto:privacy@andmorethings.com">privacy@andmorethings.com</a></footer></body></html>
'''
        relative = Path(prefix.lstrip('/')) / slug / 'index.html'
        out = ROOT / 'preview' / relative
        out.parent.mkdir(parents=True, exist_ok=True)
        out.write_text(html)
        manifest['files'][str(relative)] = hashlib.sha256(out.read_bytes()).hexdigest()
(ROOT / 'preview-manifest.json').write_text(json.dumps(manifest, indent=2)+'\n')
print('Built 6 DRAFT previews; no upload performed.')
