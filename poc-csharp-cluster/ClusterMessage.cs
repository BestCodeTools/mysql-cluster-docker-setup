namespace PocCSharpCluster;

internal sealed class ClusterMessage
{
    public ulong Id { get; set; }
    public string Content { get; set; } = string.Empty;
    public DateTime CreatedAt { get; set; }
    public DateTime UpdatedAt { get; set; }
}
