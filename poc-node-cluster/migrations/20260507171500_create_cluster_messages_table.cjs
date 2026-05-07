/**
 * @param {import('knex').Knex} knex
 */
exports.up = async function up(knex) {
  await knex.schema.dropTableIfExists("cluster_messages");

  await knex.raw(`
    CREATE TABLE cluster_messages (
      id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
      content VARCHAR(255) NOT NULL,
      created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
      updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
      PRIMARY KEY (id)
    ) ENGINE=NDBCLUSTER DEFAULT CHARSET=utf8mb4
  `);
};

/**
 * @param {import('knex').Knex} knex
 */
exports.down = async function down(knex) {
  await knex.schema.dropTableIfExists("cluster_messages");
};
