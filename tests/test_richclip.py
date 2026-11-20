"""Rich clipboard: the styled variant of copied text, kept beside cliphist."""

from __future__ import annotations

import json
import os
import tempfile
import time
import unittest
from pathlib import Path
from unittest import mock

from vitrail import richclip

FIREFOX = (
    '<meta http-equiv="content-type" content="text/html; charset=utf-8">'
    '<span style="color: rgb(255, 0, 0); font-family: Georgia, serif; font-size: 24px; font-weight: 700;">Hi</span>'
    "<!--StartFragment--> <i>there</i>"
)


class SanitizeTests(unittest.TestCase):
    def clean(self, html: str) -> str:
        return richclip.sanitize(html)

    def test_style_survives_in_a_normal_form(self) -> None:
        out = self.clean(FIREFOX)
        self.assertIn("color: rgb(255, 0, 0)", out)
        self.assertIn("font-family: Georgia, serif", out)
        self.assertIn("font-size: 24px", out)
        self.assertIn("font-weight: 700", out)
        self.assertIn("<i>there</i>", out)
        self.assertNotIn("<meta", out)
        self.assertNotIn("StartFragment", out)

    def test_scripts_and_their_text_are_gone(self) -> None:
        out = self.clean("<p>a</p><script>alert(1)</script><style>p{color:red}</style><p>b</p>")
        self.assertEqual(out, "<p>a</p><p>b</p>")

    def test_event_handlers_and_unknown_attributes_are_gone(self) -> None:
        out = self.clean('<p onclick="x()" id="y" class="z" data-a="1" style="color:red">t</p>')
        self.assertEqual(out, '<p style="color: red">t</p>')

    def test_nothing_remote_is_kept(self) -> None:
        for html in (
            '<img src="https://evil.example/a.png">',
            '<iframe src="https://evil.example"></iframe>',
            '<link rel="stylesheet" href="https://evil.example/a.css">',
            '<object data="x"></object><embed src="x">',
            '<svg><image href="https://evil.example/x"/></svg>',
        ):
            with self.subTest(html=html):
                out = self.clean(html)
                self.assertNotIn("evil", out)
                self.assertNotIn("<img", out)

    def test_css_that_fetches_or_runs_is_dropped(self) -> None:
        out = self.clean(
            '<p style="background-color: red; background-image: url(https://evil.example/a.png);'
            ' color: expression(alert(1)); font-size: 12px; position: fixed">t</p>'
        )
        self.assertEqual(out, '<p style="background-color: red; font-size: 12px">t</p>')

    def test_a_style_value_cannot_break_out_of_the_attribute(self) -> None:
        out = self.clean('<p style="font-family: &quot;A&quot; onmouseover=&quot;x()">t</p>')
        self.assertNotIn('" onmouseover', out)
        self.assertNotIn("<script", out)

    def test_links_keep_only_web_addresses(self) -> None:
        self.assertEqual(self.clean('<a href="https://a.b/c">x</a>'), '<a href="https://a.b/c">x</a>')
        self.assertEqual(self.clean('<a href="javascript:alert(1)">x</a>'), "<a>x</a>")
        self.assertEqual(self.clean('<a href="file:///etc/passwd">x</a>'), "<a>x</a>")

    def test_text_is_escaped_and_unknown_tags_keep_their_content(self) -> None:
        self.assertEqual(self.clean("<section><b>a &lt; b</b> &amp; c</section>"), "<b>a &lt; b</b> &amp; c")

    def test_lists_and_tables_are_kept_and_balanced(self) -> None:
        out = self.clean("<ul><li>one<li>two</ul><table><tr><td>x")
        self.assertEqual(out.count("<ul>"), out.count("</ul>"))
        self.assertEqual(out.count("<li>"), out.count("</li>"))
        self.assertIn("</table>", out)

    def test_nothing_is_still_nothing(self) -> None:
        self.assertEqual(self.clean(""), "")
        self.assertEqual(self.clean("<script>x</script>"), "")

    def test_a_sanitized_text_stays_the_same_when_sanitized_again(self) -> None:
        once = self.clean(FIREFOX)
        self.assertEqual(self.clean(once), once)


