from datetime import UTC, datetime, time, timedelta
from zoneinfo import ZoneInfo

from sqlalchemy import and_, case, func, or_, select

from app.core.config import get_settings
from app.modules.routines.models import Routine, RoutineRun
from app.modules.tasks.models import Task, TaskStatus
from app.modules.users.models import User
from app.shared.time import local_today, utcnow


def day_bounds(day):
    zone = ZoneInfo(get_settings().reporting_timezone)
    return datetime.combine(day, time.min, zone).astimezone(UTC), datetime.combine(
        day + timedelta(days=1), time.min, zone
    ).astimezone(UTC)


def count(model, *where):
    return select(func.count()).select_from(model).where(*where).scalar_subquery()


async def overview(db):
    settings = get_settings()
    day = local_today(settings.reporting_timezone)
    start, end = day_bounds(day)
    active = (
        select(func.count(func.distinct(Task.user_id)))
        .join(User, Task.user_id == User.id)
        .where(Task.completed_at >= utcnow() - timedelta(days=7), User.is_active.is_(True))
        .scalar_subquery()
    )
    row = (
        (
            await db.execute(
                select(
                    count(User).label("total_users"),
                    active.label("active_users_7d"),
                    count(Task, Task.created_at >= start, Task.created_at < end).label(
                        "tasks_created_today"
                    ),
                    count(Task, Task.completed_at >= start, Task.completed_at < end).label(
                        "tasks_completed_today"
                    ),
                    count(
                        RoutineRun,
                        RoutineRun.completed_at >= start,
                        RoutineRun.completed_at < end,
                        RoutineRun.status == "completed",
                    ).label("routines_run_today"),
                )
            )
        )
        .mappings()
        .one()
    )
    return {**row, "date": day, "timezone": settings.reporting_timezone}


async def activity(db, days):
    end_day = local_today(get_settings().reporting_timezone)
    dates = [end_day - timedelta(days=days - 1 - i) for i in range(days)]
    output = [
        {
            "date": day,
            "tasks_created": 0,
            "tasks_completed": 0,
            "routines_completed": 0,
            "users_joined": 0,
        }
        for day in dates
    ]
    for model, column, name in [
        (Task, Task.created_at, "tasks_created"),
        (Task, Task.completed_at, "tasks_completed"),
        (RoutineRun, RoutineRun.completed_at, "routines_completed"),
        (User, User.created_at, "users_joined"),
    ]:
        expressions = []
        for day in dates:
            start, end = day_bounds(day)
            expressions.append(
                func.coalesce(func.sum(case((and_(column >= start, column < end), 1), else_=0)), 0)
            )
        row = (
            await db.execute(
                select(*expressions).select_from(model).where(column >= day_bounds(dates[0])[0])
            )
        ).one()
        for point, value in zip(output, row, strict=True):
            point[name] = value
    return output


async def users(db, *, search, status, limit, offset):
    tasks = (
        select(
            Task.user_id,
            func.count().label("task_count"),
            func.sum(case((Task.status == TaskStatus.COMPLETED, 1), else_=0)).label(
                "completed_task_count"
            ),
        )
        .group_by(Task.user_id)
        .subquery()
    )
    routines = (
        select(Routine.user_id, func.count().label("routine_count"))
        .group_by(Routine.user_id)
        .subquery()
    )
    conditions = []
    if search:
        conditions.append(
            or_(
                func.lower(User.email).contains(search.lower(), autoescape=True),
                func.lower(User.display_name).contains(search.lower(), autoescape=True),
            )
        )
    if status != "all":
        conditions.append(User.is_active.is_(status == "active"))
    total = await db.scalar(select(func.count()).select_from(User).where(*conditions))
    rows = (
        (
            await db.execute(
                select(
                    User.id,
                    User.email,
                    User.display_name,
                    User.is_active,
                    User.is_staff,
                    User.is_verified,
                    User.created_at,
                    func.coalesce(tasks.c.task_count, 0).label("task_count"),
                    func.coalesce(tasks.c.completed_task_count, 0).label("completed_task_count"),
                    func.coalesce(routines.c.routine_count, 0).label("routine_count"),
                )
                .outerjoin(tasks, tasks.c.user_id == User.id)
                .outerjoin(routines, routines.c.user_id == User.id)
                .where(*conditions)
                .order_by(User.created_at.desc(), User.id)
                .limit(limit)
                .offset(offset)
            )
        )
        .mappings()
        .all()
    )
    return {"items": rows, "total": total, "limit": limit, "offset": offset}
