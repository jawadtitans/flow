"""One registry shared by migrations, application startup and worker processes."""

from app.modules.admin.models import AdminAudit  # noqa: F401
from app.modules.auth.models import AccountToken, AuthSession, RefreshToken  # noqa: F401
from app.modules.notifications.models import (  # noqa: F401
    Device,
    Notification,
    OutboundEmail,
    PushDelivery,
)
from app.modules.reminders.models import Reminder  # noqa: F401
from app.modules.routines.models import (  # noqa: F401
    Routine,
    RoutineRun,
    RoutineRunStep,
    RoutineStep,
)
from app.modules.tasks.models import Category, Task  # noqa: F401
from app.modules.users.models import User  # noqa: F401
