const mysql = require("mysql2/promise");
const { DB_HOST, DB_PORT, DB_USER, DB_PASSWORD, DB_NAME } = require("./config");

async function main() {
  const connection = await mysql.createConnection({
    host: DB_HOST,
    port: DB_PORT,
    user: DB_USER,
    password: DB_PASSWORD,
    multipleStatements: true
  });

  try {
    await connection.query(`CREATE DATABASE IF NOT EXISTS \`${DB_NAME}\``);

    const [engines] = await connection.query("SHOW ENGINES");
    const ndbEngine = engines.find(
      (engine) => String(engine.Engine).toUpperCase() === "NDBCLUSTER"
    );

    if (!ndbEngine || ndbEngine.Support === "NO") {
      throw new Error("Engine NDBCLUSTER is not available on this server.");
    }

    console.log(
      `Database ${DB_NAME} is ready and engine NDBCLUSTER is available (${ndbEngine.Support}).`
    );
  } finally {
    await connection.end();
  }
}

main().catch((error) => {
  console.error("Failed to prepare database:", error.message);
  process.exit(1);
});
