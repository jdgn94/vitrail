"""Downloads: the watcher that turns growing files into live notifications."""

from __future__ import annotations

import os
import tempfile
import unittest
from pathlib import Path

from vitrail import downloads


class Clock:
    def __init__(self, now: float = 1_000.0):
        self.now = now

    def __call__(self) -> float:
        return self.now

    def tick(self, seconds: float) -> None:
        self.now += seconds


class Folder(unittest.TestCase):
    def setUp(self) -> None:
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name)
        self.downloads = self.root / "Downloads"
        self.downloads.mkdir()
        self.clock = Clock()

    def watcher(self, app=None) -> downloads.Watcher:
        return downloads.Watcher([self.downloads], self.clock, app or (lambda path: "Firefox"))


class FormatTests(unittest.TestCase):
    def test_sizes_read_like_a_downloader(self) -> None:
        self.assertEqual(downloads.human_size(0), "0 B")
        self.assertEqual(downloads.human_size(999), "999 B")
        self.assertEqual(downloads.human_size(1500), "1.5 KB")
        self.assertEqual(downloads.human_size(12_400_000), "12.4 MB")
        self.assertEqual(downloads.human_size(2.5e9), "2.5 GB")

    def test_times_read_like_a_stopwatch(self) -> None:
        self.assertEqual(downloads.human_time(0), "0:00")
        self.assertEqual(downloads.human_time(7), "0:07")
        self.assertEqual(downloads.human_time(83), "1:23")
        self.assertEqual(downloads.human_time(3723), "1:02:03")

    def test_the_final_name_drops_the_downloaders_suffix(self) -> None:
        self.assertEqual(downloads.final_of(Path("/d/big.iso.part")), Path("/d/big.iso"))
        self.assertEqual(downloads.final_of(Path("/d/big.iso.crdownload")), Path("/d/big.iso"))
        self.assertEqual(downloads.final_of(Path("/d/archive.tar.download")), Path("/d/archive.tar"))
        self.assertEqual(downloads.final_of(Path("/d/notes.tmp")), Path("/d/notes"))


class MeasureTests(Folder):
    def test_a_growing_file_does_not_say_its_total(self) -> None:
        path = self.downloads / "big.iso.part"
        path.write_bytes(b"x" * 500)
        size, total = downloads.measure(path)
        self.assertEqual(size, 500)
        self.assertIsNone(total)

    def test_a_reserved_file_says_its_total(self) -> None:
        path = self.downloads / "big.iso.part"
        with path.open("wb") as out:
            out.truncate(10_000_000)
            out.write(b"x" * 1_000_000)
        size, total = downloads.measure(path)
        self.assertEqual(total, 10_000_000)
        self.assertLess(size, 2_000_000)


class AppTests(Folder):
    def test_the_process_holding_the_file_names_the_app(self) -> None:
        self.assertEqual(downloads.app_name(self.downloads / "x.part", lambda path: "firefox"), "Firefox")
        self.assertEqual(downloads.app_name(self.downloads / "x.part", lambda path: "aria2c"), "aria2")

    def test_without_a_process_the_suffix_says_what_it_can(self) -> None:
        self.assertEqual(downloads.app_name(self.downloads / "x.crdownload", lambda path: ""), "Chromium")
        self.assertEqual(downloads.app_name(self.downloads / "x.part", lambda path: ""), "Firefox")
        self.assertEqual(downloads.app_name(self.downloads / "x.tmp", lambda path: ""), "")

    def test_the_download_folders_come_from_user_dirs(self) -> None:
        config = self.root / "config"
        config.mkdir()
        (config / "user-dirs.dirs").write_text('XDG_DOWNLOAD_DIR="$HOME/Descargas"\n', encoding="utf-8")
        home = self.root / "home"
        self.assertEqual(downloads.download_dirs(home, config),
                         [home / "Descargas", home / "Downloads"])

    def test_the_home_itself_is_never_watched(self) -> None:
        config = self.root / "config"
        config.mkdir()
        (config / "user-dirs.dirs").write_text('XDG_DOWNLOAD_DIR="$HOME/"\n', encoding="utf-8")
        home = self.root / "home"
        self.assertEqual(downloads.download_dirs(home, config), [home / "Downloads"])


