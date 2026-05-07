import os


def get_config():
    return {
        "host": os.getenv("DB_HOST", "127.0.0.1"),
        "port": int(os.getenv("DB_PORT", "3306")),
        "user": os.getenv("DB_USER", "cluster_app"),
        "password": os.getenv("DB_PASSWORD", "ClusterApp123!"),
        "database": os.getenv("DB_NAME", "cluster_poc"),
    }


def build_url(database_override=None):
    config = get_config()
    database = database_override or config["database"]
    return (
        f"mysql+pymysql://{config['user']}:{config['password']}"
        f"@{config['host']}:{config['port']}/{database}"
    )
