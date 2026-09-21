import json
import logging
import sys
from contextvars import ContextVar
from datetime import UTC, datetime

from app.core.config import get_settings

request_id_context = ContextVar("request_id", default=None)


class JsonFormatter(logging.Formatter):
    def format(self, record):
        result = {
            "timestamp": datetime.now(UTC).isoformat(),
            "level": record.levelname,
            "logger": record.name,
            "message": record.getMessage(),
            "request_id": request_id_context.get(),
        }
        for name in ("method", "path", "status", "duration_ms", "user_id"):
            if hasattr(record, name):
                result[name] = getattr(record, name)
        if record.exc_info:
            result["exception"] = self.formatException(record.exc_info)
        return json.dumps(result)


def configure_logging():
    handler = logging.StreamHandler(sys.stdout)
    handler.setFormatter(
        JsonFormatter()
        if get_settings().app_env != "development"
        else logging.Formatter("%(asctime)s %(levelname)s %(name)s %(message)s")
    )
    logging.basicConfig(handlers=[handler], level=logging.INFO, force=True)
    logging.getLogger("httpx").setLevel(logging.WARNING)
