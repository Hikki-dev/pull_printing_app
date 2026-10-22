using System.IdentityModel.Tokens.Jwt;
using System.Security.Claims;
using System.Threading.RateLimiting;
using Microsoft.AspNetCore.Authentication;
using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.AspNetCore.HttpOverrides;
using Microsoft.AspNetCore.RateLimiting;
using Microsoft.Extensions.Options;
using Microsoft.IdentityModel.Tokens;
using PullPrintingBackend.Services;

var builder = WebApplication.CreateBuilder(args);

builder.Services.Configure<DemoOptions>(builder.Configuration.GetSection("Demo"));
var azure = builder.Configuration.GetSection("AzureAd").Get<AzureAdOptions>() ?? new AzureAdOptions();

builder.Services.AddSingleton(TimeProvider.System);
builder.Services.AddSingleton<IPrintDispatcher, SimulatedPrintDispatcher>();
builder.Services.AddSingleton<IPrintStore, PrintStore>();
builder.Services.AddSingleton<DemoTokenService>();
builder.Services.AddHostedService<DemoCleanupService>();
builder.Services.AddControllers();

// --- Authentication -------------------------------------------------------
// Two token sources behind one default scheme: tokens made by demo sign-in, and
// Microsoft Entra ID tokens when AzureAd:TenantId and AzureAd:ClientId are set.
const string smartScheme = "Smart";
const string demoScheme = "Demo";
const string entraScheme = "Entra";

var auth = builder.Services.AddAuthentication(smartScheme)
    .AddPolicyScheme(smartScheme, smartScheme, options =>
    {
        options.ForwardDefaultSelector = context =>
        {
            var header = context.Request.Headers.Authorization.ToString();
            if (azure.Enabled && header.StartsWith("Bearer ", StringComparison.OrdinalIgnoreCase))
            {
                var raw = header["Bearer ".Length..].Trim();
                var handler = new JwtSecurityTokenHandler();
                if (handler.CanReadToken(raw) && handler.ReadJwtToken(raw).Issuer != DemoTokenService.Issuer)
                    return entraScheme;
            }
            return demoScheme;
        };
    })
    .AddJwtBearer(demoScheme, options =>
    {
        options.MapInboundClaims = false;
        options.Events = new JwtBearerEvents
        {
            OnTokenValidated = context =>
            {
                var services = context.HttpContext.RequestServices;
                if (!services.GetRequiredService<IOptions<DemoOptions>>().Value.Enabled)
                {
                    context.Fail("Demo sign-in is switched off.");
                    return Task.CompletedTask;
                }
                var p = context.Principal!;
                services.GetRequiredService<IPrintStore>().EnsureDemoUser(
                    p.UserId(),
                    p.FindFirstValue(Claims.Name) ?? "Visitor",
                    p.IsInRole(Claims.AdminRole));
                return Task.CompletedTask;
            },
        };
    });

builder.Services.AddOptions<JwtBearerOptions>(demoScheme)
    .Configure<DemoTokenService>((options, tokens) =>
    {
        options.TokenValidationParameters = new TokenValidationParameters
        {
            ValidIssuer = DemoTokenService.Issuer,
            ValidAudience = DemoTokenService.Audience,
            IssuerSigningKey = tokens.Key,
            ValidAlgorithms = new[] { SecurityAlgorithms.HmacSha256 },
            NameClaimType = Claims.Name,
            RoleClaimType = Claims.Role,
            ClockSkew = TimeSpan.FromMinutes(1),
        };
    });

