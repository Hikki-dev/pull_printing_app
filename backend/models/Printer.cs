namespace PullPrintingBackend.Models
{
    /// <summary>A printer an administrator has set up. People can only print to enabled ones.</summary>
    public record Printer(string Id, string Name, string Location, bool Enabled);
}
