import os
import sqlite3
import subprocess
import sys
from pathlib import Path


def alembic(path, *args):
    env = {
        **os.environ,
        "DATABASE_URL": f"sqlite+aiosqlite:///{path}",
        "MIGRATION_DATABASE_URL": f"sqlite+aiosqlite:///{path}",
    }
    return subprocess.run(
        [sys.executable, "-m", "alembic", *args],
        env=env,
        cwd=Path(__file__).parents[1],
        capture_output=True,
        text=True,
        timeout=40,
    )


def test_upgrade_preserves_legacy_rows_and_downgrades(tmp_path):
    path = tmp_path / "legacy.db"
    result = alembic(path, "upgrade", "0001_initial")
    assert result.returncode == 0, result.stderr
    with sqlite3.connect(path) as conn:
        conn.execute(
            "INSERT INTO users (id,email,password_hash,display_name,is_active,created_at) VALUES (?,?,?,?,?,?)",
            ("0" * 32, "old@example.com", "hash", "Existing", 1, "2026-01-01 00:00:00"),
        )
    result = alembic(path, "upgrade", "head")
    assert result.returncode == 0, result.stderr
    with sqlite3.connect(path) as conn:
        row = conn.execute("SELECT email, is_staff, timezone FROM users").fetchone()
        assert row == ("old@example.com", 0, "Asia/Kabul")
    result = alembic(path, "check")
    assert result.returncode == 0, result.stdout + result.stderr
    result = alembic(path, "downgrade", "0001_initial")
    assert result.returncode == 0, result.stderr
    with sqlite3.connect(path) as conn:
        assert conn.execute("SELECT email FROM users").fetchone()[0] == "old@example.com"
    result = alembic(path, "upgrade", "head")
    assert result.returncode == 0, result.stderr
