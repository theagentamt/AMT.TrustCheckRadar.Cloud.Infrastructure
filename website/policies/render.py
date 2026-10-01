"""Render the bilingual policy source as guarded previews or release artifacts."""

from __future__ import annotations

import argparse
import hashlib
import json
from datetime import date
from html import escape
from pathlib import Path


ROOT = Path(__file__).resolve().parent
PUBLIC_ORIGIN = "https://andmorethings.com"
TITLES = {
    "en": {
        "privacy-policy": "Privacy Policy",
        "terms-of-use": "Terms of Use",
        "data-deletion": "Account and Data Deletion",
    },
    "es": {
        "privacy-policy": "Política de privacidad",
        "terms-of-use": "Condiciones de uso",
        "data-deletion": "Eliminación de cuenta y datos",
    },
}
MONTHS_ES = (
    "enero", "febrero", "marzo", "abril", "mayo", "junio",
    "julio", "agosto", "septiembre", "octubre", "noviembre", "diciembre",
)
CSS = """*{box-sizing:border-box}body{margin:0;background:#f6f8fa;color:#172b3a;font:1.05rem/1.7 system-ui,sans-serif}header,main,footer{max-width:850px;margin:auto;padding:1.5rem}header{border-bottom:1px solid #c9d6df}nav{display:flex;flex-wrap:wrap;gap:1rem}a{color:#124e85;text-underline-offset:.2em}a:focus-visible{outline:3px solid #925500;outline-offset:4px}h1{font-size:clamp(2rem,6vw,3rem);line-height:1.15}h2{line-height:1.35;margin-top:2.3rem}li{margin:.75rem 0}.draft{background:#fff3cc;border:2px solid #856000;padding:1rem}.effective{font-weight:650}.brand{font-weight:750;letter-spacing:.03em}.skip{position:absolute;left:-10000px}.skip:focus{left:1rem;top:1rem;background:white;padding:.6rem}footer{border-top:1px solid #c9d6df;font-size:.95rem}p,li,a{overflow-wrap:anywhere}@media(prefers-color-scheme:dark){body{background:#111b25;color:#e3eaf0}a{color:#8cc7ff}header,footer{border-color:#496176}.draft{background:#342b0f;color:#ffe6a3}}@media print{body{background:white;color:black}nav,.skip{display:none}a{color:inherit}}"""


def route(lang: str, slug: str) -> str:
    return f"/{'es/' if lang == 'es' else ''}{slug}/"


def relative_path(lang: str, slug: str) -> Path:
    return Path("es") / slug / "index.html" if lang == "es" else Path(slug) / "index.html"


def formatted_date(lang: str, value: date) -> str:
    if lang == "es":
        return f"{value.day} de {MONTHS_ES[value.month - 1]} de {value.year}"
    return value.strftime("%B %d, %Y").replace(" 0", " ")


def render_document(lang: str, slug: str, fragment: str, *, mode: str, effective_date: date | None) -> str:
    title = TITLES[lang][slug]
    other = "es" if lang == "en" else "en"
    nav = " ".join(
        f'<a href="{route(lang, key)}">{escape(value)}</a>'
        for key, value in TITLES[lang].items()
    )
    nav += (
        f' <a href="{route(other, slug)}" lang="{other}" hreflang="{other}">'
        f'{"Español" if other == "es" else "English"}</a>'
    )
    skip = "Skip to content" if lang == "en" else "Ir al contenido"
    nav_label = "Policy navigation and language" if lang == "en" else "Navegación de políticas e idioma"
    canonical = f"{PUBLIC_ORIGIN}{route(lang, slug)}"
    alternate = f"{PUBLIC_ORIGIN}{route(other, slug)}"

    if mode == "preview":
        robots = '<meta name="robots" content="noindex,nofollow">'
        title_suffix = " — DRAFT"
        status = (
            '<p class="draft">Draft for review — not effective and not published.</p>'
            if lang == "en"
            else '<p class="draft">Borrador para revisión — sin vigencia y sin publicar.</p>'
        )
    else:
        if effective_date is None:
            raise ValueError("release rendering requires an effective date")
        robots = '<meta name="robots" content="index,follow">'
        title_suffix = ""
        label = "Effective" if lang == "en" else "Vigente desde"
        status = f'<p class="effective">{label}: {escape(formatted_date(lang, effective_date))}</p>'

    return f'''<!doctype html>
<html lang="{lang}"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1">{robots}<link rel="canonical" href="{canonical}"><link rel="alternate" hreflang="{lang}" href="{canonical}"><link rel="alternate" hreflang="{other}" href="{alternate}"><title>{escape(title)} | TrustCheck Radar{title_suffix}</title><style>{CSS}</style></head>
<body><a class="skip" href="#content">{skip}</a><header><p class="brand">TrustCheck Radar</p><nav aria-label="{nav_label}">{nav}</nav></header>
<main id="content"><h1>{escape(title)}</h1>{status}{fragment}</main>
<footer>AndMoreThings Labs LLC · <a href="mailto:privacy@andmorethings.com">privacy@andmorethings.com</a></footer></body></html>
'''


def build(mode: str, effective_date: date | None = None) -> dict[str, object]:
    output_root = ROOT / ("preview" if mode == "preview" else "release")
    manifest: dict[str, object] = {
        "status": "DRAFT_NOT_FOR_DEPLOYMENT" if mode == "preview" else "RELEASE_ARTIFACT",
        "effectiveDate": effective_date.isoformat() if effective_date else None,
        "publicOrigin": PUBLIC_ORIGIN,
        "files": {},
    }
    for lang, pages in TITLES.items():
        for slug in pages:
            fragment = (ROOT / "content" / lang / f"{slug}.html").read_text()
            html = render_document(lang, slug, fragment, mode=mode, effective_date=effective_date)
            relative = relative_path(lang, slug)
            output = output_root / relative
            output.parent.mkdir(parents=True, exist_ok=True)
            output.write_text(html)
            manifest["files"][str(relative)] = hashlib.sha256(output.read_bytes()).hexdigest()

    manifest_path = ROOT / ("preview-manifest.json" if mode == "preview" else "release-manifest.json")
    manifest_path.write_text(json.dumps(manifest, indent=2) + "\n")
    return manifest


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--mode", choices=("preview", "release"), default="preview")
    parser.add_argument("--effective-date", type=date.fromisoformat)
    args = parser.parse_args()
    if args.mode == "release" and args.effective_date is None:
        parser.error("--effective-date is required in release mode")
    if args.mode == "preview" and args.effective_date is not None:
        parser.error("--effective-date is only valid in release mode")
    return args


if __name__ == "__main__":
    arguments = parse_args()
    result = build(arguments.mode, arguments.effective_date)
    print(f"Built {len(result['files'])} {arguments.mode} policy pages; no upload performed.")
