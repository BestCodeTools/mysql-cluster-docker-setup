const {
  DB_HOST,
  DB_PORT,
  DB_USER,
  DB_PASSWORD,
  DB_NAME
} = require("./src/config");

module.exports = {
  client: "mysql2",
  connection: {
    host: DB_HOST,
    port: DB_PORT,
    user: DB_USER,
    password: DB_PASSWORD,
    database: DB_NAME,
    multipleStatements: true
  },
  migrations: {
    directory: "./migrations",
    extension: "cjs"
  }
};
