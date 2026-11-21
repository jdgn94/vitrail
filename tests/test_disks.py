"""Removable drives: what `lsblk --json` says, and the udisksctl commands.

Every fixture is the text lsblk prints and the disk usage is injected, so the
tests never look at a real device, `/dev` or the running system.
"""

from __future__ import annotations

import contextlib
import io
import json
import unittest
from unittest import mock

from vitrail import disks

LSBLK = [
    "lsblk",
    "--json",
    "--bytes",
    "--output",
    "NAME,RM,HOTPLUG,TRAN,MOUNTPOINTS,FSTYPE,LABEL,UUID,SIZE,MODEL,TYPE",
]

# A USB stick, mounted, with one FAT32 partition. The partition's own TRAN and
# MODEL are empty: the parent's answer is the one that counts.
USB_STICK = """\
{
  "blockdevices": [
    {
      "name": "sdb",
      "rm": true,
      "hotplug": true,
      "tran": "usb",
      "mountpoints": [null],
      "fstype": null,
      "label": null,
      "uuid": null,
      "size": 15502336000,
      "model": "USB DISK 3.0",
      "type": "disk",
      "children": [
        {
          "name": "sdb1",
          "rm": true,
          "hotplug": true,
          "tran": null,
          "mountpoints": ["/run/media/juan/KINGSTON"],
          "fstype": "vfat",
          "label": "KINGSTON",
          "uuid": "1A2B-3C4D",
          "size": 15486328832,
          "model": null,
          "type": "part"
        }
      ]
    }
  ]
}
"""

# An external USB SSD: the disk is not marked RM (the bridge says it is fixed),
# but it is hotplug, and it carries two partitions; only one is mounted.
EXTERNAL_SSD = """\
{
  "blockdevices": [
    {
      "name": "sdc",
      "rm": false,
      "hotplug": true,
      "tran": "usb",
      "mountpoints": [null],
      "fstype": null,
      "label": null,
      "uuid": null,
      "size": 1000204886016,
      "model": "Portable SSD T7",
      "type": "disk",
      "children": [
        {
          "name": "sdc1",
          "rm": false,
          "hotplug": true,
          "tran": null,
          "mountpoints": ["/run/media/juan/Windows"],
          "fstype": "ntfs",
          "label": "Windows",
          "uuid": "8C2A1F3E4D5B6A7C",
          "size": 500102432768,
          "model": null,
          "type": "part"
        },
        {
          "name": "sdc2",
          "rm": false,
          "hotplug": true,
          "tran": null,
          "mountpoints": [],
          "fstype": "ext4",
          "label": "Backup",
          "uuid": "2f6c1c6e-1a2b-4c3d-9e8f-0123456789ab",
          "size": 500102432768,
          "model": null,
          "type": "part"
        }
      ]
    }
  ]
}
"""

# The machine's own NVMe and a loop image: fixed, never in the popup.
FIXED_AND_LOOP = """\
{
  "blockdevices": [
    {
      "name": "nvme0n1",
      "rm": false,
      "hotplug": false,
      "tran": "nvme",
      "mountpoints": [],
      "fstype": null,
      "label": null,
      "uuid": null,
      "size": 1024209543168,
      "model": "Samsung SSD 990 PRO 1TB",
      "type": "disk",
      "children": [
        {
          "name": "nvme0n1p1",
          "rm": false,
          "hotplug": false,
          "tran": null,
          "mountpoints": ["/"],
          "fstype": "btrfs",
          "label": "arch",
          "uuid": "a1b2c3d4-0000-4000-8000-111122223333",
          "size": 1024209543168,
          "model": null,
          "type": "part"
        }
      ]
    },
    {
      "name": "loop0",
      "rm": true,
      "hotplug": true,
      "tran": null,
      "mountpoints": ["/var/lib/snapd/snap/core/1"],
      "fstype": "squashfs",
      "label": null,
      "uuid": null,
      "size": 128000000,
      "model": null,
      "type": "loop"
    },
    {
      "name": "zram0",
      "rm": false,
      "hotplug": false,
      "tran": null,
      "mountpoints": ["[SWAP]"],
      "fstype": "swap",
      "label": null,
      "uuid": null,
      "size": 8589934592,
      "model": null,
      "type": "zram"
    }
  ]
}
"""