class WatchTests(Folder):
    def test_a_file_is_announced_once_then_followed(self) -> None:
        path = self.downloads / "big.iso.part"
        path.write_bytes(b"x" * 100)
        watcher = self.watcher()
        events = watcher.scan()
        self.assertEqual([kind for kind, _item in events], ["started"])
        self.assertEqual(events[0][1].name, "big.iso")
        self.assertEqual(events[0][1].app, "Firefox")
        self.assertIsNone(events[0][1].percent())

        self.clock.tick(1)
        path.write_bytes(b"x" * 300)
        events = watcher.scan()
        self.assertEqual([kind for kind, _item in events], ["updated"])
        item = events[0][1]
        self.assertEqual(item.size, 300)
        self.assertGreater(item.speed, 100)

    def test_a_preallocated_file_has_a_percentage(self) -> None:
        path = self.downloads / "big.iso.part"
        with path.open("wb") as out:
            out.truncate(10_000_000)
            out.write(b"x" * 1_000_000)
        item = self.watcher().scan()[0][1]
        self.assertEqual(item.total, 10_000_000)
        self.assertTrue(5 <= item.percent() <= 15)

    def test_the_final_file_ends_the_download(self) -> None:
        path = self.downloads / "big.iso.part"
        path.write_bytes(b"x" * 100)
        watcher = self.watcher()
        watcher.scan()
        self.clock.tick(4)
        path.rename(self.downloads / "big.iso")
        events = watcher.scan()
        self.assertEqual([kind for kind, _item in events], ["finished"])
        item = events[0][1]
        self.assertEqual((item.state, item.size, item.duration), ("done", 100, 4))

    def test_a_file_that_disappears_without_its_final_is_gone(self) -> None:
        path = self.downloads / "big.iso.part"
        path.write_bytes(b"x" * 100)
        watcher = self.watcher()
        watcher.scan()
        path.unlink()
        self.clock.tick(1)
        events = watcher.scan()
        self.assertEqual([kind for kind, _item in events], ["gone"])

    def test_cancelling_removes_the_partial_file(self) -> None:
        path = self.downloads / "big.iso.part"
        path.write_bytes(b"x" * 100)
        watcher = self.watcher()
        item = watcher.scan()[0][1]
        watcher.cancel(item)
        self.assertFalse(path.exists())
        self.clock.tick(0.5)
        self.assertEqual(watcher.scan(), [])
        self.clock.tick(2)
        events = watcher.scan()
        self.assertEqual([kind for kind, _item in events], ["cancelled"])
        self.assertEqual(events[0][1].state, "cancelled")

    def test_a_cancel_the_app_ignores_says_the_app_is_still_writing(self) -> None:
        path = self.downloads / "big.iso.part"
        path.write_bytes(b"x" * 100)
        watcher = self.watcher()
        item = watcher.scan()[0][1]
        watcher.cancel(item)
        path.write_bytes(b"x" * 200)
        self.clock.tick(2.5)
        events = watcher.scan()
        self.assertEqual([kind for kind, _item in events], ["busy"])
        self.assertEqual(events[0][1].state, "busy")

    def test_a_leftover_partial_file_is_not_a_download(self) -> None:
        path = self.downloads / "old.iso.part"
        path.write_bytes(b"x" * 100)
        os.utime(path, (1.0, 1.0))
        self.assertEqual(self.watcher().scan(), [])

    def test_a_file_the_downloader_resumed_is_still_live(self) -> None:
        path = self.downloads / "big.iso.part"
        path.write_bytes(b"x" * 100)
        watcher = self.watcher()
        watcher.scan()
        path.write_bytes(b"x" * 400)
        self.clock.tick(1)
        self.assertEqual([kind for kind, _item in watcher.scan()], ["updated"])


class FakeNotifier:
    def __init__(self) -> None:
        self.sent: list[dict] = []

    def send(self, summary, body, actions=None, hints=None, replace=0, timeout=0) -> int:
        self.sent.append({"summary": summary, "body": body, "actions": actions,
                          "hints": hints, "replace": replace})
        return len(self.sent) + 10


