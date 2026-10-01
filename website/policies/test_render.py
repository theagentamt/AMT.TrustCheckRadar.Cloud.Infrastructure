import importlib.util
import unittest
from datetime import date
from pathlib import Path


MODULE_PATH = Path(__file__).with_name("render.py")
SPEC = importlib.util.spec_from_file_location("policy_renderer", MODULE_PATH)
renderer = importlib.util.module_from_spec(SPEC)
assert SPEC.loader is not None
SPEC.loader.exec_module(renderer)


class PolicyRendererTests(unittest.TestCase):
    def test_release_requires_effective_date(self):
        with self.assertRaisesRegex(ValueError, "effective date"):
            renderer.render_document("en", "privacy-policy", "<p>Body</p>", mode="release", effective_date=None)

    def test_preview_is_guarded(self):
        html = renderer.render_document("en", "privacy-policy", "<p>Body</p>", mode="preview", effective_date=None)
        self.assertIn("DRAFT", html)
        self.assertIn("noindex,nofollow", html)
        self.assertNotIn('class="effective"', html)

    def test_release_has_public_metadata_without_draft_markers(self):
        html = renderer.render_document(
            "en", "privacy-policy", "<p>Body</p>", mode="release", effective_date=date(2026, 9, 30)
        )
        self.assertIn("Effective: September 30, 2026", html)
        self.assertIn('rel="canonical" href="https://andmorethings.com/privacy-policy/"', html)
        self.assertIn('hreflang="es" href="https://andmorethings.com/es/privacy-policy/"', html)
        self.assertNotIn("DRAFT", html)
        self.assertNotIn("noindex,nofollow", html)

    def test_spanish_release_date_and_links(self):
        html = renderer.render_document(
            "es", "data-deletion", "<p>Contenido</p>", mode="release", effective_date=date(2026, 9, 30)
        )
        self.assertIn("Vigente desde: 30 de septiembre de 2026", html)
        self.assertIn('href="/data-deletion/" lang="en"', html)
        self.assertIn('href="/es/privacy-policy/"', html)

    def test_public_routes_are_stable(self):
        self.assertEqual("/privacy-policy/", renderer.route("en", "privacy-policy"))
        self.assertEqual("/es/privacy-policy/", renderer.route("es", "privacy-policy"))
        self.assertEqual(Path("terms-of-use/index.html"), renderer.relative_path("en", "terms-of-use"))
        self.assertEqual(Path("es/terms-of-use/index.html"), renderer.relative_path("es", "terms-of-use"))

    def test_source_fragments_exclude_internal_publication_notes(self):
        forbidden = ("Publication review:", "Revisión previa a la publicación:")
        for path in (MODULE_PATH.parent / "content").glob("*/*.html"):
            source = path.read_text()
            for marker in forbidden:
                self.assertNotIn(marker, source, path)


if __name__ == "__main__":
    unittest.main()
