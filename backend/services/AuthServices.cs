using System.IdentityModel.Tokens.Jwt;
using System.Security.Claims;
using System.Security.Cryptography;
using System.Text;
using Microsoft.IdentityModel.Tokens;
using PullPrintingBackend.Models;

namespace PullPrintingBackend.Services
{
    public static class Claims
    {
        public const string UserId = "uid";
        public const string Name = "name";
        public const string Role = "role";
        public const string AdminRole = "Admin";
        public const string UserRole = "User";
        public const string AdminPolicy = "Admin";
    }

    public class DemoOptions
    {
        /// <summary>Lets anyone sign in to a private sandbox. Turn off for anything real.</summary>
        public bool Enabled { get; set; }

        /// <summary>At least 32 characters. When empty a random key is made at start-up.</summary>
        public string? SigningKey { get; set; }
    }

    public class AzureAdOptions
    {
        public string? TenantId { get; set; }
        public string? ClientId { get; set; }

        /// <summary>App role that makes someone an administrator.</summary>
        public string AdminRole { get; set; } = "PullPrint.Admin";

        public bool Enabled =>
            !string.IsNullOrWhiteSpace(TenantId) && !string.IsNullOrWhiteSpace(ClientId)
            && !TenantId!.StartsWith("YOUR_") && !ClientId!.StartsWith("YOUR_");
    }

    /// <summary>Issues and describes the tokens used by demo sign-in.</summary>
    public class DemoTokenService
    {
        public const string Issuer = "pullprint-demo";
        public const string Audience = "pullprint-demo";

        public SymmetricSecurityKey Key { get; }

        public DemoTokenService(Microsoft.Extensions.Options.IOptions<DemoOptions> options, ILogger<DemoTokenService> log)
        {
            var configured = options.Value.SigningKey;
            if (string.IsNullOrWhiteSpace(configured))
            {
                log.LogInformation("Demo:SigningKey is not set, using a random key. Tokens stop working when the app restarts.");
                Key = new SymmetricSecurityKey(RandomNumberGenerator.GetBytes(48));
            }
            else
            {
                if (configured.Length < 32)
                    throw new InvalidOperationException("Demo:SigningKey must be at least 32 characters.");
                Key = new SymmetricSecurityKey(Encoding.UTF8.GetBytes(configured));
            }
        }

        public string Create(UserSummary user, TimeProvider time)
        {
            var now = time.GetUtcNow();
            var token = new JwtSecurityToken(
                issuer: Issuer,
                audience: Audience,
                claims: new[]
                {
                    new Claim(Claims.UserId, user.UserId),
                    new Claim(Claims.Name, user.Name),
                    new Claim(Claims.Role, user.IsAdmin ? Claims.AdminRole : Claims.UserRole),
                },
                notBefore: now.UtcDateTime,
                expires: now.AddHours(8).UtcDateTime,
                signingCredentials: new SigningCredentials(Key, SecurityAlgorithms.HmacSha256));
            return new JwtSecurityTokenHandler().WriteToken(token);
        }
    }

    public static class ControllerUser
    {
        public static string UserId(this ClaimsPrincipal user) =>
            user.FindFirstValue(Claims.UserId) ?? throw new InvalidOperationException("Signed-in user has no id.");
    }
}
