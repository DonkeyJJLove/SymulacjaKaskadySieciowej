from __future__ import annotations

import sys
from pathlib import Path

PROJECT_ROOT = Path(__file__).resolve().parent
SRC_DIR = PROJECT_ROOT / "src"

if str(SRC_DIR) not in sys.path:
    sys.path.insert(0, str(SRC_DIR))

from abstrakcyjna_symulacja_kaskady_sieciowej.cli import main as cli_main


KNOWN_COMMANDS = {"simulate", "morris", "sobol", "bifurcation"}


def _normalize_argv(argv: list[str]) -> list[str]:
    if not argv:
        return ["simulate"]

    first = argv[0]
    if first in KNOWN_COMMANDS:
        return argv

    return ["simulate", *argv]


if __name__ == "__main__":
    raise SystemExit(cli_main(_normalize_argv(sys.argv[1:])))