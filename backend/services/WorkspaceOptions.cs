using System.Security.Claims;

namespace PullPrintingBackend.Services
{
    /// <summary>
    /// Connects the server to the organisation's work accounts, Microsoft Entra ID or Google Workspace.
    /// People sign in with their normal work account; the server decides who may do what.
    /// </summary>
    public class WorkspaceOptions
    {
        /// <summary><c>Microsoft</c> or <c>Google</c>. Leave empty for demo-only.</summary>
        public string? Provider { get; set; }

        public string? ClientId { get; set; }
        public string? ClientSecret { get; set; }

        /// <summary>Microsoft only: the tenant (directory) id.</summary>
        public string? TenantId { get; set; }

        /// <summary>
        /// Google: the Workspace domain, required. Microsoft: optional extra limit to one email domain.
        /// </summary>
        public string? Domain { get; set; }

        /// <summary>Email addresses of administrators, separated by commas, semicolons or spaces.</summary>
        public string? Admins { get; set; }

        /// <summary>Microsoft only: an app role that also makes someone an administrator.</summary>
        public string AdminRole { get; set; } = "PullPrint.Admin";

        /// <summary>Pages a month for a person who signs in for the first time.</summary>
        public int DefaultQuota { get; set; } = 50;

        /// <summary>Overrides the provider's sign-in address. Only for tests and special set-ups.</summary>
        public string? Authority { get; set; }

        public bool RequireHttpsMetadata { get; set; } = true;

        public bool IsMicrosoft => string.Equals(Provider, "Microsoft", StringComparison.OrdinalIgnoreCase);
        public bool IsGoogle => string.Equals(Provider, "Google", StringComparison.OrdinalIgnoreCase);
        public bool IsConfigured => !string.IsNullOrWhiteSpace(Provider);

        /// <summary>Plain-words reasons the settings cannot be used. Empty means ready.</summary>
        public IReadOnlyList<string> Problems()
        {
            var problems = new List<string>();
            if (!IsConfigured) return problems;
            if (!IsMicrosoft && !IsGoogle)
                problems.Add($"Workspace__Provider is \"{Provider}\". Use Microsoft or Google.");
            if (string.IsNullOrWhiteSpace(ClientId)) problems.Add("Workspace__ClientId is missing.");
            if (string.IsNullOrWhiteSpace(ClientSecret)) problems.Add("Workspace__ClientSecret is missing.");
            if (IsMicrosoft && string.IsNullOrWhiteSpace(TenantId)) problems.Add("Workspace__TenantId is missing.");
            if (IsGoogle && string.IsNullOrWhiteSpace(Domain))
                problems.Add("Workspace__Domain is missing. Without it any Google account could sign in.");
            if (DefaultQuota < 0) problems.Add("Workspace__DefaultQuota cannot be negative.");
            return problems;
        }

        public bool Enabled => IsConfigured && Problems().Count == 0;

        public string? ProviderName => IsMicrosoft ? "Microsoft" : IsGoogle ? "Google" : null;

        /// <summary>The address the person is sent to in order to sign in.</summary>
        public string EffectiveAuthority =>
            !string.IsNullOrWhiteSpace(Authority) ? Authority!
            : IsMicrosoft ? $"https://login.microsoftonline.com/{TenantId}/v2.0"
            : "https://accounts.google.com";

        public IReadOnlySet<string> AdminEmails =>
            (Admins ?? "")
                .Split(new[] { ',', ';', ' ', '\n', '\r', '\t' }, StringSplitOptions.RemoveEmptyEntries)
                .Select(e => e.Trim().ToLowerInvariant())
                .ToHashSet();
    }

    public record WorkspaceUser(string Id, string Name, string? Email, bool IsAdmin);

    /// <summary>Why a work account was turned away, in words for the person.</summary>
    public record WorkspaceDenied(string Code, string Message);

    /// <summary>Turns what the provider says about a person into who they are here, or says why not.</summary>
    public static class WorkspaceIdentity
    {
        public static (WorkspaceUser? User, WorkspaceDenied? Denied) Map(WorkspaceOptions options, ClaimsPrincipal principal)
        {
            string? Claim(string type) => principal.FindFirstValue(type);

            var email = (Claim("email") ?? Claim("preferred_username") ?? Claim("upn"))?.Trim().ToLowerInvariant();
            var domain = options.Domain?.Trim().TrimStart('@').ToLowerInvariant();
            var name = Claim("name") ?? email ?? "Signed-in user";

            string? id;
            if (options.IsGoogle)
            {
                id = Claim("sub");
                if (id is null) return (null, new("no_identity", "The sign-in did not say who you are."));
                if (!string.Equals(Claim("email_verified"), "true", StringComparison.OrdinalIgnoreCase))
                    return (null, new("unverified_email", "Your email address is not verified with Google."));
                if (domain is not null &&
                    !string.Equals(Claim("hd"), domain, StringComparison.OrdinalIgnoreCase))
                    return (null, NotInDomain(domain));
                id = "g-" + id;
            }
            else
            {
                id = Claim("oid") ?? Claim("sub");
                if (id is null) return (null, new("no_identity", "The sign-in did not say who you are."));
                var tenant = Claim("tid");
                if (options.TenantId is { Length: > 0 } && tenant is not null &&
                    !string.Equals(tenant, options.TenantId, StringComparison.OrdinalIgnoreCase))
                    return (null, new("wrong_account", "That account belongs to a different organisation."));
                id = "m-" + id;
            }

            if (domain is not null && (email is null || !email.EndsWith("@" + domain, StringComparison.Ordinal)))
                return (null, NotInDomain(domain));

            var isAdmin = (email is not null && options.AdminEmails.Contains(email)) ||
                          (options.IsMicrosoft && principal.FindAll("roles").Any(c => c.Value == options.AdminRole));
            return (new WorkspaceUser(id, name, email, isAdmin), null);
        }

        private static WorkspaceDenied NotInDomain(string domain) =>
            new("wrong_account", $"That account is not part of {domain}. Sign in with your work account.");
    }
}
