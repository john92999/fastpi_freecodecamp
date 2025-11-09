"""create votes table

Revision ID: 0003_create_votes
Revises: 0002_create_posts
Create Date: 2025-11-09
"""
from alembic import op
import sqlalchemy as sa

# revision identifiers, used by Alembic.
revision = '0003_create_votes'
down_revision = '0002_create_posts'
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table(
        'votes',
        sa.Column('user_id', sa.Integer(), sa.ForeignKey('users.id', ondelete='CASCADE'), primary_key=True, nullable=False),
        sa.Column('post_id', sa.Integer(), sa.ForeignKey('posts.id', ondelete='CASCADE'), primary_key=True, nullable=False),
    )


def downgrade() -> None:
    op.drop_table('votes')

