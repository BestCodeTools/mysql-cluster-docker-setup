package com.bestcodetools.mysqlcluster;

public final class ClusterConfig {
    private final String host;
    private final int port;
    private final String user;
    private final String password;
    private final String database;

    private ClusterConfig(String host, int port, String user, String password, String database) {
        this.host = host;
        this.port = port;
        this.user = user;
        this.password = password;
        this.database = database;
    }

    public static ClusterConfig load() {
        String host = getenv("DB_HOST", "127.0.0.1");
        int port = Integer.parseInt(getenv("DB_PORT", "3306"));
        String user = getenv("DB_USER", "cluster_app");
        String password = getenv("DB_PASSWORD", "ClusterApp123!");
        String database = getenv("DB_NAME", "cluster_poc");
        return new ClusterConfig(host, port, user, password, database);
    }

    private static String getenv(String key, String defaultValue) {
        String value = System.getenv(key);
        return value == null || value.trim().isEmpty() ? defaultValue : value;
    }

    public String getJdbcUrl() {
        return String.format(
            "jdbc:mysql://%s:%d/%s?useSSL=false&allowPublicKeyRetrieval=true&serverTimezone=UTC",
            host, port, database);
    }

    public String getHost() {
        return host;
    }

    public int getPort() {
        return port;
    }

    public String getUser() {
        return user;
    }

    public String getPassword() {
        return password;
    }

    public String getDatabase() {
        return database;
    }
}
