"""Operator-only account management. Never accepts passwords on the command line."""

import argparse
import asyncio
import getpass

from pydantic import EmailStr, TypeAdapter
from sqlalchemy import inspect, select

from app.core import models  # noqa: F401
from app.core.config import get_settings
from app.core.database import SessionLocal, engine, make_engine
from app.core.security import hash_password
from app.modules.auth.repository import revoke_sessions
from app.modules.users.models import User

LEGACY_COLUMNS = {
    "users": {"id", "email", "password_hash", "display_name", "is_active", "created_at"},
    "task_categories": {"id", "user_id", "name", "color"},
    "tasks": {
        "id",
        "user_id",
        "title",
        "description",
        "status",
        "priority",
        "category_id",
        "due_date",
        "due_time",
        "estimated_duration",
        "completed_at",
        "created_at",
        "updated_at",
    },
    "routines": {"id", "user_id", "name", "description", "start_time", "is_active", "created_at"},
    "routine_steps": {"id", "routine_id", "title", "position", "offset_minutes"},
    "reminders": {"id", "user_id", "task_id", "remind_at", "message", "is_sent", "created_at"},
}


async def check_legacy():
    settings = get_settings()
    direct = make_engine(settings.migration_database_url or settings.database_url)

    def inspect_legacy(connection):
        inspector = inspect(connection)
        tables = set(inspector.get_table_names())
        if "alembic_version" in tables:
            raise SystemExit(
                "This database already has migration metadata. Inspect alembic current before proceeding."
            )
        if tables != set(LEGACY_COLUMNS):
            raise SystemExit(
                "The tables do not match the original Flow schema; manual schema review is required."
            )
        for table, expected in LEGACY_COLUMNS.items():
            if {column["name"] for column in inspector.get_columns(table)} != expected:
                raise SystemExit(
                    f"Columns in {table} do not match the legacy schema; manual review is required."
                )

    try:
        async with direct.connect() as connection:
            await connection.run_sync(inspect_legacy)
    finally:
        await direct.dispose()


async def manage(args):
    email = str(TypeAdapter(EmailStr).validate_python(args.email)).lower()
    async with SessionLocal() as db:
        user = await db.scalar(select(User).where(User.email == email).with_for_update())
        if args.command == "create-staff":
            if user:
                raise SystemExit("This account exists. Use set-staff to change its role.")
            password = getpass.getpass("Staff password (at least 12 characters): ")
            if len(password) < 12 or len(password) > 128:
                raise SystemExit("Use 12–128 characters.")
            if password != getpass.getpass("Confirm password: "):
                raise SystemExit("Passwords do not match.")
            db.add(
                User(
                    email=email,
                    display_name=args.name,
                    password_hash=await hash_password(password),
                    is_staff=True,
                    is_verified=True,
                )
            )
        else:
            if not user:
                raise SystemExit("Account not found.")
            if args.command == "set-staff":
                user.is_staff = args.enabled == "true"
                await revoke_sessions(db, user.id)
            elif args.command == "activate-user":
                user.is_active = True
        await db.commit()
    await engine.dispose()
    print("Account updated.")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    commands = parser.add_subparsers(dest="command", required=True)
    staff = commands.add_parser("create-staff")
    staff.add_argument("--email", required=True)
    staff.add_argument("--name", required=True)
    role = commands.add_parser("set-staff")
    role.add_argument("--email", required=True)
    role.add_argument("--enabled", choices=["true", "false"], required=True)
    activate = commands.add_parser("activate-user")
    activate.add_argument("--email", required=True)
    adopt = commands.add_parser("adopt-legacy")
    adopt.add_argument("--acknowledge-backup", action="store_true")
    args = parser.parse_args()
    if args.command == "adopt-legacy":
        if not args.acknowledge_backup:
            parser.error("Back up and verify a restore first, then pass --acknowledge-backup.")
        asyncio.run(check_legacy())
        from alembic.config import Config

        from alembic import command

        command.stamp(Config("alembic.ini"), "0001_initial")
        print("Legacy schema adopted. Run alembic upgrade head next.")
    else:
        asyncio.run(manage(args))


if __name__ == "__main__":
    main()