class StoreTests(unittest.TestCase):
    def setUp(self) -> None:
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.dir = Path(self.tmp.name) / "clipboard"

    def test_the_variant_is_found_by_the_plain_text(self) -> None:
        richclip.save("hello", "<b>hello</b>", self.dir)
        self.assertEqual(richclip.load("hello", self.dir), "<b>hello</b>")
        self.assertIsNone(richclip.load("other", self.dir))

    def test_the_same_text_keeps_the_newest_style(self) -> None:
        richclip.save("hello", "<b>1</b>", self.dir)
        richclip.save("hello", "<i>2</i>", self.dir)
        self.assertEqual(richclip.load("hello", self.dir), "<i>2</i>")
        self.assertEqual(len(list(self.dir.glob("*.html"))), 1)

    def test_files_and_folder_are_private(self) -> None:
        path = richclip.save("hello", "<b>x</b>", self.dir)
        self.assertEqual(path.stat().st_mode & 0o777, 0o600)
        self.assertEqual(self.dir.stat().st_mode & 0o777, 0o700)

    def test_a_huge_variant_is_not_kept(self) -> None:
        self.assertIsNone(richclip.save("hello", "x" * (richclip.MAX_HTML + 1), self.dir))
        self.assertFalse(self.dir.exists() and list(self.dir.glob("*.html")))

    def test_forget_removes_one(self) -> None:
        richclip.save("a", "<b>a</b>", self.dir)
        richclip.save("b", "<b>b</b>", self.dir)
        richclip.forget("a", self.dir)
        self.assertIsNone(richclip.load("a", self.dir))
        self.assertIsNotNone(richclip.load("b", self.dir))

    def test_clear_removes_everything(self) -> None:
        richclip.save("a", "<b>a</b>", self.dir)
        richclip.save("b", "<b>b</b>", self.dir)
        richclip.clear(self.dir)
        self.assertEqual(list(self.dir.glob("*.html")), [])

    def test_prune_keeps_what_the_history_still_has(self) -> None:
        for text in ("a", "b", "c"):
            richclip.save(text, f"<b>{text}</b>", self.dir)
            os.utime(richclip.path_for(text, self.dir), (1, 1))
        richclip.prune({richclip.key("b")}, self.dir, now=time.time())
        self.assertIsNone(richclip.load("a", self.dir))
        self.assertIsNotNone(richclip.load("b", self.dir))
        self.assertIsNone(richclip.load("c", self.dir))

    def test_prune_spares_the_newest_so_a_copy_in_flight_is_not_lost(self) -> None:
        richclip.save("fresh", "<b>x</b>", self.dir)
        richclip.prune(set(), self.dir, now=time.time())
        self.assertIsNotNone(richclip.load("fresh", self.dir))

    def test_the_keys_of_the_history_skip_images(self) -> None:
        answers = {
            ("cliphist", "list"): b"3\t[[ binary data 1 KiB png 2x2 ]]\n2\tb\n1\ta\n",
            ("cliphist", "decode", "2"): b"b",
            ("cliphist", "decode", "1"): b"a",
        }

        def run(argv: list[str]) -> bytes | None:
            return answers.get(tuple(argv))

        self.assertEqual(richclip.history_keys(run), {richclip.key("a"), richclip.key("b")})

    def test_a_failing_cliphist_has_no_history_and_prunes_nothing(self) -> None:
        richclip.save("a", "<b>a</b>", self.dir)
        os.utime(richclip.path_for("a", self.dir), (1, 1))
        self.assertIsNone(richclip.history_keys(lambda argv: None))
        richclip.prune(None, self.dir, now=time.time())
        self.assertIsNotNone(richclip.load("a", self.dir))


