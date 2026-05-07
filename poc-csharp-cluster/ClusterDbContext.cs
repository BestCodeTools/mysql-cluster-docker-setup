using Microsoft.EntityFrameworkCore;

namespace PocCSharpCluster;

internal sealed class ClusterDbContext(ClusterConfig config) : DbContext
{
    public DbSet<ClusterMessage> ClusterMessages => Set<ClusterMessage>();

    protected override void OnConfiguring(DbContextOptionsBuilder optionsBuilder)
    {
        optionsBuilder.UseMySql(
            config.ConnectionString,
            ServerVersion.AutoDetect(config.ConnectionString));
    }

    protected override void OnModelCreating(ModelBuilder modelBuilder)
    {
        modelBuilder.Entity<ClusterMessage>(entity =>
        {
            entity.ToTable("csharp_cluster_messages");
            entity.HasKey(item => item.Id);

            entity.Property(item => item.Id)
                .HasColumnName("id")
                .ValueGeneratedOnAdd();

            entity.Property(item => item.Content)
                .HasColumnName("content")
                .HasMaxLength(255)
                .IsRequired();

            entity.Property(item => item.CreatedAt)
                .HasColumnName("created_at")
                .ValueGeneratedOnAdd();

            entity.Property(item => item.UpdatedAt)
                .HasColumnName("updated_at")
                .ValueGeneratedOnAddOrUpdate();
        });
    }
}
