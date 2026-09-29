"""Explicit test fixture for the isolated validation stack; never called at startup."""

import argparse
import asyncio
import os
from datetime import timedelta
from uuid import uuid4

from sqlalchemy import select
from sqlalchemy.ext.asyncio import async_sessionmaker

from app.core import models  # noqa: F401
from app.core.database import make_engine
from app.core.security import hash_password
from app.modules.routines.models import Routine, RoutineRun, RoutineRunStep, RoutineStep
from app.modules.tasks.models import Priority, Task, TaskStatus
from app.modules.users.models import User
from app.shared.time import utcnow


async def seed(url):
    if os.getenv("APP_ENV") == "production":
        raise SystemExit("Test data is disabled in production.")
    engine = make_engine(url)
    async with async_sessionmaker(engine, expire_on_commit=False)() as db:
        password = await hash_password(os.environ["FLOW_E2E_PASSWORD"])
        email = os.environ["FLOW_E2E_EMAIL"]
        if await db.scalar(select(User).where(User.email == email)):
            print("Validation account already exists.")
            await engine.dispose()
            return
        staff = User(
            email=email,
            display_name="Flow Operator",
            password_hash=password,
            is_staff=True,
            is_verified=True,
        )
        db.add(staff)
        await db.flush()
        for i, name in enumerate(
            [
                "Amina Rahimi",
                "Omar Ahmadi",
                "Sara Azizi",
                "Farid Noori",
                "Mariam Safi",
                "Ali Karimi",
                "Laila Hashemi",
                "Hamed Nouri",
            ]
        ):
            user = User(
                email=f"validation-{i}@example.com",
                display_name=name,
                password_hash=password,
                is_verified=i % 3 != 0,
                created_at=utcnow() - timedelta(days=i + 1),
            )
            db.add(user)
            await db.flush()
            for day in range(14):
                for k in range((i + day) % 4):
                    created = utcnow() - timedelta(days=day, hours=3)
                    completed = created + timedelta(hours=1) if k % 2 == 0 else None
                    db.add(
                        Task(
                            user_id=user.id,
                            title="Validation task",
                            priority=Priority.MEDIUM,
                            status=TaskStatus.COMPLETED if completed else TaskStatus.PENDING,
                            completed_at=completed,
                            created_at=created,
                            updated_at=created,
                        )
                    )
            routine = Routine(
                user_id=user.id,
                name="Morning routine",
                steps=[RoutineStep(title="Plan the day", position=0)],
            )
            db.add(routine)
            await db.flush()
            db.add(
                RoutineRun(
                    user_id=user.id,
                    routine_id=routine.id,
                    name=routine.name,
                    idempotency_key=str(uuid4()),
                    status="completed",
                    completed_at=utcnow(),
                    steps=[RoutineRunStep(title="Plan the day", position=0, completed_at=utcnow())],
                )
            )
        await db.commit()
    await engine.dispose()
    print("Validation fixture created. Credentials were supplied through the environment.")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--database-url", required=True)
    parser.add_argument("--allow-test-data", action="store_true", required=True)
    args = parser.parse_args()
    asyncio.run(seed(args.database_url))
