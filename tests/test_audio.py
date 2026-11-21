"""Audio: PipeWire's graph as one snapshot, and the actions that change it."""

from __future__ import annotations

import contextlib
import io
import json
import unittest

from vitrail import audio

ANALOG = "alsa_output.pci-0000_0d_00.6.analog-stereo"
USB_SINK = "alsa_output.usb-HyperX.analog-stereo"
ANALOG_IN = "alsa_input.pci-0000_0d_00.6.analog-stereo"
USB_IN = "alsa_input.usb-HyperX.analog-stereo"


def node(
    node_id: int,
    serial: int,
    media_class: str,
    name: str,
    description: str,
    volumes: list[float],
    mute: bool = False,
    **props: object,
) -> dict:
    """One `PipeWire:Interface:Node` as `pw-dump` prints it, minus what we ignore."""
    return {
        "id": node_id,
        "type": "PipeWire:Interface:Node",
        "info": {
            "state": "suspended",
            "props": {
                "media.class": media_class,
                "node.name": name,
                "node.description": description,
                "object.serial": serial,
                **props,
            },
            "params": {"Props": [{"volume": 1.0, "mute": mute, "channelVolumes": volumes}]},
        },
    }


def link(link_id: int, output: int, sink: int) -> dict:
    """One `PipeWire:Interface:Link` from a stream's output to a sink's input."""
    return {
        "id": link_id,
        "type": "PipeWire:Interface:Link",
        "info": {
            "output-node-id": output,
            "input-node-id": sink,
            "props": {"link.output.node": output, "link.input.node": sink},
        },
    }


DUMP = [
    node(34, 58, "Audio/Sink", ANALOG, "Ryzen HD Audio Controller Analog Stereo", [0.125, 0.125]),
    node(
        45, 60, "Audio/Sink", USB_SINK, "HyperX Virtual Surround Sound Analog Stereo", [0.015625, 0.015625], mute=True
    ),
    node(46, 59, "Audio/Source", ANALOG_IN, "Ryzen HD Audio Controller Analog Stereo", [1.0, 1.0]),
    node(44, 61, "Audio/Source", USB_IN, "HyperX Virtual Surround Sound Analog Stereo", [1.0, 1.0]),
    node(
        79,
        299,
        "Stream/Output/Audio",
        "spotify",
        "Spotify",
        [1.0, 1.0],
        **{"application.name": "Spotify", "media.name": "Spotify", "pulse.corked": True},
    ),
    node(
        83,
        407,
        "Stream/Output/Audio",
        "Firefox",
        "Firefox",
        [0.512, 0.512],
        **{
            "application.name": "Firefox",
            "application.process.binary": "firefox",
            "application.icon-name": "firefox",
            "media.name": "09-ATaleoftheSecretSaint",
        },
    ),
    node(
        90,
        450,
        "Stream/Output/Audio",
        "orphan",
        "Orphan",
        [1.0, 1.0],
        **{"application.name": "Orphan", "media.name": "Nothing"},
    ),
    node(
        91,
        451,
        "Stream/Input/Audio",
        "capture",
        "Capture",
        [1.0, 1.0],
        **{"application.name": "Recorder", "media.name": "Microphone"},
    ),
    link(80, 79, 34),
    link(81, 79, 34),
    link(88, 83, 34),
    link(89, 90, 999),
    {
        "id": 40,
        "type": "PipeWire:Interface:Metadata",
        "props": {"metadata.name": "default"},
        "metadata": [
            {"key": "default.configured.audio.sink", "value": {"name": USB_SINK}},
            {"key": "default.audio.sink", "value": {"name": ANALOG}},
            {"key": "default.audio.source", "value": {"name": USB_IN}},
        ],
    },
    {
        "id": 41,
        "type": "PipeWire:Interface:Metadata",
        "props": {"metadata.name": "settings"},
        "metadata": [{"key": "clock.rate", "value": 48000}],
    },
]

DUMP_TEXT = json.dumps(DUMP)


class Recorder:
    """A fake runner: records the command and answers with a canned stdout."""

    def __init__(self, answer: str | None = "") -> None:
        self.answer = answer
        self.calls: list[list[str]] = []

    def __call__(self, cmd: list[str]) -> str | None:
        self.calls.append(cmd)
        return self.answer


