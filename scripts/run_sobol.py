from __future__ import annotations

from pathlib import Path

from src.abstrakcyjna_symulacja_kaskady_sieciowej.cli import main

if __name__ == "__main__":
    root = Path(__file__).resolve().parents[1]
    config_path = root / "config" / "config.yaml"
    raise SystemExit(main(["--config", str(config_path), "sobol"]))