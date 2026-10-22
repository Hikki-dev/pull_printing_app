using Microsoft.AspNetCore.Authentication;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.RateLimiting;
using Microsoft.Extensions.Options;
using PullPrintingBackend.Models;
using PullPrintingBackend.Services;

namespace PullPrintingBackend.Controllers
{
    [ApiController]
    [Route("api/[controller]")]
    [RequestSizeLimit(16_384)]
    public class AuthController : ControllerBase
    {
        public const string WorkspaceScheme = "Workspace";
        public const string ExternalScheme = "External";

        private readonly IPrintStore _store;
        private readonly AppTokenService _tokens;
        private readonly DemoOptions _demo;
        private readonly WorkspaceOptions _workspace;
        private readonly TimeProvider _time;

        public AuthController(IPrintStore store, AppTokenService tokens, IOptions<DemoOptions> demo,
            IOptions<WorkspaceOptions> workspace, TimeProvider time)
        {
            _store = store;
            _tokens = tokens;
            _demo = demo.Value;
            _workspace = workspace.Value;
            _time = time;
        }

        /// <summary>What the sign-in screen needs before anyone is signed in: which work account to offer.</summary>
        [HttpGet("config")]
        public AuthConfigDto Config() => new(
            _workspace.Enabled ? _workspace.ProviderName!.ToLowerInvariant() : "none",
            _workspace.Enabled ? _workspace.ProviderName : null,
            _workspace.Enabled ? _workspace.Domain : null,
            _demo.Enabled);

        /// <summary>
        /// Demo sign-in: creates a private sandbox with sample documents and returns a token for it.
        /// Not found unless <c>Demo:Enabled</c> is true.
        /// </summary>
        [HttpPost("demo-login")]
        [EnableRateLimiting("login")]
        public ActionResult<SessionDto> DemoLogin([FromBody] DemoLoginRequest? request)
        {
            if (!_demo.Enabled) return NotFound();
            var user = _store.CreateDemoUser(request?.Admin ?? false);
            return new SessionDto(_tokens.Create(user, Claims.DemoKind, _time), user.UserId, user.Name, user.IsAdmin);
        }

        /// <summary>Who the token belongs to.</summary>
        [HttpGet("me")]
        [Authorize]
        public MeDto Me() => new(
            User.UserId(),
            User.FindFirst(Claims.Name)?.Value ?? "Signed-in user",
            User.IsInRole(Claims.AdminRole));

        /// <summary>
        /// Starts sign-in with the organisation's work account: sends the browser to Microsoft or Google.
        /// <paramref name="returnTo"/> is a path on this site to come back to, such as <c>/?printer=abc</c>.
        /// </summary>
        [HttpGet("login")]
        [EnableRateLimiting("login")]
        public IActionResult Login([FromQuery] string? returnTo)
        {
            if (!_workspace.Enabled) return NotFound();
            var properties = new AuthenticationProperties { RedirectUri = "/api/auth/complete" };
            properties.Items["returnTo"] = SafeReturnPath(returnTo);
            return Challenge(properties, WorkspaceScheme);
        }

        /// <summary>
        /// Where the browser lands after the work account signed in. Checks the account belongs to this
        /// organisation, then hands the app a session token in the address fragment, which never reaches a server log.
        /// </summary>
        [HttpGet("complete")]
        public async Task<IActionResult> Complete()
        {
            var result = await HttpContext.AuthenticateAsync(ExternalScheme);
            await HttpContext.SignOutAsync(ExternalScheme);

            var returnTo = SafeReturnPath(result.Properties?.Items.TryGetValue("returnTo", out var saved) == true ? saved : null);
            if (!result.Succeeded || result.Principal is null || !_workspace.Enabled)
                return Redirect(returnTo + "#error=sign_in_failed");

            var (person, denied) = WorkspaceIdentity.Map(_workspace, result.Principal);
            if (person is null) return Redirect(returnTo + "#error=" + (denied?.Code ?? "sign_in_failed"));

            var user = _store.EnsureUser(person.Id, person.Name, person.IsAdmin, person.Email);
            var token = _tokens.Create(user, Claims.WorkspaceKind, _time);
            return Redirect(returnTo + "#token=" + token);
        }

        /// <summary>Only paths on this site are allowed, so sign-in cannot be used to send people elsewhere.</summary>
        public static string SafeReturnPath(string? path)
        {
            if (string.IsNullOrEmpty(path) || path.Length > 200) return "/";
            if (path[0] != '/' || path.StartsWith("//") || path.Contains('\\')) return "/";
            if (path.Any(char.IsControl)) return "/";
            var hash = path.IndexOf('#');
            return hash >= 0 ? path[..hash] : path;
        }
    }
}
