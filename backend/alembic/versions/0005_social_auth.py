"""Mark users who can sign in with a social identity provider."""

import sqlalchemy as sa

from alembic import op

revision = "0005_social_auth"
down_revision = "0004_account_onboarding"
branch_labels = None
depends_on = None


def upgrade():
    with op.batch_alter_table("users") as batch:
        batch.add_column(
            sa.Column("social_auth", sa.Boolean(), nullable=False, server_default=sa.false())
        )


def downgrade():
    with op.batch_alter_table("users") as batch:
        batch.drop_column("social_auth")