class WpctlTextTests(unittest.TestCase):
    def test_a_default_volume_is_a_percentage(self) -> None:
        self.assertEqual(audio.parse_get_volume("Volume: 0.50\n"), {"volume": 50, "muted": False})
        self.assertEqual(audio.parse_get_volume("Volume: 1.00\n"), {"volume": 100, "muted": False})

    def test_the_muted_suffix_sets_the_flag(self) -> None:
        self.assertEqual(audio.parse_get_volume("Volume: 0.50 [MUTED]\n"), {"volume": 50, "muted": True})
        self.assertEqual(audio.parse_get_volume("Volume: 0.07 [muted]\n"), {"volume": 7, "muted": True})

    def test_an_unknown_reading_has_no_volume(self) -> None:
        self.assertEqual(audio.parse_get_volume(""), {"volume": None, "muted": False})
        self.assertEqual(audio.parse_get_volume("no sink\n"), {"volume": None, "muted": False})


class LevelTests(unittest.TestCase):
    def test_pipewires_cubic_level_reads_like_the_osd(self) -> None:
        self.assertEqual(audio.level_percent(0.125), 50)
        self.assertEqual(audio.level_percent(0.015625), 25)
        self.assertEqual(audio.level_percent(0.512), 80)
        self.assertEqual(audio.level_percent(1.0), 100)
        self.assertEqual(audio.level_percent(0.0), 0)

    def test_a_level_above_full_is_clamped(self) -> None:
        self.assertEqual(audio.level_percent(8.0), 100)

    def test_percentages_stay_on_the_scale(self) -> None:
        self.assertEqual(audio.clamp_percent(150), 100)
        self.assertEqual(audio.clamp_percent(-5), 0)
        self.assertEqual(audio.clamp_percent(49.5), 50)


class SnapshotTests(unittest.TestCase):
    def setUp(self) -> None:
        self.data = audio.parse_dump(DUMP_TEXT)
        self.sinks = {entry["name"]: entry for entry in self.data["sinks"]}
        self.sources = {entry["name"]: entry for entry in self.data["sources"]}
        self.streams = {entry["app"]: entry for entry in self.data["streams"]}

    def test_the_default_sink_and_source_are_metadata(self) -> None:
        self.assertEqual(self.data["defaultSink"], self.sinks[ANALOG])
        self.assertEqual(self.data["defaultSource"], self.sources[USB_IN])
        self.assertEqual(self.data["defaultSink"]["id"], 34)
        self.assertEqual(self.data["defaultSink"]["volume"], 50)

    def test_every_sink_and_source_has_the_same_fields(self) -> None:
        self.assertEqual(
            self.data["sinks"],
            [
                {
                    "id": 34,
                    "serial": 58,
                    "name": ANALOG,
                    "description": "Ryzen HD Audio Controller Analog Stereo",
                    "volume": 50,
                    "muted": False,
                },
                {
                    "id": 45,
                    "serial": 60,
                    "name": USB_SINK,
                    "description": "HyperX Virtual Surround Sound Analog Stereo",
                    "volume": 25,
                    "muted": True,
                },
            ],
        )
        self.assertEqual([entry["name"] for entry in self.data["sources"]], [ANALOG_IN, USB_IN])
        self.assertEqual(self.data["sources"][0]["volume"], 100)

    def test_a_stream_carries_its_app_track_icon_and_state(self) -> None:
        self.assertEqual(
            self.streams["Spotify"],
            {
                "id": 79,
                "serial": 299,
                "app": "Spotify",
                "name": "Spotify",
                "icon": "",
                "volume": 100,
                "muted": False,
                "corked": True,
                "sink": 34,
            },
        )
        self.assertEqual(self.streams["Firefox"]["icon"], "firefox")
        self.assertEqual(self.streams["Firefox"]["volume"], 80)
        self.assertEqual(self.streams["Firefox"]["name"], "09-ATaleoftheSecretSaint")

    def test_streams_group_their_links_onto_one_sink(self) -> None:
        self.assertEqual([entry["id"] for entry in self.data["streams"]], [79, 83, 90])
        self.assertEqual(self.streams["Spotify"]["sink"], 34)
        self.assertIsNone(self.streams["Orphan"]["sink"])

    def test_capture_streams_are_not_playback_streams(self) -> None:
        self.assertNotIn("Recorder", self.streams)
        self.assertEqual(len(self.data["streams"]), 3)

    def test_a_dump_without_metadata_has_no_defaults(self) -> None:
        objects = [entry for entry in DUMP if entry["type"] != "PipeWire:Interface:Metadata"]
        data = audio.parse_dump(json.dumps(objects))
        self.assertIsNone(data["defaultSink"])
        self.assertIsNone(data["defaultSource"])

    def test_the_configured_sink_is_the_fallback(self) -> None:
        metadata = next(entry for entry in DUMP if entry.get("id") == 40)
        only_configured = [entry for entry in DUMP if entry is not metadata] + [
            {
                "id": 40,
                "type": "PipeWire:Interface:Metadata",
                "props": {"metadata.name": "default"},
                "metadata": [{"key": "default.configured.audio.sink", "value": {"name": USB_SINK}}],
            }
        ]
        data = audio.parse_dump(json.dumps(only_configured))
        self.assertEqual(data["defaultSink"]["name"], USB_SINK)

    def test_a_metadata_value_stored_as_json_still_names_the_node(self) -> None:
        text = DUMP_TEXT.replace(json.dumps({"name": ANALOG}), json.dumps(json.dumps({"name": ANALOG})))
        self.assertEqual(audio.parse_dump(text)["defaultSink"]["name"], ANALOG)

    def test_the_document_has_exactly_the_documented_shape(self) -> None:
        self.assertEqual(set(self.data), {"defaultSink", "defaultSource", "sinks", "sources", "streams", "error"})
        self.assertIsNone(self.data["error"])
        json.dumps(self.data)


