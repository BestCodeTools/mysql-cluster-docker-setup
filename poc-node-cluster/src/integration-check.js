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
  console.log("Executando validacoes com raw query.");

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
    throw new Error("Falha ao consultar o registro inserido via raw query.");
  }

  await connection.query("DELETE FROM cluster_messages WHERE id = ?", [rawId]);

  const [remainingRows] = await connection.query(
    "SELECT COUNT(*) AS total FROM cluster_messages WHERE id = ?",
    [rawId]
  );

  if (Number(remainingRows[0].total) !== 0) {
    throw new Error("Falha ao excluir o registro via raw query.");
  }

  console.log(`Raw query validada com sucesso. id=${rawId}`);
}

async function runSequelizeChecks(sequelize) {
  console.log("Executando validacoes com Sequelize.");

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
    throw new Error("Falha ao consultar o registro inserido via Sequelize.");
  }

  await loaded.destroy();

  const deleted = await ClusterMessage.findByPk(inserted.id);
  if (deleted) {
    throw new Error("Falha ao excluir o registro via Sequelize.");
  }

  console.log(`Sequelize validado com sucesso. id=${inserted.id}`);
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
      throw new Error("Tabela cluster_messages nao foi encontrada.");
    }

    const metadata = normalizeTableMetadata(rows[0]);
    if (metadata.engine !== "NDBCLUSTER") {
      throw new Error(`Tabela criada com engine inesperado: ${metadata.engine}`);
    }

    console.log(
      `Tabela confirmada para integracao: ${metadata.tableName} com engine ${metadata.engine}.`
    );

    await sequelize.authenticate();
    console.log("Sequelize autenticado com usuario customizado.");

    await runRawQueryChecks(connection);
    await runSequelizeChecks(sequelize);
  } finally {
    await Promise.allSettled([connection.end(), sequelize.close()]);
  }
}

main().catch((error) => {
  console.error("Falha no teste de integracao:", error.message);
  process.exit(1);
});
