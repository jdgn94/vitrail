"""The privacy snapshot: who captures the microphone, the camera or the screen.

The graphs are `pw-dump` documents written in PipeWire's own shape (nodes,
clients and links), so the tests never need PipeWire or a device.
"""

from __future__ import annotations

import json
import unittest
from contextlib import redirect_stderr, redirect_stdout
from io import StringIO
from unittest import mock

from vitrail import privacy


def node(ident: int, media_class: str, name: str, app: str | None = None, state: str = "running", **props) -> dict:
    merged = {"media.class": media_class, "node.name": name, **props}
    if app is not None:
        merged["application.name"] = app
    return {"id": ident, "type": "PipeWire:Interface:Node", "info": {"state": state, "props": merged}}


def link(ident: int, out: int, into: int) -> dict:
    return {
        "id": ident,
        "type": "PipeWire:Interface:Link",
        "info": {"output-node-id": out, "input-node-id": into},
    }


def client(ident: int, binary: str) -> dict:
    return {
        "id": ident,
        "type": "PipeWire:Interface:Client",
        "info": {"props": {"application.process.binary": binary}},
    }


MIC = node(40, "Audio/Source", "alsa_input.pci.analog-stereo", state="running")
SINK = node(41, "Audio/Sink", "alsa_output.pci.analog-stereo")
CAMERA = node(50, "Video/Source", "v4l2_input.usb-cam", state="idle")

# (a) nothing in use: devices and a playing app, no capture stream.
NOTHING = [MIC, SINK, node(60, "Stream/Output/Audio", "firefox", "Firefox"), link(1, 60, 41)]
# (b) one application on the microphone.
ONE_MIC = [MIC, SINK, node(61, "Stream/Input/Audio", "Firefox input", "Firefox"), link(2, 40, 61)]
# (c) two applications on the microphone and a camera.
MIC_AND_CAMERA = [
    MIC,
    SINK,
    CAMERA,
    node(62, "Stream/Input/Audio", "discord capture", "Discord"),
    node(61, "Stream/Input/Audio", "Firefox input", "Firefox"),
    node(70, "Stream/Input/Video", "Firefox camera", "Firefox"),
    link(2, 40, 61),
    link(3, 40, 62),
    link(4, 50, 70),
]
# (d) a camera that is present and linked to nothing.
UNUSED_CAMERA = [CAMERA, MIC, SINK]
# (e) a portal screencast: the portal's stream, consumed by OBS.
PORTAL = [
    client(7, "xdg-desktop-portal-hyprland"),
    node(80, "Stream/Output/Video", "xdph-streaming", None, **{"client.id": 7}),
    node(81, "Stream/Input/Video", "OBS capture", "OBS Studio"),
    link(5, 80, 81),
]
# (f) a malformed graph: no media.class, no props, odd entries.
MALFORMED = [
    {"id": 90, "type": "PipeWire:Interface:Node", "info": {"props": {"node.name": "mystery"}}},
    {"id": 91, "type": "PipeWire:Interface:Node"},
    {"id": "x", "type": "PipeWire:Interface:Node", "info": {"props": {"media.class": "Stream/Input/Audio"}}},
    {"type": "PipeWire:Interface:Link", "info": {"output-node-id": 1}},
    "junk",
    None,
]


def kinds(uses: list[dict]) -> list[tuple[str, str]]:
    return [(use["kind"], use["app"]) for use in uses]


def snapshot(graph: object, **kwargs) -> dict:
    return privacy.state(json.dumps(graph), **kwargs)


class Uses(unittest.TestCase):
    def test_nothing_in_use(self) -> None:
        result = snapshot(NOTHING)
        self.assertEqual(result["uses"], [])
        self.assertFalse(result["anyUse"])
        self.assertIsNone(result["error"])

    def test_one_app_on_the_microphone(self) -> None:
        result = snapshot(ONE_MIC)
        self.assertEqual(
            result["uses"],
            [{"kind": "microphone", "app": "Firefox", "label": "Firefox input", "node": 61, "since": None}],
        )
        self.assertTrue(result["anyUse"])

    def test_two_apps_and_a_camera(self) -> None:
        result = snapshot(MIC_AND_CAMERA)
        self.assertEqual(
            kinds(result["uses"]),
            [("microphone", "Discord"), ("microphone", "Firefox"), ("camera", "Firefox")],
        )
        self.assertTrue(result["anyUse"])

    def test_a_camera_that_is_only_present_is_not_reported(self) -> None:
        result = snapshot(UNUSED_CAMERA)
        self.assertEqual(result["uses"], [])
        self.assertFalse(result["anyUse"])

    def test_portal_screencast_is_a_screen_not_a_camera(self) -> None:
        result = snapshot(PORTAL)
        self.assertEqual(kinds(result["uses"]), [("screen", "OBS Studio")])
        self.assertEqual(result["uses"][0]["node"], 81)

    def test_portal_stream_without_a_consumer_is_not_reported(self) -> None:
        self.assertEqual(snapshot(PORTAL[:2])["uses"], [])

    def test_a_stream_named_like_the_portal_without_its_client_is_a_camera(self) -> None:
        graph = [PORTAL[1], PORTAL[2], PORTAL[3]]  # the client object is missing
        graph[0] = node(80, "Stream/Output/Video", "xdph-streaming", None)
        self.assertEqual(kinds(snapshot(graph)["uses"]), [("camera", "OBS Studio")])

    def test_portal_found_by_the_nodes_own_binary(self) -> None:
        stream = node(80, "Video/Source", "cast", None, **{"application.process.binary": "xdg-desktop-portal-gtk"})
        graph = [stream, PORTAL[2], PORTAL[3]]
        self.assertEqual(kinds(snapshot(graph)["uses"]), [("screen", "OBS Studio")])

    def test_malformed_nodes_are_ignored(self) -> None:
        result = snapshot(MALFORMED)
        self.assertEqual(result["uses"], [])
        self.assertIsNone(result["error"])

    def test_app_falls_back_to_the_binary_then_the_node_name(self) -> None:
        binary = node(61, "Stream/Input/Audio", "raw", None, **{"application.process.binary": "arecord"})
        bare = node(62, "Stream/Input/Audio", "only-a-name", None)
        uses = snapshot([binary, bare])["uses"]
        self.assertEqual([use["app"] for use in uses], ["arecord", "only-a-name"])
        self.assertEqual(uses[0]["label"], "raw")

    def test_label_is_the_node_id_without_a_name(self) -> None:
        bare = {"id": 9, "type": "PipeWire:Interface:Node", "info": {"props": {"media.class": "Stream/Input/Audio"}}}
        self.assertEqual(snapshot([bare])["uses"][0]["label"], "9")


