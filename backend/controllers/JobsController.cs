using Microsoft.AspNetCore.Mvc;
using PullPrintingBackend.Models;
using PullPrintingBackend.Services;

[ApiController]
[Route("api/[controller]")]
public class JobsController : ControllerBase
{
    private readonly PrintService _printService;
    private readonly UserService _userService;
    private static List<PrintJob> _jobs = new();

    public JobsController(PrintService printService, UserService userService)
    {
        _printService = printService;
        _userService = userService;
    }

    [HttpGet]
    public IEnumerable<PrintJob> GetJobs() => _jobs;

    [HttpPost("release")]
    public IActionResult ReleaseJob([FromBody] PrintJob job)
    {
        var user = _userService.GetUserById(job.UserId);
        if (user.PrintQuota <= 0) return Forbid("Quota exceeded");
        _printService.ReleaseJob(job, "DefaultPrinter");
        user.PrintQuota--;
        return Ok();
    }
}