# A stick after `udisksctl power-off`: the node is still there for a moment,
# with no filesystem and no mount point.
EJECTED = """\
{
  "blockdevices": [
    {
      "name": "sdd",
      "rm": true,
      "hotplug": true,
      "tran": "usb",
      "mountpoints": [],
      "fstype": null,
      "label": null,
      "uuid": null,
      "size": 8004304896,
      "model": "Cruzer Blade",
      "type": "disk",
      "children": null
    }
  ]
}
"""


class Runner:
    """A fake process runner: one (status, stdout, stderr) answer per call."""

    def __init__(self, status: int = 0, out: str = "", err: str = ""):
        self.status, self.out, self.err = status, out, err
        self.calls: list[list[str]] = []

    def __call__(self, argv: list[str]) -> tuple[int, str, str]:
        self.calls.append(argv)
        return self.status, self.out, self.err


class ParseTests(unittest.TestCase):
    def test_a_mounted_usb_stick_is_one_partition(self) -> None:
        found = disks.parse(USB_STICK)
        self.assertEqual(len(found), 1)
        self.assertEqual(
            found[0],
            {
                "name": "/dev/sdb1",
                "label": "KINGSTON",
                "uuid": "1A2B-3C4D",
                "fstype": "vfat",
                "size": 15486328832,
                "model": "USB DISK 3.0",
                "transport": "usb",
                "mounted": True,
                "mountpoint": "/run/media/juan/KINGSTON",
                "used": None,
                "free": None,
            },
        )

    def test_both_partitions_of_an_external_ssd_keep_the_parents_transport_and_model(self) -> None:
        found = disks.parse(EXTERNAL_SSD)
        self.assertEqual([one["name"] for one in found], ["/dev/sdc1", "/dev/sdc2"])
        for one in found:
            self.assertEqual(one["transport"], "usb")
            self.assertEqual(one["model"], "Portable SSD T7")
        self.assertTrue(found[0]["mounted"])
        self.assertEqual(found[0]["mountpoint"], "/run/media/juan/Windows")
        self.assertFalse(found[1]["mounted"])
        self.assertEqual(found[1]["mountpoint"], "")

    def test_a_fixed_nvme_and_a_loop_and_zram_are_not_removable(self) -> None:
        self.assertEqual(disks.parse(FIXED_AND_LOOP), [])

    def test_an_ejected_stick_is_still_a_connected_device(self) -> None:
        found = disks.parse(EJECTED)
        self.assertEqual(len(found), 1)
        one = found[0]
        self.assertEqual(one["name"], "/dev/sdd")
        self.assertEqual(one["label"], "")
        self.assertEqual(one["uuid"], "")
        self.assertEqual(one["fstype"], "")
        self.assertFalse(one["mounted"])
        self.assertIsNone(one["used"])
        self.assertIsNone(one["free"])

    def test_an_empty_or_broken_document_has_no_devices(self) -> None:
        self.assertEqual(disks.parse('{"blockdevices": []}'), [])
        self.assertEqual(disks.parse(""), [])
        self.assertEqual(disks.parse("not json"), [])

    def test_a_missing_transport_or_model_is_an_empty_string(self) -> None:
        text = json.dumps(
            {
                "blockdevices": [
                    {
                        "name": "sde",
                        "rm": True,
                        "hotplug": True,
                        "tran": None,
                        "mountpoints": [None],
                        "fstype": None,
                        "label": None,
                        "uuid": None,
                        "size": 100,
                        "model": None,
                        "type": "disk",
                    }
                ]
            }
        )
        one = disks.parse(text)[0]
        self.assertEqual(
            (one["transport"], one["model"], one["label"], one["uuid"], one["fstype"]), ("", "", "", "", "")
        )


