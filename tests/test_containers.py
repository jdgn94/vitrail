"""Containers: the docker or podman snapshot the bar and its popup read.

No docker, no podman, no daemon: every engine answer is injected.
"""

from __future__ import annotations

import contextlib
import io
import json
import unittest
from unittest import mock

from vitrail import containers

DOCKER = (
    '{"ID":"a1b2","Names":"web","Image":"nginx:latest","State":"running",'
    '"Status":"Up 2 hours (healthy)","Ports":"0.0.0.0:8080->80/tcp, :::8080->80/tcp"}\n'
    '{"ID":"c3d4","Names":"db","Image":"postgres:16","State":"exited",'
    '"Status":"Exited (0) 2 hours ago","Ports":""}\n'
    '{"ID":"e5f6","Names":"job","Image":"alpine:3.20","State":"running",'
    '"Status":"Up 5 seconds","Ports":""}\n'
)
PODMAN = (
    '{"Id":"p1","Names":["api"],"Image":"docker.io/x/api","State":"running","Status":"Up 3 minutes",'
    '"Ports":[{"host_ip":"0.0.0.0","host_port":3000,"container_port":3000,"protocol":"tcp"}],'
    '"Health":"healthy"}\n'
    '{"Id":"p2","Names":["worker"],"Image":"x/worker","State":"exited",'
    '"Status":"Exited (1) 1 minute ago","Ports":[]}\n'
)


def runner(outputs: dict[str, str | None]):
    """A runner that answers by the command's first two words."""

    def run(argv: list[str]) -> str | None:
        return outputs.get(" ".join(argv[:2]))

    return run


def both(docker: str | None = DOCKER, podman: str | None = PODMAN):
    return runner(
        {"docker --version": "Docker 27.0", "docker ps": docker, "podman --version": "podman 5.0", "podman ps": podman}
    )


class EngineTests(unittest.TestCase):
    def test_docker_comes_first(self) -> None:
        self.assertEqual(containers.engine(both()), "docker")

    def test_without_docker_podman_is_used(self) -> None:
        run = runner({"podman --version": "podman 5.0"})
        self.assertEqual(containers.engine(run), "podman")

    def test_neither_engine_is_none(self) -> None:
        self.assertIsNone(containers.engine(runner({})))

    def test_an_engine_that_cannot_answer_is_absent(self) -> None:
        run = runner({"docker --version": None, "podman --version": "podman 5.0"})
        self.assertEqual(containers.engine(run), "podman")

    def test_the_option_picks_the_engine(self) -> None:
        self.assertEqual(containers.engine(both(), "podman"), "podman")
        self.assertEqual(containers.engine(runner({"podman --version": "5.0"}), "docker"), None)

    def test_available_says_whether_the_element_has_anything_to_show(self) -> None:
        self.assertTrue(containers.available(both()))
        self.assertFalse(containers.available(runner({})))


class ParseTests(unittest.TestCase):
    def test_docker_json_lines(self) -> None:
        found = containers.parse_ps(DOCKER)
        self.assertEqual([one["id"] for one in found], ["a1b2", "c3d4", "e5f6"])
        self.assertEqual(found[0]["name"], "web")
        self.assertEqual(found[0]["image"], "nginx:latest")
        self.assertEqual(found[0]["state"], "running")
        self.assertEqual(found[0]["status"], "Up 2 hours (healthy)")
        self.assertEqual(found[0]["health"], "healthy")
        self.assertEqual(found[0]["ports"], "0.0.0.0:8080->80/tcp, :::8080->80/tcp")
        self.assertEqual(found[1]["health"], None)
        self.assertEqual(found[2]["health"], None)
        self.assertEqual(found[2]["ports"], "")

    def test_podman_json_lines(self) -> None:
        found = containers.parse_ps(PODMAN)
        self.assertEqual([one["id"] for one in found], ["p1", "p2"])
        self.assertEqual(found[0]["name"], "api")
        self.assertEqual(found[0]["health"], "healthy")
        self.assertEqual(found[0]["ports"], "0.0.0.0:3000->3000/tcp")
        self.assertEqual(found[1]["health"], None)
        self.assertEqual(found[1]["ports"], "")

    def test_older_engines_emit_an_array(self) -> None:
        found = containers.parse_ps(json.dumps([json.loads(line) for line in DOCKER.splitlines()]))
        self.assertEqual([one["id"] for one in found], ["a1b2", "c3d4", "e5f6"])

    def test_empty_output_is_no_containers(self) -> None:
        self.assertEqual(containers.parse_ps(""), [])
        self.assertEqual(containers.parse_ps("\n"), [])

    def test_noise_is_skipped(self) -> None:
        found = containers.parse_ps('not json\n{"ID":"a1","Names":"web","State":"running"}\n[1]\n')
        self.assertEqual([one["id"] for one in found], ["a1"])


