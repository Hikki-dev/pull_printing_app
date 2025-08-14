using Microsoft.AspNetCore.Mvc;
using PullPrintingBackend.Services;

[ApiController]
[Route("api/[controller]")]
public class AuthController : ControllerBase
{
    private readonly AzureAuthService _authService;
    public AuthController(AzureAuthService authService) => _authService = authService;

    [HttpPost("login")]
    public IActionResult Login([FromBody] string token)
    {
        if (_authService.ValidateToken(token))
            return Ok(new { message = "Token valid" });
        return Unauthorized();
    }
}