class StateTests(unittest.TestCase):
    def test_state_reads_lsblk_once_and_fills_used_and_free_for_mounted_devices(self) -> None:
        run = Runner(out=EXTERNAL_SSD)
        asked: list[str] = []

        def usage(path: str) -> tuple[int, int, int]:
            asked.append(path)
            return 500102432768, 200000000000, 300102432768

        document = disks.state(run, usage)
        self.assertEqual(run.calls, [LSBLK])
        self.assertEqual(document["total"], 2)
        self.assertEqual([one["name"] for one in document["devices"]], ["/dev/sdc1", "/dev/sdc2"])
        self.assertEqual((document["devices"][0]["used"], document["devices"][0]["free"]), (200000000000, 300102432768))
        self.assertEqual((document["devices"][1]["used"], document["devices"][1]["free"]), (None, None))
        # Only the mount point of the mounted partition is measured.
        self.assertEqual(asked, ["/run/media/juan/Windows"])

    def test_a_failed_usage_leaves_used_and_free_null(self) -> None:
        run = Runner(out=USB_STICK)

        def usage(_path: str) -> tuple[int, int, int]:
            raise OSError("not readable")

        one = disks.state(run, usage)["devices"][0]
        self.assertTrue(one["mounted"])
        self.assertIsNone(one["used"])
        self.assertIsNone(one["free"])

    def test_a_failing_lsblk_is_an_empty_state(self) -> None:
        document = disks.state(Runner(status=1, err="lsblk: failed"), lambda _path: (0, 0, 0))
        self.assertEqual(document, {"devices": [], "total": 0})

    def test_the_json_shape_is_the_documented_one(self) -> None:
        document = disks.state(Runner(out=USB_STICK), lambda _path: (10, 4, 6))
        self.assertEqual(sorted(document), ["devices", "total"])
        self.assertEqual(
            sorted(document["devices"][0]),
            [
                "free",
                "fstype",
                "label",
                "model",
                "mounted",
                "mountpoint",
                "name",
                "size",
                "transport",
                "used",
                "uuid",
            ],
        )
        self.assertEqual(document["devices"][0]["used"], 4)
        self.assertEqual(document["devices"][0]["free"], 6)


class CommandTests(unittest.TestCase):
    def test_the_three_actions_are_plain_udisksctl_builders(self) -> None:
        self.assertEqual(disks.mount("/dev/sdb1"), ["udisksctl", "mount", "-b", "/dev/sdb1"])
        self.assertEqual(disks.unmount("/dev/sdb1"), ["udisksctl", "unmount", "-b", "/dev/sdb1"])
        self.assertEqual(disks.eject("/dev/sdb1"), ["udisksctl", "power-off", "-b", "/dev/sdb1"])

    def test_open_uses_the_desktops_file_manager(self) -> None:
        self.assertEqual(
            disks.open_command("/run/media/juan/KINGSTON", lambda: ["nautilus", "--new-window"]),
            ["nautilus", "--new-window", "/run/media/juan/KINGSTON"],
        )

    def test_a_successful_action_returns_its_output(self) -> None:
        run = Runner(out="Mounted /dev/sdb1 at /run/media/juan/KINGSTON.\n")
        result = disks.invoke(disks.mount("/dev/sdb1"), run)
        self.assertEqual(
            result, {"ok": True, "output": "Mounted /dev/sdb1 at /run/media/juan/KINGSTON.", "error": None}
        )
        self.assertEqual(run.calls, [["udisksctl", "mount", "-b", "/dev/sdb1"]])

    def test_a_failed_action_surfaces_the_error_text_without_raising(self) -> None:
        error = "Error: GDBus.Error:org.freedesktop.UDisks2.Error.NotAuthorized: Not authorized\n"
        result = disks.invoke(disks.eject("/dev/sdb1"), Runner(status=1, err=error))
        self.assertFalse(result["ok"])
        self.assertEqual(result["error"], error.strip())

    def test_without_error_text_the_status_is_reported(self) -> None:
        result = disks.invoke(disks.unmount("/dev/sdb1"), Runner(status=2))
        self.assertFalse(result["ok"])
        self.assertIn("udisksctl", result["error"])
        self.assertIn("2", result["error"])


