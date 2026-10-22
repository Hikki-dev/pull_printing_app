namespace PullPrintingBackend.Models
{
    public record DemoLoginRequest(bool Admin = false);

    public record SessionDto(string Token, string UserId, string Name, bool IsAdmin);

    public record MeDto(string UserId, string Name, bool IsAdmin);

    /// <summary>Send <c>jobIds</c>; a single <c>jobId</c> is also accepted.</summary>
    public record ReleaseRequest(List<string>? JobIds = null, string? JobId = null);

    public record ReleaseResponse(List<string> Printed, int Pages, Quota Quota);

    public record SetQuotaRequest(string? UserId, int Quota);

    public record UserQuotaDto(string UserId, string Name, Quota Quota);

    public record ApiError(string Error, string Message, int? PagesOver = null);
}
