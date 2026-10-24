using System.IdentityModel.Tokens.Jwt;
using System.Security.Claims;
using System.Security.Cryptography;
using System.Text;
using Microsoft.Extensions.Options;
using Microsoft.IdentityModel.Tokens;
using PullPrintingBackend.Models;

namespace PullPrintingBackend.Services
{
    public static class Claims
    {
        public const string UserId = "uid";
        public const string Name = "name";
        public const string Role = "role";
        public const string Kind = "kind";
        public const string AdminRole = "Admin";
        public const string UserRole = "User";
        public const string AdminPolicy = "Admin";

        /// <summary>Token made by demo sign-in.</summary>
        public const string DemoKind = "demo";

        /// <summary>Token made after a work account (Microsoft or Google) signed in.</summary>
        public const string WorkspaceKind = "workspace";
    }

    public class DemoOptions
    {
        /// <summary>Lets anyone sign in to a private sandbox. Turn off for anything real.</summary>
        public bool Enabled { get; set; }
    }

    public class AuthOptions
    {
        /// <summary>At least 32 characters. When empty a random key is made at start-up and everyone is signed out on restart.</summary>
        public string? SigningKey { get; set; }
    }

    /// <summary>
    /// Makes and describes the server's own session tokens. Whoever signs in, with a demo sandbox or a
    /// work account, gets the same kind of token, so nothing else needs to know how they signed in.
    /// </summary>
    public class AppTokenService
    {
        public const string Issuer = "pullprint";
        public const string Audience = "pullprint";

        public SymmetricSecurityKey Key { get; }

        /// <summary>True when no signing key was set, so tokens stop working at every restart.</summary>
        public bool UsesRandomKey { get; }

        public AppTokenService(IOptions<AuthOptions> options, IConfiguration config, ILogger<AppTokenService> log)
        {
            // "Demo:SigningKey" is the older name for the same setting.
            var configured = options.Value.SigningKey;
            if (string.IsNullOrWhiteSpace(configured)) configured = config["Demo:SigningKey"];

            if (string.IsNullOrWhiteSpace(configured))
            {
                log.LogInformation("Auth:SigningKey is not set, using a random key. Everyone is signed out when the app restarts.");
                Key = new SymmetricSecurityKey(RandomNumberGenerator.GetBytes(48));
                UsesRandomKey = true;
            }
            else
            {
                if (configured.Length < 32)
                    throw new InvalidOperationException("Auth:SigningKey must be at least 32 characters.");
                Key = new SymmetricSecurityKey(Encoding.UTF8.GetBytes(configured));
            }
        }

        public string Create(UserSummary user, string kind, TimeProvider time)
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
                    new Claim(Claims.Kind, kind),
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
