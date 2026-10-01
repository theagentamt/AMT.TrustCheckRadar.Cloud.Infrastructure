"""Fail closed when generated policy release artifacts drift from their manifest."""

from __future__ import annotations

import hashlib
import json
import sys
from html.parser import HTMLParser
from pathlib import Path
from urllib.parse import urlparse


ROOT = Path(__file__).resolve().parent
ALLOWED_EXTERNAL_HOSTS = {"andmorethings.com", "play.google.com"}


class PolicyParser(HTMLParser):
    def __init__(self) -> None:
        super().__init__()
        self.hrefs: list[str] = []
        self.lang: str | None = None
        self.h1 = 0
        self.h2 = 0
        self.forms = 0
        self.scripts = 0
        self.external_styles = 0

    def handle_starttag(self, tag: str, attrs: list[tuple[str, str | None]]) -> None:
        values = dict(attrs)
        if tag == "html":
            self.lang = values.get("lang")
        elif tag == "a" and values.get("href"):
            self.hrefs.append(values["href"] or "")
        elif tag == "h1":
            self.h1 += 1
        elif tag == "h2":
            self.h2 += 1
        elif tag == "form":
            self.forms += 1
        elif tag == "script":
            self.scripts += 1
        elif tag == "link" and values.get("rel") == "stylesheet":
            self.external_styles += 1


def fail(message: str) -> None:
    raise AssertionError(message)


def validate() -> None:
    manifest = json.loads((ROOT / "release-manifest.json").read_text())
    if manifest.get("status") != "RELEASE_ARTIFACT":
        fail("release manifest status is not RELEASE_ARTIFACT")
    if not manifest.get("effectiveDate"):
        fail("release manifest has no effective date")

    expected = manifest.get("files", {})
    if len(expected) != 6:
        fail(f"expected six release files, found {len(expected)}")
    observed_headings: dict[str, int] = {}
    for relative, recorded_hash in expected.items():
        path = ROOT / "release" / relative
        if not path.is_file():
            fail(f"missing release file: {relative}")
        payload = path.read_bytes()
        actual_hash = hashlib.sha256(payload).hexdigest()
        if actual_hash != recorded_hash:
            fail(f"manifest hash mismatch: {relative}")
        text = payload.decode("utf-8")
        for marker in ("DRAFT", "noindex,nofollow", "Publication review:", "Revisión previa a la publicación:"):
            if marker in text:
                fail(f"internal marker {marker!r} in {relative}")

        parser = PolicyParser()
        parser.feed(text)
        expected_lang = "es" if relative.startswith("es/") else "en"
        if parser.lang != expected_lang:
            fail(f"wrong or missing language in {relative}")
        if parser.h1 != 1:
            fail(f"expected one h1 in {relative}")
        if parser.forms or parser.scripts or parser.external_styles:
            fail(f"active/external page element found in {relative}")
        observed_headings[relative] = parser.h2
        for href in parser.hrefs:
            parsed = urlparse(href)
            if parsed.scheme in ("", "mailto"):
                continue
            if parsed.scheme != "https" or parsed.hostname not in ALLOWED_EXTERNAL_HOSTS:
                fail(f"unapproved external destination {href!r} in {relative}")

    for slug in ("privacy-policy", "terms-of-use", "data-deletion"):
        if observed_headings[f"{slug}/index.html"] != observed_headings[f"es/{slug}/index.html"]:
            fail(f"English/Spanish heading-count mismatch for {slug}")

    rollback_root = ROOT / "rollback" / "2026-09-30"
    rollback = json.loads((rollback_root / "manifest.json").read_text())
    for key, metadata in rollback["objects"].items():
        if not metadata["present"]:
            continue
        payload = (rollback_root / key).read_bytes()
        if len(payload) != metadata["size"]:
            fail(f"rollback size mismatch: {key}")
        if hashlib.sha256(payload).hexdigest() != metadata["sha256"]:
            fail(f"rollback hash mismatch: {key}")


if __name__ == "__main__":
    try:
        validate()
    except (AssertionError, KeyError, UnicodeDecodeError, json.JSONDecodeError) as error:
        print(f"policy release validation failed: {error}", file=sys.stderr)
        raise SystemExit(1)
    print("Validated six bilingual policy release artifacts and manifest hashes.")
