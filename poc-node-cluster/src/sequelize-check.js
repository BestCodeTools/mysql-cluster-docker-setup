const { Sequelize, DataTypes } = require("sequelize");
const { DB_HOST, DB_PORT, DB_USER, DB_PASSWORD, DB_NAME } = require("./config");

async function main() {
  const sequelize = new Sequelize(DB_NAME, DB_USER, DB_PASSWORD, {
    host: DB_HOST,
    port: DB_PORT,
    dialect: "mysql",
    logging: false
  });

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

  try {
    await sequelize.authenticate();
    console.log("Sequelize conectou com sucesso ao MySQL Cluster.");

    const [rows] = await sequelize.query(
      "SELECT table_name, engine FROM information_schema.tables WHERE table_schema = ? AND table_name = 'cluster_messages'",
      { replacements: [DB_NAME] }
    );

    if (!rows.length) {
      throw new Error("Tabela cluster_messages nao foi encontrada.");
    }

    const tableName = rows[0].table_name || rows[0].TABLE_NAME;
    const rawEngine = rows[0].engine || rows[0].ENGINE;
    const tableEngine = String(rawEngine).toUpperCase();

    console.log(`Tabela encontrada: ${tableName} usando engine ${tableEngine}.`);

    if (tableEngine !== "NDBCLUSTER") {
      throw new Error(`Tabela criada com engine inesperado: ${rawEngine}`);
    }

    const inserted = await ClusterMessage.create({
      content: `mensagem criada via sequelize em ${new Date().toISOString()}`
    });

    const loaded = await ClusterMessage.findByPk(inserted.id);
    console.log(
      `Registro validado via Sequelize. id=${loaded.id}, content="${loaded.content}"`
    );
  } finally {
    await sequelize.close();
  }
}

main().catch((error) => {
  console.error("Falha no teste do Sequelize:", error.message);
  process.exit(1);
});
