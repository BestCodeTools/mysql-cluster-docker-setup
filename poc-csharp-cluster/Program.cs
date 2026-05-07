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
        Console.WriteLine($"Starting C# PoC against {config.Host}:{config.Port}/{config.Database}.");

        await using var connection = new MySqlConnection(config.ConnectionString);
        await connection.OpenAsync();

        await ValidateNdbEngineAsync(connection);
        RunMigrations(config);
        await RunRawChecksAsync(connection);
        await RunEntityFrameworkChecksAsync(config);

        Console.WriteLine("C# PoC validated successfully.");
    }

    private static async Task ValidateNdbEngineAsync(MySqlConnection connection)
    {
        var engines = await connection.QueryAsync<(string Engine, string Support)>("SHOW ENGINES");
        var ndb = engines.FirstOrDefault(engine =>
            string.Equals(engine.Engine, "NDBCLUSTER", StringComparison.OrdinalIgnoreCase));

        if (string.IsNullOrWhiteSpace(ndb.Engine) || string.Equals(ndb.Support, "NO", StringComparison.OrdinalIgnoreCase))
        {
            throw new InvalidOperationException("Engine NDBCLUSTER is not available.");
        }

        Console.WriteLine($"Engine NDBCLUSTER available ({ndb.Support}).");
    }

    private static void RunMigrations(ClusterConfig config)
    {
        Console.WriteLine("Running C# migrations with the local SQL runner.");
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
                Console.WriteLine($"Migration already applied: {version}");
                continue;
            }

            var sql = File.ReadAllText(migrationFile);
            using var command = new MySqlCommand(sql, connection);
            command.ExecuteNonQuery();

            connection.Execute(
                "INSERT INTO schema_migrations_csharp (version) VALUES (@Version)",
                new { Version = version });

            Console.WriteLine($"Migration applied: {version}");
        }
    }

    private static async Task RunRawChecksAsync(MySqlConnection connection)
    {
        Console.WriteLine("Running raw query CRUD.");

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
            throw new InvalidOperationException("Failed to read the record inserted via raw query.");
        }

        await connection.ExecuteAsync(
            "DELETE FROM csharp_cluster_messages WHERE id = @Id",
            new { Id = insertId });

        var exists = await connection.ExecuteScalarAsync<long>(
            "SELECT COUNT(*) FROM csharp_cluster_messages WHERE id = @Id",
            new { Id = insertId });

        if (exists != 0)
        {
            throw new InvalidOperationException("Failed to delete the record via raw query.");
        }

        Console.WriteLine($"Raw query validated. id={insertId}");
    }

    private static async Task RunEntityFrameworkChecksAsync(ClusterConfig config)
    {
        Console.WriteLine("Running Entity Framework Core CRUD.");

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
            throw new InvalidOperationException("Failed to read the record inserted via Entity Framework Core.");
        }

        dbContext.ClusterMessages.Remove(loaded);
        await dbContext.SaveChangesAsync();

        var deleted = await dbContext.ClusterMessages.SingleOrDefaultAsync(item => item.Id == message.Id);
        if (deleted is not null)
        {
            throw new InvalidOperationException("Failed to delete the record via Entity Framework Core.");
        }

        Console.WriteLine($"Entity Framework Core validated. id={message.Id}");
    }
}