if (azure.Enabled)
{
    auth.AddJwtBearer(entraScheme, options =>
    {
        options.MapInboundClaims = false;
        options.Authority = $"https://login.microsoftonline.com/{azure.TenantId}/v2.0";
        options.TokenValidationParameters = new TokenValidationParameters
        {
            ValidAudiences = new[] { azure.ClientId!, $"api://{azure.ClientId}" },
            NameClaimType = Claims.Name,
            RoleClaimType = Claims.Role,
        };
        options.Events = new JwtBearerEvents
        {
            OnTokenValidated = context =>
            {
                var p = context.Principal!;
                var id = p.FindFirstValue("oid") ?? p.FindFirstValue("sub");
                if (id is null)
                {
                    context.Fail("Token has no user id.");
                    return Task.CompletedTask;
                }
                var name = p.FindFirstValue("name") ?? p.FindFirstValue("preferred_username") ?? "Signed-in user";
                var isAdmin = p.FindAll("roles").Any(c => c.Value == azure.AdminRole);

                p.AddIdentity(new ClaimsIdentity(new[]
                {
                    new Claim(Claims.UserId, id),
                    new Claim(Claims.Name, name),
                    new Claim(Claims.Role, isAdmin ? Claims.AdminRole : Claims.UserRole),
                }, entraScheme, Claims.Name, Claims.Role));

                context.HttpContext.RequestServices.GetRequiredService<IPrintStore>().EnsureUser(id, name, isAdmin);
                return Task.CompletedTask;
            },
        };
    });
}

builder.Services.AddAuthorization(options =>
    options.AddPolicy(Claims.AdminPolicy, policy => policy.RequireRole(Claims.AdminRole)));

// --- Abuse limits ---------------------------------------------------------
builder.Services.AddRateLimiter(_ => { });
builder.Services.AddOptions<RateLimiterOptions>().Configure<IConfiguration>((options, config) =>
{
    var perMinute = config.GetValue("RateLimit:PerMinute", 300);
    var loginsPerMinute = config.GetValue("RateLimit:LoginPerMinute", 20);
    options.RejectionStatusCode = StatusCodes.Status429TooManyRequests;
    options.GlobalLimiter = PartitionedRateLimiter.Create<HttpContext, string>(context =>
        RateLimitPartition.GetFixedWindowLimiter(
            context.Connection.RemoteIpAddress?.ToString() ?? "unknown",
            _ => new FixedWindowRateLimiterOptions { PermitLimit = perMinute, Window = TimeSpan.FromMinutes(1) }));
    options.AddPolicy("login", context =>
        RateLimitPartition.GetFixedWindowLimiter(
            context.Connection.RemoteIpAddress?.ToString() ?? "unknown",
            _ => new FixedWindowRateLimiterOptions { PermitLimit = loginsPerMinute, Window = TimeSpan.FromMinutes(1) }));
});

// The app normally sits behind the host's proxy, which adds the real client address.
builder.Services.Configure<ForwardedHeadersOptions>(options =>
{
    options.ForwardedHeaders = ForwardedHeaders.XForwardedFor | ForwardedHeaders.XForwardedProto;
    options.KnownNetworks.Clear();
    options.KnownProxies.Clear();
});

// Only needed when the web app is served from a different address, such as `flutter run`.
if (builder.Configuration.GetValue<bool>("Cors:AllowAnyOrigin"))
{
    builder.Services.AddCors(options =>
        options.AddDefaultPolicy(policy => policy.AllowAnyOrigin().AllowAnyHeader().AllowAnyMethod()));
}

var app = builder.Build();

app.UseForwardedHeaders();

// The Flutter web build is served from wwwroot. Files that change on every deploy must not be cached.
app.UseDefaultFiles();
app.UseStaticFiles(new StaticFileOptions
{
    OnPrepareResponse = context =>
    {
        var name = context.File.Name;
        if (name is "index.html" or "flutter_service_worker.js" or "flutter_bootstrap.js" or "version.json")
            context.Context.Response.Headers.CacheControl = "no-cache";
    },
});

app.UseRouting();
if (builder.Configuration.GetValue<bool>("Cors:AllowAnyOrigin")) app.UseCors();
app.UseRateLimiter();
app.UseAuthentication();
app.UseAuthorization();

app.MapGet("/healthz", () => Results.Ok(new { status = "ok" })).DisableRateLimiting();
app.MapControllers();

if (app.Environment.WebRootFileProvider.GetFileInfo("index.html").Exists)
    app.MapFallbackToFile("/{*path:regex(^(?!api/).*$)}", "index.html");

app.Run();

/// <summary>Lets the integration tests start the app.</summary>
public partial class Program { }