class Exclusions(unittest.TestCase):
    def test_a_sink_monitor_is_not_a_microphone(self) -> None:
        graph = [SINK, node(61, "Stream/Input/Audio", "cava", "cava"), link(1, 41, 61)]
        self.assertEqual(snapshot(graph)["uses"], [])

    def test_the_capture_sink_flag_is_a_monitor_too(self) -> None:
        graph = [node(61, "Stream/Input/Audio", "rec", "Recorder", **{"stream.capture.sink": "true"})]
        self.assertEqual(snapshot(graph)["uses"], [])

    def test_readers_of_the_graph_are_not_users(self) -> None:
        graph = [
            node(61, "Stream/Input/Audio", "a", "pw-dump"),
            node(62, "Stream/Input/Audio", "b", "wpctl"),
            node(63, "Stream/Input/Audio", "c", "quickshell"),
            node(64, "Stream/Input/Audio", "d", "Volume Control", **{"media.name": "Peak detect"}),
        ]
        self.assertEqual(snapshot(graph)["uses"], [])

    def test_idle_streams_are_not_in_use(self) -> None:
        graph = [node(61, "Stream/Input/Audio", "paused", "Firefox", state="idle")]
        self.assertEqual(snapshot(graph)["uses"], [])

    def test_a_stream_without_state_counts(self) -> None:
        stream = node(61, "Stream/Input/Audio", "x", "Firefox")
        del stream["info"]["state"]
        self.assertEqual(len(snapshot([stream])["uses"]), 1)


class Shape(unittest.TestCase):
    def test_json_shape(self) -> None:
        result = snapshot(ONE_MIC)
        self.assertEqual(set(result), {"uses", "anyUse", "watching", "error"})
        self.assertEqual(result["watching"], {"microphone": True, "camera": True, "screen": True})
        self.assertEqual(json.loads(json.dumps(result)), result)

    def test_watching_narrows_the_uses_and_any_use(self) -> None:
        result = snapshot(MIC_AND_CAMERA, watch=["camera"])
        self.assertEqual(kinds(result["uses"]), [("camera", "Firefox")])
        self.assertEqual(result["watching"], {"microphone": False, "camera": True, "screen": False})
        self.assertFalse(snapshot(ONE_MIC, watch=["camera"])["anyUse"])

    def test_the_runner_gets_pw_dump(self) -> None:
        seen: list[list[str]] = []

        def runner(argv: list[str]) -> str:
            seen.append(argv)
            return json.dumps(ONE_MIC)

        self.assertTrue(privacy.state(runner=runner)["anyUse"])
        self.assertEqual(seen, [["pw-dump"]])


class Failures(unittest.TestCase):
    def test_missing_program_is_an_answer(self) -> None:
        result = privacy.state(runner=lambda argv: None)
        self.assertEqual(result["uses"], [])
        self.assertFalse(result["anyUse"])
        self.assertIn("pw-dump", result["error"])

    def test_run_text_reports_a_missing_program_as_none(self) -> None:
        with mock.patch("vitrail.privacy.shutil.which", return_value=None):
            self.assertIsNone(privacy.run_text(["pw-dump"]))

    def test_bad_output_is_an_error_not_a_crash(self) -> None:
        for text in ("not json", "{}", ""):
            with self.subTest(text=text):
                result = privacy.state(text)
                self.assertFalse(result["anyUse"])
                self.assertTrue(result["error"])

    def test_cli_exits_zero_without_pipewire(self) -> None:
        out = StringIO()
        with (
            mock.patch("vitrail.privacy.shutil.which", return_value=None),
            redirect_stdout(out),
        ):
            self.assertEqual(privacy.main(["state"]), 0)
        self.assertFalse(json.loads(out.getvalue())["anyUse"])

    def test_cli_rejects_unknown_arguments(self) -> None:
        with redirect_stderr(StringIO()):
            self.assertEqual(privacy.main(["state", "radar"]), 2)
            self.assertEqual(privacy.main([]), 2)


class Stop(unittest.TestCase):
    def test_every_kind_destroys_the_stream_node(self) -> None:
        for kind in privacy.KINDS:
            with self.subTest(kind=kind):
                self.assertEqual(privacy.stop(kind, 61), ["pw-cli", "destroy", "61"])

    def test_invalid_input_builds_nothing(self) -> None:
        for kind, node_id in (
            ("radar", 1),
            ("microphone", "61"),
            ("microphone", True),
            ("camera", -1),
            ("screen", None),
        ):
            with self.subTest(kind=kind, node=node_id):
                self.assertIsNone(privacy.stop(kind, node_id))

    def test_building_the_command_runs_nothing(self) -> None:
        with mock.patch("vitrail.privacy.subprocess.run") as run:
            privacy.stop("microphone", 61)
        run.assert_not_called()


if __name__ == "__main__":
    unittest.main()
