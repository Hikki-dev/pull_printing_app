namespace PullPrintingBackend.Models
{
    public record DemoLoginRequest(bool Admin = false);

    public record SessionDto(string Token, string UserId, string Name, bool IsAdmin);

    public record MeDto(string UserId, string Name, bool IsAdmin, string? Email = null);

    /// <summary>What the sign-in screen needs to know before anyone is signed in.</summary>
    public record AuthConfigDto(string Provider, string? ProviderName, string? Domain, bool Demo);

    /// <summary>Send <c>jobIds</c>; a single <c>jobId</c> is also accepted. Without <c>printerId</c> the first enabled printer is used.</summary>
    public record ReleaseRequest(List<string>? JobIds = null, string? JobId = null, string? PrinterId = null);

    public record ReleaseResponse(List<string> Printed, int Pages, Quota Quota, string? PrinterName);

    public record SetQuotaRequest(string? UserId, int Quota);

    public record QuotaValueRequest(int Quota);

    public record PrinterRequest(string? Name, string? Location, bool? Enabled);

    public record UserQuotaDto(string UserId, string Name, Quota Quota, string? Email = null);

    public record SetupDto(
        string Provider,
        string? ProviderName,
        string? Domain,
        bool DemoEnabled,
        int DefaultQuota,
        int People,
        int Printers,
        string RedirectUri,
        List<string> Warnings);

    public record ApiError(string Error, string Message, int? PagesOver = null);
}
