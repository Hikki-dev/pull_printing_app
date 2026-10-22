namespace PullPrintingBackend.Models
{
    /// <summary>Pages used and allowed this month.</summary>
    public record Quota(int Used, int Total)
    {
        public int Left => Math.Max(Total - Used, 0);
    }
}
