"""create python cluster messages

Revision ID: 0001_python_cluster_messages
Revises:
Create Date: 2026-05-07
"""

from alembic import op

revision = "0001_python_cluster_messages"
down_revision = None
branch_labels = None
depends_on = None


def upgrade():
    op.execute(
        """
        CREATE TABLE IF NOT EXISTS python_cluster_messages (
          id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
          content VARCHAR(255) NOT NULL,
          created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
          updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
          PRIMARY KEY (id)
        ) ENGINE=NDBCLUSTER DEFAULT CHARSET=utf8mb4
        """
    )


def downgrade():
    op.execute("DROP TABLE IF EXISTS python_cluster_messages")