class CaptureTests(unittest.TestCase):
    """What the watcher stores when the clipboard changes."""

    def setUp(self) -> None:
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.dir = Path(self.tmp.name) / "clipboard"

    def watcher(self, types: str | None, plain=b"hello", html=b"<b>hello</b>", second=None):
        reads = {"plain": 0}

        def run(argv: list[str]) -> bytes | None:
            if argv[:2] == ["wl-paste", "--list-types"]:
                return None if types is None else types.encode()
            if argv[-1] == "text/html":
                return html
            if argv[-1] == "text":
                reads["plain"] += 1
                return second if reads["plain"] > 1 and second is not None else plain
            return None

        return run

    def capture(self, types, enabled=True, **extra):
        return richclip.capture(self.watcher(types, **extra), self.dir, enabled=enabled)

    def test_html_beside_text_is_stored_under_the_text(self) -> None:
        self.assertTrue(self.capture("text/plain\ntext/html\n"))
        self.assertEqual(richclip.load("hello", self.dir), "<b>hello</b>")

    def test_text_alone_stores_nothing(self) -> None:
        self.assertFalse(self.capture("text/plain\nUTF8_STRING\n"))
        self.assertFalse(self.dir.exists())

    def test_the_html_of_an_image_without_text_stores_nothing(self) -> None:
        self.assertFalse(self.capture("text/html\nimage/png\n", plain=None))

    def test_the_preference_off_stores_nothing(self) -> None:
        self.assertFalse(self.capture("text/plain\ntext/html\n", enabled=False))

    def test_a_password_manager_is_never_stored(self) -> None:
        self.assertFalse(self.capture("text/plain\ntext/html\nx-kde-passwordManagerHint\n"))

    def test_a_clipboard_that_changed_while_reading_is_dropped(self) -> None:
        self.assertFalse(self.capture("text/plain\ntext/html\n", second=b"another"))
        self.assertFalse(self.dir.exists())

    def test_a_failing_wl_paste_stores_nothing(self) -> None:
        self.assertFalse(self.capture(None))

    def test_a_charset_suffix_is_still_html(self) -> None:
        run = self.watcher("text/plain\ntext/html;charset=utf-8\n")

        def run2(argv: list[str]) -> bytes | None:
            if argv[-1] == "text/html;charset=utf-8":
                return b"<i>x</i>"
            return run(argv)

        self.assertTrue(richclip.capture(run2, self.dir))

    def test_the_text_is_hashed_as_cliphist_gets_it(self) -> None:
        self.capture("text/plain\ntext/html\n", plain="café\n".encode())
        self.assertIsNotNone(richclip.load("café\n", self.dir))


class PreviewTests(unittest.TestCase):
    def setUp(self) -> None:
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.dir = Path(self.tmp.name) / "clipboard"

    def test_a_text_with_a_variant_previews_styled_and_sanitized(self) -> None:
        richclip.save("hi", '<b onclick="x()">hi</b><script>1</script>', self.dir)
        out = richclip.preview(b"hi", self.dir)
        self.assertEqual(out["kind"], "text")
        self.assertEqual(out["text"], "hi")
        self.assertEqual(out["html"], "<b>hi</b>")

    def test_a_plain_text_has_no_html(self) -> None:
        self.assertEqual(richclip.preview(b"hi", self.dir), {"kind": "text", "text": "hi", "html": ""})

    def test_long_text_is_cut(self) -> None:
        out = richclip.preview(b"x" * (richclip.MAX_PREVIEW_TEXT + 50), self.dir)
        self.assertEqual(len(out["text"]), richclip.MAX_PREVIEW_TEXT)

    def test_binary_data_is_not_text(self) -> None:
        self.assertEqual(richclip.preview(b"\x89PNG\r\n\x1a\n\x00\x00", self.dir), {"kind": "binary"})

    def test_a_huge_sanitized_variant_falls_back_to_the_text(self) -> None:
        richclip.save("hi", "<b>" + "x" * (richclip.MAX_PREVIEW_HTML + 10) + "</b>", self.dir)
        self.assertEqual(richclip.preview(b"hi", self.dir)["html"], "")


