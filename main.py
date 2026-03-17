from __future__ import annotations

import sys
from pathlib import Path

PROJECT_ROOT = Path(__file__).resolve().parent

if str(PROJECT_ROOT) not in sys.path:
    sys.path.insert(0, str(PROJECT_ROOT))

from src.abstrakcyjna_symulacja_kaskady_sieciowej.cli import main as cli_main

KNOWN_COMMANDS = {"simulate", "morris", "sobol", "bifurcation"}


def _normalize_argv(argv: list[str]) -> list[str]:
    if not argv:
        return ["sobol"]

    if any(arg in KNOWN_COMMANDS for arg in argv):
        return argv

    global_opts: list[str] = []
    rest: list[str] = []

    i = 0
    while i < len(argv):
        arg = argv[i]
        if arg == "--config":
            global_opts.append(arg)
            if i + 1 < len(argv):
                global_opts.append(argv[i + 1])
                i += 2
                continue
        rest.append(arg)
        i += 1

    return [*global_opts, "sobol", *rest]


if __name__ == "__main__":
    raise SystemExit(cli_main(_normalize_argv(sys.argv[1:])))