class ActionTests(unittest.TestCase):
    def test_an_absolute_volume_is_clamped_and_sent_as_a_percentage(self) -> None:
        run = Recorder()
        self.assertTrue(audio.set_volume(150, target="34", run=run)["ok"])
        audio.set_volume(-4, run=run)
        audio.set_volume(65, run=run)
        self.assertEqual(
            run.calls,
            [
                ["wpctl", "set-volume", "--limit", "1.0", "34", "100%"],
                ["wpctl", "set-volume", "--limit", "1.0", audio.DEFAULT_SINK, "0%"],
                ["wpctl", "set-volume", "--limit", "1.0", audio.DEFAULT_SINK, "65%"],
            ],
        )

    def test_a_delta_keeps_its_direction(self) -> None:
        run = Recorder()
        audio.set_volume(10, delta=True, run=run)
        audio.set_volume(-10, delta=True, run=run)
        audio.set_volume(-150, delta=True, run=run)
        self.assertEqual([call[-1] for call in run.calls], ["10%+", "10%-", "100%-"])

    def test_mute_toggles_the_default_sink_source_or_an_id(self) -> None:
        run = Recorder()
        audio.toggle_mute(run=run)
        audio.toggle_mute(target=audio.DEFAULT_SOURCE, run=run)
        audio.toggle_mute(target=45, run=run)
        self.assertEqual(
            run.calls,
            [
                ["wpctl", "set-mute", audio.DEFAULT_SINK, "toggle"],
                ["wpctl", "set-mute", audio.DEFAULT_SOURCE, "toggle"],
                ["wpctl", "set-mute", "45", "toggle"],
            ],
        )

    def test_a_stream_moves_with_pactl(self) -> None:
        run = Recorder()
        result = audio.move_stream(299, USB_SINK, run=run)
        self.assertTrue(result["ok"])
        self.assertEqual(run.calls, [["pactl", "move-sink-input", "299", USB_SINK]])

    def test_an_action_whose_program_is_missing_is_unsupported(self) -> None:
        missing = Recorder(None)
        actions = [
            (audio.set_volume(50, run=missing), "wpctl"),
            (audio.toggle_mute(run=missing), "wpctl"),
            (audio.move_stream(299, USB_SINK, run=missing), "pactl"),
        ]
        for result, program in actions:
            with self.subTest(program=program):
                self.assertFalse(result["ok"])
                self.assertIn("unsupported", result["error"])
                self.assertIn(program, result["error"])


