namespace PullPrintingBackend.Models
{
    public static class JobStatus
    {
        public const string Held = "Held";
        public const string Printed = "Printed";
        public const string Failed = "Failed";
    }

    /// <summary>One document waiting to print, or already printed. Immutable, updated with <c>with</c>.</summary>
    public record PrintJob(
        string Id,
        string UserId,
        string UserName,
        string FileName,
        int Pages,
        DateTimeOffset SubmittedAt,
        string Status,
        string? FailureReason = null,
        string? PrinterName = null);
}
