using Microsoft.AspNetCore.Mvc;
using PullPrintingBackend.Services;

[ApiController]
[Route("api/[controller]")]
public class AdminController : ControllerBase
{
    private readonly UserService _userService;
    public AdminController(UserService userService) => _userService = userService;

    [HttpPost("set-quota")]
    public IActionResult SetQuota([FromBody] dynamic payload)
    {
        string userId = payload.userId;
        int quota = payload.quota;
        _userService.UpdateQuota(userId, quota);
        return Ok();
    }
}