class DaemonTests(Folder):
    def daemon(self, opened=None):
        notifier = FakeNotifier()
        daemon = downloads.Daemon(self.watcher(), notifier, language="en",
                                  open_path=(opened.append if opened is not None else (lambda path: None)))
        return daemon, notifier

    def test_a_live_download_is_one_notification_replaced_in_place(self) -> None:
        path = self.downloads / "big.iso.part"
        path.write_bytes(b"x" * 100)
        daemon, notifier = self.daemon()
        daemon.step()
        first = notifier.sent[0]
        self.assertEqual(first["summary"], "Downloading big.iso")
        self.assertTrue(first["body"].startswith("Firefox · "))
        self.assertEqual(first["actions"], ["cancel", "Cancel"])
        self.assertEqual(first["hints"]["x-vitrail-state"], "live")
        self.assertNotIn("value", first["hints"])
        self.assertEqual(first["replace"], 0)

        self.clock.tick(1)
        path.write_bytes(b"x" * 300)
        daemon.step()
        self.assertEqual(notifier.sent[1]["replace"], 11)
        self.assertIn("300 B", notifier.sent[1]["body"])

    def test_the_end_offers_delete_open_folder_and_open_file(self) -> None:
        path = self.downloads / "big.iso.part"
        path.write_bytes(b"x" * 100)
        daemon, notifier = self.daemon()
        daemon.step()
        self.clock.tick(3)
        path.rename(self.downloads / "big.iso")
        daemon.step()
        last = notifier.sent[-1]
        self.assertEqual(last["summary"], "Downloaded big.iso")
        self.assertEqual(last["hints"]["x-vitrail-state"], "done")
        self.assertEqual(last["actions"], ["delete", "Delete", "folder", "Open folder", "file", "Open file"])
        self.assertIn("in 0:03", last["body"])

    def test_cancel_from_the_card_removes_the_file_and_then_reports_it(self) -> None:
        path = self.downloads / "big.iso.part"
        path.write_bytes(b"x" * 100)
        daemon, notifier = self.daemon()
        daemon.step()
        nid = next(iter(daemon.by_id))
        daemon.on_action(nid, "cancel")
        self.assertFalse(path.exists())
        self.assertEqual(notifier.sent[-1]["summary"], "Cancelling big.iso")
        self.clock.tick(3)
        daemon.step()
        self.assertEqual(notifier.sent[-1]["summary"], "Download cancelled")

    def test_delete_folder_and_file_use_the_paths(self) -> None:
        opened: list[Path] = []
        path = self.downloads / "big.iso.part"
        path.write_bytes(b"x" * 100)
        daemon, _notifier = self.daemon(opened)
        daemon.step()
        self.clock.tick(2)
        path.rename(self.downloads / "big.iso")
        daemon.step()
        nid = next(iter(daemon.by_id))
        daemon.on_action(nid, "folder")
        daemon.on_action(nid, "file")
        self.assertEqual(opened, [self.downloads, self.downloads / "big.iso"])
        daemon.on_action(nid, "delete")
        self.assertFalse((self.downloads / "big.iso").exists())

    def test_an_unknown_action_changes_nothing(self) -> None:
        daemon, notifier = self.daemon()
        daemon.on_action(999, "cancel")
        self.assertEqual(notifier.sent, [])


class WordsTests(Folder):
    def test_the_texts_come_from_the_i18n_files(self) -> None:
        item = downloads.Download(path=Path("/d/a.part"), final=Path("/d/a"), app="Firefox", first=0.0)
        self.assertEqual(downloads.announce_text("started", item, "en")[0], "Downloading a")
        self.assertEqual(downloads.announce_text("started", item, "es")[0], "Descargando a")
        self.assertEqual(downloads.actions_for("finished", "es")[1], "Eliminar")
        self.assertEqual(downloads.t("downloads.body.of", "1 B", "2 B", language="de"), "1 B von 2 B")


if __name__ == "__main__":
    unittest.main()
