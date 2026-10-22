using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using PullPrintingBackend.Models;
using PullPrintingBackend.Services;

namespace PullPrintingBackend.Controllers
{
    [ApiController]
    [Route("api/[controller]")]
    [Authorize(Policy = Claims.AdminPolicy)]
    public class AdminController : ControllerBase
    {
        public const int MaxQuota = 10_000;

        private readonly IPrintStore _store;
        public AdminController(IPrintStore store) => _store = store;

        [HttpGet("users")]
        public IEnumerable<UserQuotaDto> Users() =>
            _store.Users(User.UserId()).Select(u => new UserQuotaDto(u.UserId, u.Name, u.Quota));

        [HttpPost("set-quota")]
        public IActionResult SetQuota([FromBody] SetQuotaRequest request)
        {
            if (string.IsNullOrWhiteSpace(request.UserId))
                return BadRequest(new ApiError("bad_request", "userId is required."));
            if (request.Quota is < 0 or > MaxQuota)
                return BadRequest(new ApiError("bad_request", $"Quota must be between 0 and {MaxQuota} pages."));
            return _store.SetQuota(User.UserId(), request.UserId, request.Quota)
                ? Ok()
                : NotFound(new ApiError("not_found", "No such user."));
        }
    }
}
