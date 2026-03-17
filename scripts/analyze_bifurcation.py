from __future__ import annotations

from pathlib import Path
from src.abstrakcyjna_symulacja_kaskady_sieciowej.cli import main

if __name__ == "__main__":
    project_root = Path(__file__).resolve().parents[1]
    data_path = project_root / "outputs" / "sobol" / "sobol_model_outputs.csv"

    if not data_path.exists():
        raise SystemExit(f"Brak pliku wejściowego: {data_path}")

    raise SystemExit(main(["bifurcation", "--data", str(data_path)]))