class MainTests(unittest.TestCase):
    def main(self, args: list[str], run=None, spawn=None, usage=None) -> tuple[int, str, str]:
        out, err = io.StringIO(), io.StringIO()
        with contextlib.redirect_stdout(out), contextlib.redirect_stderr(err):
            code = disks.main(
                args,
                run=run or Runner(out=USB_STICK),
                usage=usage or (lambda _path: (10, 4, 6)),
                spawn=spawn or (lambda argv: None),
            )
        return code, out.getvalue(), err.getvalue()

    def test_state_prints_one_json_document(self) -> None:
        with mock.patch.object(disks.shutil, "which", return_value="/usr/bin/lsblk"):
            code, out, err = self.main(["state"])
        self.assertEqual((code, err), (0, ""))
        document = json.loads(out)
        self.assertEqual((document["total"], document["devices"][0]["name"]), (1, "/dev/sdb1"))

    def test_mount_runs_udisksctl_and_prints_the_result(self) -> None:
        run = Runner(out="Mounted /dev/sdb1.\n")
        with mock.patch.object(disks.shutil, "which", return_value="/usr/bin/udisksctl"):
            code, out, err = self.main(["mount", "/dev/sdb1"], run=run)
        self.assertEqual((code, err), (0, ""))
        self.assertEqual(json.loads(out)["ok"], True)
        self.assertEqual(run.calls, [["udisksctl", "mount", "-b", "/dev/sdb1"]])

    def test_a_refused_action_exits_non_zero_with_the_error_in_json(self) -> None:
        run = Runner(status=1, err="Error: not authorized\n")
        with mock.patch.object(disks.shutil, "which", return_value="/usr/bin/udisksctl"):
            code, out, _err = self.main(["eject", "/dev/sdb1"], run=run)
        self.assertEqual(code, 1)
        self.assertEqual(json.loads(out)["error"], "Error: not authorized")

    def test_open_runs_the_file_manager_on_the_mount_point(self) -> None:
        ran: list[list[str]] = []
        with mock.patch.object(disks, "open_command", return_value=["nautilus", "/run/media/x"]):
            code, out, err = self.main(["open", "/run/media/x"], spawn=ran.append)
        self.assertEqual((code, out, err), (0, "", ""))
        self.assertEqual(ran, [["nautilus", "/run/media/x"]])

    def test_without_lsblk_one_clear_line_and_a_non_zero_exit(self) -> None:
        with mock.patch.object(disks.shutil, "which", return_value=None):
            code, out, err = self.main(["state"])
        self.assertEqual((code, out), (1, ""))
        self.assertIn("lsblk", err)
        self.assertIn("util-linux", err)
        self.assertEqual(len(err.strip().splitlines()), 1)
        self.assertNotIn("Traceback", err)

    def test_without_udisksctl_one_clear_line_and_a_non_zero_exit(self) -> None:
        with mock.patch.object(disks.shutil, "which", return_value=None):
            code, out, err = self.main(["mount", "/dev/sdb1"])
        self.assertEqual((code, out), (1, ""))
        self.assertIn("udisksctl", err)
        self.assertIn("udisks2", err)
        self.assertEqual(len(err.strip().splitlines()), 1)
        self.assertNotIn("Traceback", err)

    def test_an_unknown_command_prints_the_usage(self) -> None:
        code, out, err = self.main(["what"])
        self.assertEqual((code, out), (2, ""))
        self.assertIn("usage: disks", err)


if __name__ == "__main__":
    unittest.main()