class CopyTests(unittest.TestCase):
    def setUp(self) -> None:
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.dir = Path(self.tmp.name) / "clipboard"
        self.served: list[dict] = []
        self.plain: list[bytes] = []

    def copy(self, data: bytes, rich=True, serve_ok=True, **extra):
        def serve(payload: dict) -> bool:
            self.served.append(payload)
            return serve_ok

        return richclip.copy(
            data,
            self.dir,
            enabled=rich,
            serve=serve,
            plain_copy=lambda raw: self.plain.append(raw) or True,
            **extra,
        )

    def test_a_text_with_a_variant_offers_both_types_at_once(self) -> None:
        richclip.save("hello", "<b>hello</b>", self.dir)
        self.assertEqual(self.copy(b"hello"), "rich")
        self.assertEqual(self.served, [{"plain": "hello", "html": "<b>hello</b>"}])
        self.assertEqual(self.plain, [])

    def test_the_original_html_is_what_is_offered_not_the_preview(self) -> None:
        richclip.save("hello", '<b onclick="x()">hello</b>', self.dir)
        self.copy(b"hello")
        self.assertEqual(self.served[0]["html"], '<b onclick="x()">hello</b>')

    def test_without_a_variant_it_is_plain(self) -> None:
        self.assertEqual(self.copy(b"hello"), "plain")
        self.assertEqual(self.plain, [b"hello"])
        self.assertEqual(self.served, [])

    def test_the_preference_off_is_plain_even_with_a_variant(self) -> None:
        richclip.save("hello", "<b>hello</b>", self.dir)
        self.assertEqual(self.copy(b"hello", rich=False), "plain")
        self.assertEqual(self.served, [])

    def test_a_failing_helper_falls_back_to_plain(self) -> None:
        richclip.save("hello", "<b>hello</b>", self.dir)
        self.assertEqual(self.copy(b"hello", serve_ok=False), "plain")
        self.assertEqual(self.plain, [b"hello"])

    def test_an_image_goes_as_it_is(self) -> None:
        png = b"\x89PNG\r\n\x1a\n\x00\x00"
        self.assertEqual(self.copy(png), "plain")
        self.assertEqual(self.plain, [png])

    def test_the_terminal_form_is_always_plain_and_without_trailing_newlines(self) -> None:
        richclip.save("hello\n\n", "<b>hello</b>", self.dir)
        self.assertEqual(self.copy(b"hello\n\n", trim=True), "plain")
        self.assertEqual(self.plain, [b"hello"])
        self.assertEqual(self.served, [])


class ServeTests(unittest.TestCase):
    def test_the_helper_gets_the_payload_and_must_say_ok(self) -> None:
        class Child:
            def __init__(self) -> None:
                self.stdin = mock.Mock()
                self.stdout = mock.Mock()
                self.stdout.readline.return_value = b"ok\n"

            def poll(self):
                return None

        child = Child()
        self.assertTrue(richclip.launch({"plain": "a", "html": "<b>a</b>"}, popen=lambda *a, **k: child))
        written = child.stdin.write.call_args[0][0]
        self.assertEqual(json.loads(written), {"plain": "a", "html": "<b>a</b>"})

    def test_a_helper_that_does_not_answer_is_a_failure(self) -> None:
        class Child:
            def __init__(self) -> None:
                self.stdin = mock.Mock()
                self.stdout = mock.Mock()
                self.stdout.readline.return_value = b""
                self.killed = False

            def poll(self):
                return 1

            def kill(self) -> None:
                self.killed = True

        self.assertFalse(richclip.launch({"plain": "a", "html": "x"}, popen=lambda *a, **k: Child()))

    def test_a_missing_python_is_a_failure(self) -> None:
        def broken(*args, **kwargs):
            raise OSError("no")

        self.assertFalse(richclip.launch({"plain": "a", "html": "x"}, popen=broken))

    def test_the_offered_types_cover_the_text_aliases_and_html(self) -> None:
        types = richclip.offered_types()
        self.assertIn("text/plain;charset=utf-8", types["plain"])
        self.assertIn("UTF8_STRING", types["plain"])
        self.assertEqual(types["html"], ["text/html"])


class EntryTests(unittest.TestCase):
    def test_a_watcher_call_is_one_line(self) -> None:
        with mock.patch.object(richclip, "capture", return_value=True) as capture:
            from vitrail import cli

            with mock.patch("sys.stdin") as stdin:
                stdin.buffer.read.return_value = b"<b>x</b>"
                self.assertEqual(cli.main(["clipboard", "store"]), 0)
        capture.assert_called_once()

    def test_the_preference_decides(self) -> None:
        self.assertTrue(richclip.enabled({}))
        self.assertTrue(richclip.enabled({"clipboardRich": "true"}))
        self.assertFalse(richclip.enabled({"clipboardRich": "false"}))
        self.assertFalse(richclip.enabled({"clipboardRich": "0"}))

    def test_forget_reads_the_text_from_stdin(self) -> None:
        from vitrail import cli

        with tempfile.TemporaryDirectory() as tmp:
            directory = Path(tmp)
            richclip.save("hello", "<b>x</b>", directory)
            with mock.patch.object(richclip, "store_dir", return_value=directory):
                with mock.patch("sys.stdin") as stdin:
                    stdin.buffer.read.return_value = b"hello"
                    self.assertEqual(cli.main(["clipboard", "forget"]), 0)
            self.assertIsNone(richclip.load("hello", directory))


if __name__ == "__main__":
    unittest.main()
