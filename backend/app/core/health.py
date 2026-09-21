import asyncio

from sqlalchemy import text


async def check_db(db):
    try:
        async with asyncio.timeout(3):
            await db.execute(text("SELECT 1"))
        return "ok"
    except Exception:
        await db.rollback()
        return "error"


async def check_redis(redis):
    try:
        async with asyncio.timeout(2):
            await redis.ping()
        return "ok"
    except Exception:
        return "error"


async def dependencies(db, app):
    db_state = await check_db(db)
    cache, limiter, broker, results = await asyncio.gather(
        *(
            check_redis(client)
            for client in [app.state.redis, app.state.limiter, app.state.broker, app.state.results]
        )
    )
    return {
        "db": db_state,
        "redis": cache,
        "limiter": limiter,
        "broker": broker,
        "results": results,
    }
