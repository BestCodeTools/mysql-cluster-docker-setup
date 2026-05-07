from alembic import command
from alembic.config import Config
from sqlalchemy import create_engine, text
from sqlalchemy.orm import Session

from config import build_url
from models import PythonClusterMessage


def validate_ndb_engine(engine):
    with engine.connect() as connection:
        rows = connection.execute(text("SHOW ENGINES"))
        for row in rows:
            if str(row[0]).upper() == "NDBCLUSTER" and str(row[1]).upper() != "NO":
                print(f"Engine NDBCLUSTER available ({row[1]}).")
                return

    raise RuntimeError("Engine NDBCLUSTER is not available.")


def run_migrations():
    print("Running migration with Alembic.")
    alembic_config = Config("alembic.ini")
    command.upgrade(alembic_config, "head")


def run_raw_checks(engine):
    print("Running CRUD with SQLAlchemy Core.")
    with engine.begin() as connection:
        connection.execute(text("DELETE FROM python_cluster_messages"))
        content = "sqlalchemy core python"
        result = connection.execute(
            text("INSERT INTO python_cluster_messages (content) VALUES (:content)"),
            {"content": content},
        )
        inserted_id = result.lastrowid
        loaded = connection.execute(
            text("SELECT content FROM python_cluster_messages WHERE id = :id"),
            {"id": inserted_id},
        ).scalar_one()

        if loaded != content:
            raise RuntimeError("Failed to read the record inserted via SQLAlchemy Core.")

        connection.execute(
            text("DELETE FROM python_cluster_messages WHERE id = :id"),
            {"id": inserted_id},
        )
        count = connection.execute(
            text("SELECT COUNT(*) FROM python_cluster_messages WHERE id = :id"),
            {"id": inserted_id},
        ).scalar_one()

        if count != 0:
            raise RuntimeError("Failed to delete the record via SQLAlchemy Core.")

        print(f"SQLAlchemy Core validated. id={inserted_id}")


def run_orm_checks(engine):
    print("Running CRUD with SQLAlchemy ORM.")
    with Session(engine) as session:
        session.execute(text("DELETE FROM python_cluster_messages"))
        session.commit()

        content = "sqlalchemy orm python"
        message = PythonClusterMessage(content=content)
        session.add(message)
        session.commit()
        session.refresh(message)

        loaded = session.get(PythonClusterMessage, message.id)
        if loaded is None or loaded.content != content:
            raise RuntimeError("Failed to read the record inserted via SQLAlchemy ORM.")

        session.delete(loaded)
        session.commit()

        deleted = session.get(PythonClusterMessage, message.id)
        if deleted is not None:
            raise RuntimeError("Failed to delete the record via SQLAlchemy ORM.")

        print(f"SQLAlchemy ORM validated. id={message.id}")


def main():
    engine = create_engine(build_url(), future=True)
    print("Starting Python PoC.")
    validate_ndb_engine(engine)
    run_migrations()
    run_raw_checks(engine)
    run_orm_checks(engine)
    print("Python PoC validated successfully.")


if __name__ == "__main__":
    main()
