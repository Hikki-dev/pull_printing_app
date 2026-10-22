namespace PullPrintingBackend.Models
{
    /// <summary>A person known to the store. Mutated only while the store's lock is held.</summary>
    public class User
    {
        public required string Id { get; init; }
        public required string DisplayName { get; set; }
        public string? Email { get; set; }
        public bool IsAdmin { get; set; }
        public int PrintQuota { get; set; }
        public int PagesUsed { get; set; }
        public DateTimeOffset LastSeen { get; set; }

        /// <summary>
        /// Who can see and manage this person. Everyone who signs in for real shares the
        /// <c>default</c> group; each demo visitor and demo administrator gets a private one.
        /// </summary>
        public string SandboxId { get; init; } = "default";

        public Quota Quota => new(PagesUsed, PrintQuota);
    }

    public record UserSummary(string UserId, string Name, bool IsAdmin, Quota Quota);
}
