const DB_HOST = process.env.DB_HOST || "127.0.0.1";
const DB_PORT = Number(process.env.DB_PORT || 3306);
const DB_USER = process.env.DB_USER || "cluster_app";
const DB_PASSWORD = process.env.DB_PASSWORD || "ClusterApp123!";
const DB_NAME = process.env.DB_NAME || "cluster_poc";

module.exports = {
  DB_HOST,
  DB_PORT,
  DB_USER,
  DB_PASSWORD,
  DB_NAME
};
