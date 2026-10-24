using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Extensions.Options;
using PullPrintingBackend.Models;
using PullPrintingBackend.Services;

namespace PullPrintingBackend.Controllers
{
    [ApiController]
    [Route("api/[controller]")]
    [Authorize(Policy = Claims.AdminPolicy)]
    [RequestSizeLimit(16_384)]
    public class AdminController : ControllerBase
    {
        public const int MaxQuota = 10_000;

        private readonly IPrintStore _store;
        private readonly WorkspaceOptions _workspace;
        private readonly DemoOptions _demo;
        private readonly AppTokenService _tokens;

        public AdminController(IPrintStore store, IOptions<WorkspaceOptions> workspace,
            IOptions<DemoOptions> demo, AppTokenService tokens)
        {
            _store = store;
            _workspace = workspace.Value;
            _demo = demo.Value;
            _tokens = tokens;
        }

        // ---- the setup check ---------------------------------------------------

        /// <summary>
        /// A plain summary of how this server is set up and anything that needs attention,
        /// including the address to register with Microsoft or Google.
        /// </summary>
        [HttpGet("setup")]
        public SetupDto Setup()
        {
            var me = User.UserId();
            var warnings = new List<string>();
            foreach (var problem in _workspace.Problems()) warnings.Add("Work account sign-in is not ready. " + problem);
            if (_workspace.Enabled && _demo.Enabled)
                warnings.Add("Demo sign-in is on, so anyone on the internet can sign in to a sample sandbox. Turn it off for real use (Demo__Enabled=false).");
            var printers = _store.Printers(me);
            if (printers.Count == 0) warnings.Add("No printers yet. Add one so people can print.");
            else if (printers.All(p => !p.Enabled)) warnings.Add("Every printer is switched off, so nobody can print.");
            if (_workspace.Enabled && _tokens.UsesRandomKey)
                warnings.Add("Auth__SigningKey is not set, so everyone is signed out whenever the server restarts.");

            var provider = _workspace.Enabled ? _workspace.ProviderName!
                : _demo.Enabled ? "Demo only"
                : "None";
            return new SetupDto(
                provider,
                _workspace.Enabled ? _workspace.ProviderName : null,
                _workspace.Enabled ? _workspace.Domain : null,
                _demo.Enabled,
                _store.DefaultQuota(me) ?? PrintStore.DefaultQuotaPages,
                _store.Users(me).Count,
                printers.Count,
                $"{Request.Scheme}://{Request.Host}/api/auth/callback",
                warnings);
        }

        // ---- people and quotas -------------------------------------------------

        [HttpGet("users")]
        public IEnumerable<UserQuotaDto> Users() =>
            _store.Users(User.UserId()).Select(u => new UserQuotaDto(u.UserId, u.Name, u.Quota, u.Email));

        [HttpPost("set-quota")]
        public IActionResult SetQuota([FromBody] SetQuotaRequest request)
        {
            if (string.IsNullOrWhiteSpace(request.UserId))
                return BadRequest(new ApiError("bad_request", "userId is required."));
            if (InvalidQuota(request.Quota, out var problem)) return problem!;
            return _store.SetQuota(User.UserId(), request.UserId, request.Quota)
                ? Ok()
                : NotFound(new ApiError("not_found", "No such user."));
        }

        /// <summary>The pages a month that new people start with.</summary>
        [HttpPost("default-quota")]
        public IActionResult SetDefaultQuota([FromBody] QuotaValueRequest request)
        {
            if (InvalidQuota(request.Quota, out var problem)) return problem!;
            return _store.SetDefaultQuota(User.UserId(), request.Quota) ? Ok() : NotFound();
        }

        /// <summary>Gives everyone the same pages a month, and returns how many people changed.</summary>
        [HttpPost("set-quota-all")]
        public IActionResult SetQuotaForAll([FromBody] QuotaValueRequest request)
        {
            if (InvalidQuota(request.Quota, out var problem)) return problem!;
            return Ok(new { changed = _store.SetQuotaForAll(User.UserId(), request.Quota) });
        }

        // ---- printers ----------------------------------------------------------

        [HttpPost("printers")]
        public IActionResult AddPrinter([FromBody] PrinterRequest request)
        {
            if (InvalidPrinter(request, out var problem)) return problem!;
            var printer = _store.AddPrinter(User.UserId(), request.Name!, request.Location ?? "");
            return printer is null
                ? Conflict(new ApiError("too_many", $"At most {PrintStore.MaxPrinters} printers."))
                : Ok(printer);
        }

        [HttpPut("printers/{id}")]
        public IActionResult UpdatePrinter(string id, [FromBody] PrinterRequest request)
        {
            if (InvalidPrinter(request, out var problem)) return problem!;
            return _store.UpdatePrinter(User.UserId(), id, request.Name!, request.Location ?? "", request.Enabled ?? true)
                ? Ok()
                : NotFound(new ApiError("not_found", "No such printer."));
        }

        [HttpDelete("printers/{id}")]
        public IActionResult DeletePrinter(string id) =>
            _store.DeletePrinter(User.UserId(), id) ? Ok() : NotFound(new ApiError("not_found", "No such printer."));

        // ---- checks ------------------------------------------------------------

        private static bool InvalidQuota(int quota, out IActionResult? problem)
        {
            problem = quota is < 0 or > MaxQuota
                ? new BadRequestObjectResult(new ApiError("bad_request", $"Quota must be between 0 and {MaxQuota} pages."))
                : null;
            return problem is not null;
        }

        private static bool InvalidPrinter(PrinterRequest request, out IActionResult? problem)
        {
            problem = null;
            if (string.IsNullOrWhiteSpace(request.Name))
                problem = new BadRequestObjectResult(new ApiError("bad_request", "A printer needs a name."));
            else if (request.Name.Length > 60 || (request.Location?.Length ?? 0) > 100)
                problem = new BadRequestObjectResult(new ApiError("bad_request", "Name up to 60 characters, location up to 100."));
            return problem is not null;
        }
    }
}
