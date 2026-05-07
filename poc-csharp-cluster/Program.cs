using System.Reflection;
using Dapper;
using Microsoft.EntityFrameworkCore;
using MySqlConnector;

namespace PocCSharpCluster;

internal static class Program
{
    private static async Task Main()
    {
        var config = ClusterConfig.Load();
        Console.WriteLine($"Iniciando PoC C# contra {config.Host}:{config.Port}/{config.Database}.");

        await using var connection = new MySqlConnection(config.ConnectionString);
        await connection.OpenAsync();

        await ValidateNdbEngineAsync(connection);
        RunMigrations(config);
        await RunRawChecksAsync(connection);
        await RunEntityFrameworkChecksAsync(config);

        Console.WriteLine("PoC C# validada com sucesso.");
    }

    private static async Task ValidateNdbEngineAsync(MySqlConnection connection)
    {
        var engines = await connection.QueryAsync<(string Engine, string Support)>("SHOW ENGINES");
        var ndb = engines.FirstOrDefault(engine =>
            string.Equals(engine.Engine, "NDBCLUSTER", StringComparison.OrdinalIgnoreCase));

        if (string.IsNullOrWhiteSpace(ndb.Engine) || string.Equals(ndb.Support, "NO", StringComparison.OrdinalIgnoreCase))
        {
            throw new InvalidOperationException("Engine NDBCLUSTER nao esta disponivel.");
        }

        Console.WriteLine($"Engine NDBCLUSTER disponivel ({ndb.Support}).");
    }

    private static void RunMigrations(ClusterConfig config)
    {
        Console.WriteLine("Executando migrations C# com runner proprio.");
        using var connection = new MySqlConnection(config.ConnectionString);
        connection.Open();

        connection.Execute(
            """
            CREATE TABLE IF NOT EXISTS schema_migrations_csharp (
              version VARCHAR(255) NOT NULL PRIMARY KEY
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
            """);

        var scriptsPath = Path.Combine(Path.GetDirectoryName(Assembly.GetExecutingAssembly().Location)!, "Migrations");
        var migrationFiles = Directory.GetFiles(scriptsPath, "*.sql")
            .OrderBy(Path.GetFileName, StringComparer.OrdinalIgnoreCase)
            .ToList();

        foreach (var migrationFile in migrationFiles)
        {
            var version = Path.GetFileName(migrationFile);
            var alreadyApplied = connection.ExecuteScalar<long>(
                "SELECT COUNT(*) FROM schema_migrations_csharp WHERE version = @Version",
                new { Version = version });

            if (alreadyApplied > 0)
            {
                Console.WriteLine($"Migration ja aplicada: {version}");
                continue;
            }

            var sql = File.ReadAllText(migrationFile);
            using var command = new MySqlCommand(sql, connection);
            command.ExecuteNonQuery();

            connection.Execute(
                "INSERT INTO schema_migrations_csharp (version) VALUES (@Version)",
                new { Version = version });

            Console.WriteLine($"Migration aplicada: {version}");
        }
    }

    private static async Task RunRawChecksAsync(MySqlConnection connection)
    {
        Console.WriteLine("Executando CRUD com raw query.");

        await connection.ExecuteAsync("DELETE FROM csharp_cluster_messages");

        var content = $"raw query csharp em {DateTime.UtcNow:O}";
        var insertId = await connection.ExecuteScalarAsync<ulong>(
            "INSERT INTO csharp_cluster_messages (content) VALUES (@Content); SELECT LAST_INSERT_ID();",
            new { Content = content });

        var loaded = await connection.QuerySingleOrDefaultAsync<ClusterMessage>(
            "SELECT id, content, created_at AS CreatedAt, updated_at AS UpdatedAt FROM csharp_cluster_messages WHERE id = @Id",
            new { Id = insertId });

        if (loaded is null || loaded.Content != content)
        {
            throw new InvalidOperationException("Falha ao ler o registro inserido via raw query.");
        }

        await connection.ExecuteAsync(
            "DELETE FROM csharp_cluster_messages WHERE id = @Id",
            new { Id = insertId });

        var exists = await connection.ExecuteScalarAsync<long>(
            "SELECT COUNT(*) FROM csharp_cluster_messages WHERE id = @Id",
            new { Id = insertId });

        if (exists != 0)
        {
            throw new InvalidOperationException("Falha ao excluir o registro via raw query.");
        }

        Console.WriteLine($"Raw query validada. id={insertId}");
    }

    private static async Task RunEntityFrameworkChecksAsync(ClusterConfig config)
    {
        Console.WriteLine("Executando CRUD com Entity Framework Core.");

        await using var dbContext = new ClusterDbContext(config);
        await dbContext.Database.OpenConnectionAsync();

        await dbContext.ClusterMessages.ExecuteDeleteAsync();

        var content = $"ef core em {DateTime.UtcNow:O}";
        var message = new ClusterMessage { Content = content };

        dbContext.ClusterMessages.Add(message);
        await dbContext.SaveChangesAsync();

        var loaded = await dbContext.ClusterMessages.SingleOrDefaultAsync(item => item.Id == message.Id);
        if (loaded is null || loaded.Content != content)
        {
            throw new InvalidOperationException("Falha ao ler o registro inserido via Entity Framework Core.");
        }

        dbContext.ClusterMessages.Remove(loaded);
        await dbContext.SaveChangesAsync();

        var deleted = await dbContext.ClusterMessages.SingleOrDefaultAsync(item => item.Id == message.Id);
        if (deleted is not null)
        {
            throw new InvalidOperationException("Falha ao excluir o registro via Entity Framework Core.");
        }

        Console.WriteLine($"Entity Framework Core validado. id={message.Id}");
    }
}
