"""Email-first authentication and profile completion.

The existing schema calls its name field display_name, not full_name. Keep it
for older clients and backfill the structured fields without losing that value.
"""

import sqlalchemy as sa

from alembic import op

revision = "0003_email_first_auth"
down_revision = "0002_hardening"
branch_labels = None
depends_on = None


def upgrade():
    with op.batch_alter_table("users") as batch:
        batch.add_column(sa.Column("first_name", sa.String(50), nullable=True))
        batch.add_column(sa.Column("last_name", sa.String(49), nullable=True))
        batch.add_column(sa.Column("birth_date", sa.Date(), nullable=True))
        batch.add_column(
            sa.Column("profile_completed", sa.Boolean(), server_default=sa.false(), nullable=False)
        )
        batch.alter_column("password_hash", existing_type=sa.String(255), nullable=True)
        batch.alter_column("display_name", existing_type=sa.String(100), server_default="")
        batch.alter_column(
            "is_verified",
            new_column_name="email_verified",
            existing_type=sa.Boolean(),
            existing_nullable=False,
        )
    users = sa.table(
        "users",
        sa.column("id"),
        sa.column("display_name"),
        sa.column("first_name"),
        sa.column("last_name"),
    )
    connection = op.get_bind()
    for row in connection.execute(sa.select(users.c.id, users.c.display_name)).mappings():
        parts = (row["display_name"] or "").strip().split(maxsplit=1)
        if parts:
            connection.execute(
                users.update()
                .where(users.c.id == row["id"])
                .values(
                    first_name=parts[0][:50],
                    last_name=parts[1][:49] if len(parts) > 1 else None,
                )
            )
    # A legacy display name alone does not supply the required birth date.
    # These accounts finish onboarding on their next mobile sign-in.


def downgrade():
    if op.get_bind().scalar(sa.text("SELECT count(*) FROM users WHERE password_hash IS NULL")):
        raise RuntimeError(
            "Cannot downgrade while passwordless accounts exist; this would lose their authentication model."
        )
    with op.batch_alter_table("users") as batch:
        batch.alter_column(
            "email_verified",
            new_column_name="is_verified",
            existing_type=sa.Boolean(),
            existing_nullable=False,
        )
        batch.alter_column("password_hash", existing_type=sa.String(255), nullable=False)
        batch.alter_column("display_name", existing_type=sa.String(100), server_default=None)
        for name in ("profile_completed", "birth_date", "last_name", "first_name"):
            batch.drop_column(name)