class StateTests(unittest.TestCase):
    def test_the_snapshot_comes_from_pw_dump(self) -> None:
        run = Recorder(DUMP_TEXT)
        data = audio.state(run)
        self.assertEqual(run.calls, [["pw-dump"]])
        self.assertEqual(data["defaultSink"]["name"], ANALOG)
        self.assertIsNone(data["error"])

    def test_a_missing_pw_dump_is_one_clear_error_with_the_empty_shape(self) -> None:
        data = audio.state(Recorder(None))
        self.assertIn("pw-dump", data["error"])
        self.assertEqual((data["defaultSink"], data["sinks"], data["streams"]), (None, [], []))

    def test_a_dump_that_is_not_json_is_an_error_not_a_traceback(self) -> None:
        data = audio.state(Recorder("not json"))
        self.assertIn("JSON", data["error"])
        self.assertEqual(data["sources"], [])


class MainTests(unittest.TestCase):
    def test_state_prints_the_json(self) -> None:
        out = io.StringIO()
        with contextlib.redirect_stdout(out):
            self.assertEqual(audio.main(["state"], run=Recorder(DUMP_TEXT)), 0)
        self.assertEqual(json.loads(out.getvalue())["defaultSink"]["name"], ANALOG)

    def test_a_missing_program_exits_non_zero_with_one_line_on_stderr(self) -> None:
        out, errors = io.StringIO(), io.StringIO()
        with contextlib.redirect_stdout(out), contextlib.redirect_stderr(errors):
            self.assertEqual(audio.main(["state"], run=Recorder(None)), 1)
        self.assertEqual(out.getvalue(), "")
        lines = errors.getvalue().strip().splitlines()
        self.assertEqual(len(lines), 1)
        self.assertIn("pw-dump", lines[0])

    def test_an_unknown_action_prints_the_usage(self) -> None:
        errors = io.StringIO()
        with contextlib.redirect_stderr(errors):
            self.assertEqual(audio.main(["now"], run=Recorder(DUMP_TEXT)), 2)
        self.assertIn("usage: audio state", errors.getvalue())

    def run_action(self, args: list[str], run: Recorder) -> tuple[int, dict | None]:
        out = io.StringIO()
        with contextlib.redirect_stdout(out), contextlib.redirect_stderr(io.StringIO()):
            code = audio.main(args, run=run)
        return code, json.loads(out.getvalue()) if out.getvalue() else None

    def test_a_volume_step_is_one_wpctl_call(self) -> None:
        run = Recorder("")
        code, result = self.run_action(["volume", "sink", "-5"], run)
        self.assertEqual(code, 0)
        self.assertEqual(run.calls, [["wpctl", "set-volume", "--limit", "1.0", "@DEFAULT_AUDIO_SINK@", "5%-"]])
        self.assertTrue(result["ok"])

    def test_an_absolute_volume_goes_to_a_node_id(self) -> None:
        run = Recorder("")
        self.assertEqual(self.run_action(["volume", "57", "40"], run)[0], 0)
        self.assertEqual(run.calls, [["wpctl", "set-volume", "--limit", "1.0", "57", "40%"]])

    def test_mute_and_default_and_move(self) -> None:
        run = Recorder("")
        self.assertEqual(self.run_action(["mute", "source"], run)[0], 0)
        self.assertEqual(self.run_action(["default", "52"], run)[0], 0)
        self.assertEqual(self.run_action(["move", "91", USB_SINK], run)[0], 0)
        self.assertEqual(
            run.calls,
            [
                ["wpctl", "set-mute", "@DEFAULT_AUDIO_SOURCE@", "toggle"],
                ["wpctl", "set-default", "52"],
                ["pactl", "move-sink-input", "91", USB_SINK],
            ],
        )

    def test_an_action_that_cannot_run_exits_one_and_says_why(self) -> None:
        code, result = self.run_action(["default", "52"], Recorder(None))
        self.assertEqual(code, 1)
        self.assertFalse(result["ok"])
        self.assertIn("wpctl", result["error"])

    def test_a_bad_target_or_value_runs_nothing(self) -> None:
        run = Recorder("")
        for args in (
            ["volume", "sink; reboot", "5"],
            ["volume", "sink", "loud"],
            ["mute", "everything"],
            ["default", "sink"],
            ["move", "x", USB_SINK],
            ["volume", "sink"],
        ):
            with self.subTest(args=args):
                self.assertEqual(self.run_action(args, run)[0], 2)
        self.assertEqual(run.calls, [])


if __name__ == "__main__":
    unittest.main()
