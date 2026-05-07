namespace PocCSharpCluster;

internal sealed record ClusterConfig(
    string Host,
    int Port,
    string User,
    string Password,
    string Database)
{
    public static ClusterConfig Load()
    {
        return new ClusterConfig(
            Environment.GetEnvironmentVariable("DB_HOST") ?? "127.0.0.1",
            int.TryParse(Environment.GetEnvironmentVariable("DB_PORT"), out var port) ? port : 3306,
            Environment.GetEnvironmentVariable("DB_USER") ?? "cluster_app",
            Environment.GetEnvironmentVariable("DB_PASSWORD") ?? "ClusterApp123!",
            Environment.GetEnvironmentVariable("DB_NAME") ?? "cluster_poc");
    }

    public string ConnectionString =>
        $"Server={Host};Port={Port};Database={Database};User ID={User};Password={Password};SslMode=None;AllowUserVariables=True";
}
