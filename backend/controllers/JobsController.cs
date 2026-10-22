using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Extensions.Options;
using PullPrintingBackend.Models;
using PullPrintingBackend.Services;

namespace PullPrintingBackend.Controllers
{
    [ApiController]
    [Route("api/[controller]")]
    [Authorize]
    public class JobsController : ControllerBase
    {
        private readonly IPrintStore _store;
        private readonly DemoOptions _demo;

        public JobsController(IPrintStore store, IOptions<DemoOptions> demo)
        {
            _store = store;
            _demo = demo.Value;
        }

        /// <summary>Every job in the administrator's own group. Administrators only.</summary>
        [HttpGet]
        [Authorize(Policy = Claims.AdminPolicy)]
        public IReadOnlyList<PrintJob> All() => _store.AllJobs(User.UserId());

        /// <summary>The signed-in user's documents that are waiting to print, newest first.</summary>
        [HttpGet("held")]
        public IReadOnlyList<PrintJob> Held() => _store.HeldJobs(User.UserId());

        /// <summary>Pages used and allowed this month for the signed-in user.</summary>
        [HttpGet("quota")]
        public ActionResult<Quota> MyQuota() =>
            _store.GetQuota(User.UserId()) is { } quota ? quota : NotFound();

        /// <summary>
        /// Prints the chosen documents. Only the caller's own waiting documents are used,
        /// and nothing prints if the total would go over their quota.
        /// </summary>
        [HttpPost("release")]
        public ActionResult<ReleaseResponse> Release([FromBody] ReleaseRequest request)
        {
            var ids = new List<string>(request.JobIds ?? new List<string>());
            if (request.JobId is { Length: > 0 }) ids.Add(request.JobId);
            if (ids.Count == 0)
                return BadRequest(new ApiError("no_jobs", "Choose at least one document."));

            var result = _store.Release(User.UserId(), ids);
            return result.Outcome switch
            {
                ReleaseOutcome.Printed => new ReleaseResponse(
                    result.Printed.Select(j => j.Id).ToList(), result.Pages, result.Quota),
                ReleaseOutcome.OverQuota => Conflict(new ApiError(
                    "quota_exceeded",
                    $"Over your limit by {result.PagesOver} pages.",
                    result.PagesOver)),
                _ => NotFound(new ApiError("not_found", "Those documents are not waiting to print.")),
            };
        }

        /// <summary>Demo only: sends one more sample document to the signed-in user.</summary>
        [HttpPost("sample")]
        public ActionResult<PrintJob> Sample()
        {
            if (!_demo.Enabled) return NotFound();
            var job = _store.AddSample(User.UserId());
            return job is null
                ? Conflict(new ApiError("no_more_samples", "You already have plenty of documents waiting."))
                : job;
        }
    }
}
