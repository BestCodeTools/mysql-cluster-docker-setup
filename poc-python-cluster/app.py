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
                print(f"Engine NDBCLUSTER disponivel ({row[1]}).")
                return

    raise RuntimeError("Engine NDBCLUSTER nao esta disponivel.")


def run_migrations():
    print("Executando migration com Alembic.")
    alembic_config = Config("alembic.ini")
    command.upgrade(alembic_config, "head")


def run_raw_checks(engine):
    print("Executando CRUD com SQLAlchemy Core.")
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
            raise RuntimeError("Falha ao ler registro inserido via SQLAlchemy Core.")

        connection.execute(
            text("DELETE FROM python_cluster_messages WHERE id = :id"),
            {"id": inserted_id},
        )
        count = connection.execute(
            text("SELECT COUNT(*) FROM python_cluster_messages WHERE id = :id"),
            {"id": inserted_id},
        ).scalar_one()

        if count != 0:
            raise RuntimeError("Falha ao excluir registro via SQLAlchemy Core.")

        print(f"SQLAlchemy Core validado. id={inserted_id}")


def run_orm_checks(engine):
    print("Executando CRUD com SQLAlchemy ORM.")
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
            raise RuntimeError("Falha ao ler registro inserido via SQLAlchemy ORM.")

        session.delete(loaded)
        session.commit()

        deleted = session.get(PythonClusterMessage, message.id)
        if deleted is not None:
            raise RuntimeError("Falha ao excluir registro via SQLAlchemy ORM.")

        print(f"SQLAlchemy ORM validado. id={message.id}")


def main():
    engine = create_engine(build_url(), future=True)
    print("Iniciando PoC Python.")
    validate_ndb_engine(engine)
    run_migrations()
    run_raw_checks(engine)
    run_orm_checks(engine)
    print("PoC Python validada com sucesso.")


if __name__ == "__main__":
    main()