class StateTests(unittest.TestCase):
    def test_the_snapshot_counts_running_containers(self) -> None:
        found = containers.state(both())
        self.assertEqual(found["engine"], "docker")
        self.assertEqual(found["running"], 2)
        self.assertEqual([one["name"] for one in found["containers"]], ["web", "db", "job"])
        self.assertIsNone(found["error"])

    def test_podman_counts_its_own(self) -> None:
        found = containers.state(runner({"podman --version": "5.0", "podman ps": PODMAN}))
        self.assertEqual(found["engine"], "podman")
        self.assertEqual(found["running"], 1)

    def test_neither_engine_is_an_ordinary_empty_state(self) -> None:
        self.assertEqual(
            containers.state(runner({})),
            {"engine": None, "running": 0, "containers": [], "error": None},
        )

    def test_a_failed_listing_is_reported_without_containers(self) -> None:
        found = containers.state(runner({"docker --version": "27.0", "docker ps": None}))
        self.assertEqual(found["engine"], "docker")
        self.assertEqual(found["containers"], [])
        self.assertEqual(found["running"], 0)
        self.assertIn("docker", found["error"])

    def test_the_json_shape_is_stable(self) -> None:
        found = json.loads(json.dumps(containers.state(both()), separators=(",", ":")))
        self.assertEqual(set(found), {"engine", "running", "containers", "error"})
        self.assertEqual(set(found["containers"][0]), {"id", "name", "image", "state", "status", "health", "ports"})


class MainTests(unittest.TestCase):
    def run_main(self, args: list[str]) -> tuple[int, str, mock.MagicMock]:
        output = io.StringIO()
        answer = {"engine": "podman", "running": 0, "containers": [], "error": None}
        with mock.patch("vitrail.containers.state", return_value=answer) as state, contextlib.redirect_stdout(output):
            code = containers.main(args)
        return code, output.getvalue(), state

    def test_state_takes_the_engine_option(self) -> None:
        code, out, state = self.run_main(["state", "--engine", "podman"])
        self.assertEqual(code, 0)
        self.assertEqual(json.loads(out)["engine"], "podman")
        state.assert_called_once_with(option="podman")

    def test_auto_asks_for_no_engine(self) -> None:
        code, _, state = self.run_main(["state", "--engine", "auto"])
        self.assertEqual(code, 0)
        state.assert_called_once_with(option=None)

    def test_an_unknown_engine_is_usage(self) -> None:
        for args in (["state", "--engine", "lxc"], ["state", "--engine"], ["state", "extra"]):
            with self.subTest(args=args):
                code, out, state = self.run_main(args)
                self.assertEqual((code, out), (2, ""))
                state.assert_not_called()


class ActionTests(unittest.TestCase):
    def test_start_and_stop_name_the_engine_and_the_container(self) -> None:
        self.assertEqual(containers.start("docker", "a1b2"), ["docker", "start", "a1b2"])
        self.assertEqual(containers.stop("podman", "p1"), ["podman", "stop", "p1"])

    def test_logs_asks_for_the_last_two_hundred_lines(self) -> None:
        self.assertEqual(containers.logs("docker", "a1b2"), ["docker", "logs", "--tail", "200", "a1b2"])
        self.assertEqual(containers.logs("podman", "p1"), ["podman", "logs", "--tail", "200", "p1"])


if __name__ == "__main__":
    unittest.main()
