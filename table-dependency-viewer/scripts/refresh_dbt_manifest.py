#!/usr/bin/env python3
from __future__ import annotations

import fcntl
import os
import shutil
import sys
import tempfile
from contextlib import contextmanager
from datetime import date
from pathlib import Path

from minio import Minio


REQUIRED_FILES = ("manifest.json", "run_results.json")


def env_bool(name: str, default: bool) -> bool:
    value = os.getenv(name)
    if value is None:
        return default
    return value.strip().lower() in {"1", "true", "yes", "on"}


def env_int(name: str, default: int) -> int:
    value = os.getenv(name)
    if value is None:
        return default
    return int(value)


def project_root() -> Path:
    return Path(__file__).resolve().parents[1]


def resolve_path(raw: str, default: Path) -> Path:
    if not raw:
        return default
    path = Path(raw)
    if path.is_absolute():
        return path
    return (project_root() / path).resolve()


def load_config() -> dict[str, object]:
    root = project_root()
    target_root = resolve_path(
        os.getenv("DBT_MANIFEST_ROOT", "config_files/dbt"),
        root / "config_files/dbt",
    )
    source = os.getenv("DBT_MANIFEST_SOURCE", "ohd").strip() or "ohd"
    day = os.getenv("DBT_REFRESH_DAY", date.today().isoformat()).strip()
    return {
        "host": os.environ["MINIO_HOST"].strip(),
        "port": env_int("MINIO_PORT", 9000),
        "access_key": os.environ["MINIO_ACCESS_KEY"].strip(),
        "secret_key": os.environ["MINIO_SECRET_KEY"],
        "secure": env_bool("MINIO_SECURE", True),
        "bucket": os.getenv("DBT_MINIO_BUCKET", "dbt-zp-prod").strip(),
        "prefix": os.getenv("DBT_MINIO_PREFIX", "dbt_run_manual").strip().strip("/"),
        "source": source,
        "target_dir": (target_root / source).resolve(),
        "archive_dir": (target_root / ".archive" / source).resolve(),
        "keep_count": max(1, env_int("DBT_MANIFEST_KEEP", 2)),
        "day": day,
        "lock_path": resolve_path(
            os.getenv("DBT_MANIFEST_LOCK_FILE", "/tmp/tdv_refresh_dbt_manifest.lock"),
            Path("/tmp/tdv_refresh_dbt_manifest.lock"),
        ),
    }


@contextmanager
def exclusive_lock(lock_path: Path):
    lock_path.parent.mkdir(parents=True, exist_ok=True)
    with lock_path.open("w", encoding="utf-8") as handle:
        try:
            fcntl.flock(handle.fileno(), fcntl.LOCK_EX | fcntl.LOCK_NB)
        except BlockingIOError as exc:
            raise RuntimeError(f"Lock already acquired: {lock_path}") from exc
        handle.write(str(os.getpid()))
        handle.flush()
        try:
            yield
        finally:
            fcntl.flock(handle.fileno(), fcntl.LOCK_UN)


def build_client(config: dict[str, object]) -> Minio:
    endpoint = f"{config['host']}:{config['port']}"
    return Minio(
        endpoint,
        access_key=str(config["access_key"]),
        secret_key=str(config["secret_key"]),
        secure=bool(config["secure"]),
        cert_check=False,
    )


def find_latest_run_prefix(client: Minio, config: dict[str, object]) -> str | None:
    day_prefix = f"{config['prefix']}/{config['day']}/"
    manifests: list[str] = []
    for obj in client.list_objects(
        bucket_name=str(config["bucket"]),
        prefix=day_prefix,
        recursive=True,
    ):
        if obj.object_name.endswith("/manifest.json"):
            manifests.append(obj.object_name)
    if not manifests:
        return None
    latest_manifest = sorted(manifests)[-1]
    return str(Path(latest_manifest).parent)


def download_run_files(client: Minio, config: dict[str, object], run_prefix: str, tmp_dir: Path) -> dict[str, Path]:
    downloaded: dict[str, Path] = {}
    for file_name in REQUIRED_FILES:
        object_name = f"{run_prefix}/{file_name}"
        local_path = tmp_dir / file_name
        try:
            client.fget_object(
                bucket_name=str(config["bucket"]),
                object_name=object_name,
                file_path=str(local_path),
            )
        except Exception:
            if file_name == "manifest.json":
                raise
            continue
        downloaded[file_name] = local_path
    if "manifest.json" not in downloaded:
        raise RuntimeError(f"manifest.json not found in {run_prefix}")
    return downloaded


def install_files(config: dict[str, object], downloaded: dict[str, Path], run_prefix: str) -> None:
    target_dir = Path(config["target_dir"])
    archive_dir = Path(config["archive_dir"])
    run_name = Path(run_prefix).name.replace(" ", "_").replace(":", "-")
    archive_run_dir = archive_dir / f"{config['day']}_{run_name}"

    target_dir.mkdir(parents=True, exist_ok=True)
    archive_run_dir.mkdir(parents=True, exist_ok=True)

    for file_name, local_path in downloaded.items():
        shutil.copy2(local_path, archive_run_dir / file_name)

    for file_name, local_path in downloaded.items():
        tmp_target = target_dir / f".{file_name}.tmp"
        shutil.copy2(local_path, tmp_target)
        tmp_target.replace(target_dir / file_name)

    (archive_run_dir / "source_prefix.txt").write_text(f"{run_prefix}\n", encoding="utf-8")


def cleanup_archives(config: dict[str, object]) -> None:
    archive_dir = Path(config["archive_dir"])
    if not archive_dir.exists():
        return
    directories = sorted(
        [path for path in archive_dir.iterdir() if path.is_dir()],
        key=lambda item: item.name,
        reverse=True,
    )
    for old_dir in directories[int(config["keep_count"]):]:
        shutil.rmtree(old_dir)


def main() -> int:
    config = load_config()
    with exclusive_lock(Path(config["lock_path"])):
        client = build_client(config)
        run_prefix = find_latest_run_prefix(client, config)
        if not run_prefix:
            print(f"No manifest found for day {config['day']}")
            return 0

        with tempfile.TemporaryDirectory(prefix="tdv_dbt_manifest_") as tmp_name:
            downloaded = download_run_files(client, config, run_prefix, Path(tmp_name))
            install_files(config, downloaded, run_prefix)
        cleanup_archives(config)
        print(
            "Updated dbt manifest:",
            f"source={config['source']}",
            f"day={config['day']}",
            f"run={run_prefix}",
        )
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except Exception as exc:
        print(f"refresh_dbt_manifest failed: {exc}", file=sys.stderr)
        raise SystemExit(1)
