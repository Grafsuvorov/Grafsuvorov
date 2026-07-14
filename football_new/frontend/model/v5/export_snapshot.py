from __future__ import annotations

from .data_snapshot import load_v5_snapshot
from .settings import SNAPSHOT_OUTPUT


def main() -> None:
    df = load_v5_snapshot()
    SNAPSHOT_OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    df.to_csv(SNAPSHOT_OUTPUT, index=False)
    print(f"saved {len(df)} rows to {SNAPSHOT_OUTPUT}")


if __name__ == "__main__":
    main()
