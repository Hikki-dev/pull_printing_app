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
    public class AuthController : ControllerBase
    {
        private readonly IPrintStore _store;
        private readonly DemoTokenService _tokens;
        private readonly DemoOptions _demo;
        private readonly TimeProvider _time;

        public AuthController(IPrintStore store, DemoTokenService tokens, IOptions<DemoOptions> demo, TimeProvider time)
        {
            _store = store;
            _tokens = tokens;
            _demo = demo.Value;
            _time = time;
        }

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
            return new SessionDto(_tokens.Create(user, _time), user.UserId, user.Name, user.IsAdmin);
        }

        /// <summary>Who the token belongs to. Works for demo and Microsoft sign-in.</summary>
        [HttpGet("me")]
        [Authorize]
        public MeDto Me() => new(
            User.UserId(),
            User.FindFirst(Claims.Name)?.Value ?? "Signed-in user",
            User.IsInRole(Claims.AdminRole));
    }
}
