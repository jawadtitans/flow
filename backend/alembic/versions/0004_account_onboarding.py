"""Persist onboarding answers and account photos."""

import sqlalchemy as sa

from alembic import op

revision = "0004_account_onboarding"
down_revision = "0003_email_first_auth"
branch_labels = None
depends_on = None


def upgrade():
    with op.batch_alter_table("users") as batch:
        batch.add_column(
            sa.Column(
                "onboarding_completed", sa.Boolean(), nullable=False, server_default=sa.false()
            )
        )
        batch.add_column(sa.Column("discovery_source", sa.String(80)))
        batch.add_column(sa.Column("interests", sa.JSON(), nullable=False, server_default="[]"))
        batch.add_column(sa.Column("other_interest", sa.String(120)))
        batch.add_column(sa.Column("profile_photo", sa.Text()))
    op.execute("UPDATE users SET onboarding_completed = true WHERE profile_completed = true")


def downgrade():
    with op.batch_alter_table("users") as batch:
        for name in (
            "profile_photo",
            "other_interest",
            "interests",
            "discovery_source",
            "onboarding_completed",
        ):
            batch.drop_column(name)
