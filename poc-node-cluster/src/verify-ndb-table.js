const mysql = require("mysql2/promise");
const { DB_HOST, DB_PORT, DB_USER, DB_PASSWORD, DB_NAME } = require("./config");

async function main() {
  const connection = await mysql.createConnection({
    host: DB_HOST,
    port: DB_PORT,
    user: DB_USER,
    password: DB_PASSWORD,
    database: DB_NAME
  });

  try {
    const [tables] = await connection.query(
      "SELECT table_name, engine FROM information_schema.tables WHERE table_schema = ? AND table_name = 'cluster_messages'",
      [DB_NAME]
    );

    if (!tables.length) {
      throw new Error("Tabela cluster_messages nao existe.");
    }

    const rawEngine = tables[0].engine || tables[0].ENGINE;
    const tableEngine = String(rawEngine).toUpperCase();

    if (tableEngine !== "NDBCLUSTER") {
      throw new Error(
        `Tabela cluster_messages criada com engine inesperado: ${rawEngine}`
      );
    }

    console.log("Tabela cluster_messages confirmada com engine NDBCLUSTER.");
  } finally {
    await connection.end();
  }
}

main().catch((error) => {
  console.error("Falha na verificacao da tabela:", error.message);
  process.exit(1);
});
