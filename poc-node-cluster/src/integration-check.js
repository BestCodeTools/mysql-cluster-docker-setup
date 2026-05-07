const mysql = require("mysql2/promise");
const { Sequelize, DataTypes } = require("sequelize");
const { DB_HOST, DB_PORT, DB_USER, DB_PASSWORD, DB_NAME } = require("./config");

function normalizeTableMetadata(row) {
  return {
    tableName: row.table_name || row.TABLE_NAME,
    engine: String(row.engine || row.ENGINE || "").toUpperCase()
  };
}

async function runRawQueryChecks(connection) {
  console.log("Running raw query validations.");

  await connection.query("DELETE FROM cluster_messages");

  const rawContent = `raw query em ${new Date().toISOString()}`;
  const [insertResult] = await connection.query(
    "INSERT INTO cluster_messages (content) VALUES (?)",
    [rawContent]
  );

  const rawId = insertResult.insertId;
  const [selectedRows] = await connection.query(
    "SELECT id, content FROM cluster_messages WHERE id = ?",
    [rawId]
  );

  if (!selectedRows.length || selectedRows[0].content !== rawContent) {
    throw new Error("Failed to read the record inserted via raw query.");
  }

  await connection.query("DELETE FROM cluster_messages WHERE id = ?", [rawId]);

  const [remainingRows] = await connection.query(
    "SELECT COUNT(*) AS total FROM cluster_messages WHERE id = ?",
    [rawId]
  );

  if (Number(remainingRows[0].total) !== 0) {
    throw new Error("Failed to delete the record via raw query.");
  }

  console.log(`Raw query validation succeeded. id=${rawId}`);
}

async function runSequelizeChecks(sequelize) {
  console.log("Running Sequelize validations.");

  const ClusterMessage = sequelize.define(
    "ClusterMessage",
    {
      id: {
        type: DataTypes.BIGINT.UNSIGNED,
        autoIncrement: true,
        primaryKey: true
      },
      content: {
        type: DataTypes.STRING(255),
        allowNull: false
      }
    },
    {
      tableName: "cluster_messages",
      timestamps: true,
      underscored: true
    }
  );

  await ClusterMessage.destroy({ where: {} });

  const sequelizeContent = `sequelize em ${new Date().toISOString()}`;
  const inserted = await ClusterMessage.create({ content: sequelizeContent });
  const loaded = await ClusterMessage.findByPk(inserted.id);

  if (!loaded || loaded.content !== sequelizeContent) {
    throw new Error("Failed to read the record inserted via Sequelize.");
  }

  await loaded.destroy();

  const deleted = await ClusterMessage.findByPk(inserted.id);
  if (deleted) {
    throw new Error("Failed to delete the record via Sequelize.");
  }

  console.log(`Sequelize validation succeeded. id=${inserted.id}`);
}

async function main() {
  const connection = await mysql.createConnection({
    host: DB_HOST,
    port: DB_PORT,
    user: DB_USER,
    password: DB_PASSWORD,
    database: DB_NAME
  });

  const sequelize = new Sequelize(DB_NAME, DB_USER, DB_PASSWORD, {
    host: DB_HOST,
    port: DB_PORT,
    dialect: "mysql",
    logging: false
  });

  try {
    const [rows] = await connection.query(
      "SELECT table_name, engine FROM information_schema.tables WHERE table_schema = ? AND table_name = 'cluster_messages'",
      [DB_NAME]
    );

    if (!rows.length) {
      throw new Error("Table cluster_messages was not found.");
    }

    const metadata = normalizeTableMetadata(rows[0]);
    if (metadata.engine !== "NDBCLUSTER") {
      throw new Error(`Table was created with unexpected engine: ${metadata.engine}`);
    }

    console.log(
      `Table confirmed for integration: ${metadata.tableName} using engine ${metadata.engine}.`
    );

    await sequelize.authenticate();
    console.log("Sequelize authenticated with the custom user.");

    await runRawQueryChecks(connection);
    await runSequelizeChecks(sequelize);
  } finally {
    await Promise.allSettled([connection.end(), sequelize.close()]);
  }
}

main().catch((error) => {
  console.error("Integration test failed:", error.message);
  process.exit(1);
});
