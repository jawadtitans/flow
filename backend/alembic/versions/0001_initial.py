"""Initial Flow foundation.

Revision ID: 0001_initial
Revises:
"""

import sqlalchemy as sa

from alembic import op

revision = "0001_initial"
down_revision = None
branch_labels = None
depends_on = None


def upgrade():
    op.create_table(
        "users",
        sa.Column("id", sa.Uuid(), primary_key=True),
        sa.Column("email", sa.String(320), nullable=False),
        sa.Column("password_hash", sa.String(255), nullable=False),
        sa.Column("display_name", sa.String(100), nullable=False),
        sa.Column("is_active", sa.Boolean(), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
    )
    op.create_index("ix_users_email", "users", ["email"], unique=True)
    op.create_table(
        "task_categories",
        sa.Column("id", sa.Uuid(), primary_key=True),
        sa.Column("user_id", sa.Uuid(), sa.ForeignKey("users.id"), nullable=False),
        sa.Column("name", sa.String(80), nullable=False),
        sa.Column("color", sa.String(7)),
    )
    op.create_index("ix_task_categories_user_id", "task_categories", ["user_id"])
    op.create_table(
        "tasks",
        sa.Column("id", sa.Uuid(), primary_key=True),
        sa.Column("user_id", sa.Uuid(), sa.ForeignKey("users.id"), nullable=False),
        sa.Column("title", sa.String(280), nullable=False),
        sa.Column("description", sa.Text()),
        sa.Column("status", sa.String(20), nullable=False),
        sa.Column("priority", sa.String(20), nullable=False),
        sa.Column("category_id", sa.Uuid(), sa.ForeignKey("task_categories.id")),
        sa.Column("due_date", sa.Date()),
        sa.Column("due_time", sa.Time()),
        sa.Column("estimated_duration", sa.Integer()),
        sa.Column("completed_at", sa.DateTime(timezone=True)),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), nullable=False),
    )
    op.create_index("ix_tasks_user_id", "tasks", ["user_id"])
    op.create_index("ix_tasks_due_date", "tasks", ["due_date"])
    op.create_table(
        "routines",
        sa.Column("id", sa.Uuid(), primary_key=True),
        sa.Column("user_id", sa.Uuid(), sa.ForeignKey("users.id"), nullable=False),
        sa.Column("name", sa.String(160), nullable=False),
        sa.Column("description", sa.Text()),
        sa.Column("start_time", sa.Time()),
        sa.Column("is_active", sa.Boolean(), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
    )
    op.create_index("ix_routines_user_id", "routines", ["user_id"])
    op.create_table(
        "routine_steps",
        sa.Column("id", sa.Uuid(), primary_key=True),
        sa.Column("routine_id", sa.Uuid(), sa.ForeignKey("routines.id"), nullable=False),
        sa.Column("title", sa.String(280), nullable=False),
        sa.Column("position", sa.Integer(), nullable=False),
        sa.Column("offset_minutes", sa.Integer(), nullable=False),
    )
    op.create_index("ix_routine_steps_routine_id", "routine_steps", ["routine_id"])
    op.create_table(
        "reminders",
        sa.Column("id", sa.Uuid(), primary_key=True),
        sa.Column("user_id", sa.Uuid(), sa.ForeignKey("users.id"), nullable=False),
        sa.Column("task_id", sa.Uuid(), sa.ForeignKey("tasks.id")),
        sa.Column("remind_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("message", sa.String(280)),
        sa.Column("is_sent", sa.Boolean(), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
    )
    op.create_index("ix_reminders_user_id", "reminders", ["user_id"])
    op.create_index("ix_reminders_remind_at", "reminders", ["remind_at"])


def downgrade():
    op.drop_table("reminders")
    op.drop_table("routine_steps")
    op.drop_table("routines")
    op.drop_table("tasks")
    op.drop_table("task_categories")
    op.drop_table("users")
