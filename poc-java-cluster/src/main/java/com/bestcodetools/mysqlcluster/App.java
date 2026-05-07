package com.bestcodetools.mysqlcluster;

import org.flywaydb.core.Flyway;
import org.hibernate.Session;
import org.hibernate.SessionFactory;
import org.hibernate.Transaction;
import org.hibernate.cfg.Configuration;

import java.sql.Connection;
import java.sql.DriverManager;
import java.sql.PreparedStatement;
import java.sql.ResultSet;
import java.sql.Statement;
import java.time.Instant;
import java.util.Properties;

public final class App {
    public static void main(String[] args) throws Exception {
        ClusterConfig config = ClusterConfig.load();
        System.out.println("Iniciando PoC Java contra " + config.getHost() + ":" + config.getPort() + "/" + config.getDatabase());

        try (Connection connection = DriverManager.getConnection(
            config.getJdbcUrl(),
            config.getUser(),
            config.getPassword())) {

            validateNdbEngine(connection);
            runMigrations(config);
            runJdbcChecks(connection);
        }

        runHibernateChecks(config);
        System.out.println("PoC Java validada com sucesso.");
    }

    private static void validateNdbEngine(Connection connection) throws Exception {
        try (Statement statement = connection.createStatement();
             ResultSet resultSet = statement.executeQuery("SHOW ENGINES")) {
            boolean found = false;
            while (resultSet.next()) {
                String engine = resultSet.getString("Engine");
                if ("NDBCLUSTER".equalsIgnoreCase(engine)) {
                    found = !"NO".equalsIgnoreCase(resultSet.getString("Support"));
                    break;
                }
            }

            if (!found) {
                throw new IllegalStateException("Engine NDBCLUSTER nao esta disponivel.");
            }
        }
    }

    private static void runMigrations(ClusterConfig config) {
        System.out.println("Executando migration com Flyway.");
        Flyway.configure()
            .dataSource(config.getJdbcUrl(), config.getUser(), config.getPassword())
            .table("schema_history_java")
            .load()
            .migrate();
    }

    private static void runJdbcChecks(Connection connection) throws Exception {
        System.out.println("Executando CRUD com JDBC.");
        try (Statement cleanup = connection.createStatement()) {
            cleanup.executeUpdate("DELETE FROM java_cluster_messages");
        }

        long insertedId;
        String content = "jdbc em " + Instant.now().toString();

        try (PreparedStatement insert = connection.prepareStatement(
            "INSERT INTO java_cluster_messages (content) VALUES (?)",
            Statement.RETURN_GENERATED_KEYS)) {
            insert.setString(1, content);
            insert.executeUpdate();

            try (ResultSet generatedKeys = insert.getGeneratedKeys()) {
                if (!generatedKeys.next()) {
                    throw new IllegalStateException("Falha ao recuperar id do insert JDBC.");
                }
                insertedId = generatedKeys.getLong(1);
            }
        }

        try (PreparedStatement select = connection.prepareStatement(
            "SELECT content FROM java_cluster_messages WHERE id = ?")) {
            select.setLong(1, insertedId);
            try (ResultSet resultSet = select.executeQuery()) {
                if (!resultSet.next() || !content.equals(resultSet.getString(1))) {
                    throw new IllegalStateException("Falha ao ler registro inserido via JDBC.");
                }
            }
        }

        try (PreparedStatement delete = connection.prepareStatement(
            "DELETE FROM java_cluster_messages WHERE id = ?")) {
            delete.setLong(1, insertedId);
            delete.executeUpdate();
        }

        System.out.println("JDBC validado. id=" + insertedId);
    }

    private static void runHibernateChecks(ClusterConfig config) {
        System.out.println("Executando CRUD com Hibernate.");

        Properties properties = new Properties();
        properties.setProperty("hibernate.connection.driver_class", "com.mysql.cj.jdbc.Driver");
        properties.setProperty("hibernate.connection.url", config.getJdbcUrl());
        properties.setProperty("hibernate.connection.username", config.getUser());
        properties.setProperty("hibernate.connection.password", config.getPassword());
        properties.setProperty("hibernate.dialect", "org.hibernate.dialect.MySQL8Dialect");
        properties.setProperty("hibernate.show_sql", "false");
        properties.setProperty("hibernate.hbm2ddl.auto", "none");

        Configuration configuration = new Configuration();
        configuration.setProperties(properties);
        configuration.addAnnotatedClass(ClusterMessage.class);

        try (SessionFactory sessionFactory = configuration.buildSessionFactory()) {
            Session cleanupSession = sessionFactory.openSession();
            Transaction cleanupTx = cleanupSession.beginTransaction();
            cleanupSession.createQuery("delete from ClusterMessage").executeUpdate();
            cleanupTx.commit();
            cleanupSession.close();

            String content = "hibernate em " + Instant.now().toString();
            Session writeSession = sessionFactory.openSession();
            Transaction writeTx = writeSession.beginTransaction();
            ClusterMessage message = new ClusterMessage();
            message.setContent(content);
            writeSession.persist(message);
            writeTx.commit();
            writeSession.close();

            Session readSession = sessionFactory.openSession();
            ClusterMessage loaded = readSession.get(ClusterMessage.class, message.getId());
            if (loaded == null || !content.equals(loaded.getContent())) {
                readSession.close();
                throw new IllegalStateException("Falha ao ler registro inserido via Hibernate.");
            }
            readSession.close();

            Session deleteSession = sessionFactory.openSession();
            Transaction deleteTx = deleteSession.beginTransaction();
            ClusterMessage toDelete = deleteSession.get(ClusterMessage.class, message.getId());
            deleteSession.remove(toDelete);
            deleteTx.commit();
            deleteSession.close();

            System.out.println("Hibernate validado. id=" + message.getId());
        }
    }
}
