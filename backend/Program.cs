using System.Security.Claims;
using System.Threading.RateLimiting;
using Microsoft.AspNetCore.Authentication.Cookies;
using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.AspNetCore.Authentication.OpenIdConnect;
using Microsoft.AspNetCore.HttpOverrides;
using Microsoft.AspNetCore.RateLimiting;
using Microsoft.Extensions.Options;
using Microsoft.IdentityModel.Protocols.OpenIdConnect;
using Microsoft.IdentityModel.Tokens;
using PullPrintingBackend.Controllers;
using PullPrintingBackend.Services;

var builder = WebApplication.CreateBuilder(args);

builder.Services.Configure<DemoOptions>(builder.Configuration.GetSection("Demo"));
builder.Services.Configure<AuthOptions>(builder.Configuration.GetSection("Auth"));
builder.Services.Configure<WorkspaceOptions>(builder.Configuration.GetSection("Workspace"));

builder.Services.AddSingleton(TimeProvider.System);
builder.Services.AddSingleton<IPrintDispatcher, SimulatedPrintDispatcher>();
builder.Services.AddSingleton<IPrintStore, PrintStore>();
builder.Services.AddSingleton<AppTokenService>();
builder.Services.AddHostedService<DemoCleanupService>();
builder.Services.AddControllers();

// --- Authentication -------------------------------------------------------
// Everyone ends up with the server's own session token (see AppTokenService), whether they signed in
// to a demo sandbox or with their organisation's Microsoft or Google work account. The work-account
// step is a normal OpenID Connect sign-in done here on the server, so the app needs no provider SDK.
builder.Services.AddAuthentication("Bearer")
    .AddJwtBearer("Bearer", options =>
    {
        options.MapInboundClaims = false;
        options.Events = new JwtBearerEvents
        {
            OnTokenValidated = context =>
            {
                var services = context.HttpContext.RequestServices;
                var principal = context.Principal!;
                var store = services.GetRequiredService<IPrintStore>();
                var name = principal.FindFirstValue(Claims.Name) ?? "Signed-in user";
                var isAdmin = principal.IsInRole(Claims.AdminRole);
                switch (principal.FindFirstValue(Claims.Kind))
                {
                    case Claims.DemoKind when services.GetRequiredService<IOptions<DemoOptions>>().Value.Enabled:
                        store.EnsureDemoUser(principal.UserId(), name, isAdmin);
                        break;
                    case Claims.WorkspaceKind when services.GetRequiredService<IOptions<WorkspaceOptions>>().Value.Enabled:
                        store.EnsureUser(principal.UserId(), name, isAdmin);
                        break;
                    default:
                        // The way this token was issued has been switched off since.
                        context.Fail("That kind of sign-in is switched off.");
                        break;
                }
                return Task.CompletedTask;
            },
        };
    })
    .AddCookie(AuthController.ExternalScheme, options =>
    {
        // Holds who the work account said you are for the few seconds between the two redirects.
        options.Cookie.Name = ".pullprint.external";
        options.Cookie.SameSite = SameSiteMode.Lax;
        options.Cookie.SecurePolicy = CookieSecurePolicy.SameAsRequest;
        options.ExpireTimeSpan = TimeSpan.FromMinutes(5);
        options.SlidingExpiration = false;
        options.Events.OnRedirectToLogin = context =>
        {
            context.Response.StatusCode = StatusCodes.Status401Unauthorized;
            return Task.CompletedTask;
        };
    })
    // Always registered, but only used when Workspace settings are complete (see AuthController.Login).
    // Its settings are read when it is first used, so it needs nothing when the server runs on demo sign-in alone.
    .AddOpenIdConnect(AuthController.WorkspaceScheme, _ => { });

builder.Services.AddOptions<JwtBearerOptions>("Bearer")
    .Configure<AppTokenService>((options, tokens) =>
    {
        options.TokenValidationParameters = new TokenValidationParameters
        {
            ValidIssuer = AppTokenService.Issuer,
            ValidAudience = AppTokenService.Audience,
            IssuerSigningKey = tokens.Key,
            ValidAlgorithms = new[] { SecurityAlgorithms.HmacSha256 },
            NameClaimType = Claims.Name,
            RoleClaimType = Claims.Role,
            ClockSkew = TimeSpan.FromMinutes(1),
        };
    });

builder.Services.AddOptions<OpenIdConnectOptions>(AuthController.WorkspaceScheme)
    .Configure<IOptions<WorkspaceOptions>>((options, workspace) =>
    {
        var w = workspace.Value;
        options.Authority = w.EffectiveAuthority;
        options.ClientId = string.IsNullOrWhiteSpace(w.ClientId) ? "not-configured" : w.ClientId;
        options.ClientSecret = string.IsNullOrWhiteSpace(w.ClientSecret) ? "not-configured" : w.ClientSecret;
        options.RequireHttpsMetadata = w.RequireHttpsMetadata;
        options.ResponseType = OpenIdConnectResponseType.Code;
        options.UsePkce = true;
        options.CallbackPath = "/api/auth/callback";
        options.SignInScheme = AuthController.ExternalScheme;
        options.MapInboundClaims = false;
        options.SaveTokens = false;
        options.GetClaimsFromUserInfoEndpoint = false;
        options.Scope.Clear();
        options.Scope.Add("openid");
        options.Scope.Add("profile");
        options.Scope.Add("email");
        options.CorrelationCookie.SameSite = SameSiteMode.Lax;
        options.CorrelationCookie.SecurePolicy = CookieSecurePolicy.SameAsRequest;
        options.NonceCookie.SameSite = SameSiteMode.Lax;
        options.NonceCookie.SecurePolicy = CookieSecurePolicy.SameAsRequest;
        options.TokenValidationParameters.NameClaimType = Claims.Name;
        options.Events = new OpenIdConnectEvents
        {
            OnRedirectToIdentityProvider = context =>
            {
                context.ProtocolMessage.Prompt = "select_account";
                // A hint that limits the account chooser to the organisation. The server still checks the account itself.
                if (w.IsGoogle && !string.IsNullOrWhiteSpace(w.Domain))
                    context.ProtocolMessage.SetParameter("hd", w.Domain!.TrimStart('@'));
                return Task.CompletedTask;
            },
            OnRemoteFailure = context =>
            {
                context.Response.Redirect("/#error=sign_in_failed");
                context.HandleResponse();
                return Task.CompletedTask;
            },
        };
    });

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

// Anything unexpected becomes a short JSON error. Details stay in the server log, never in the reply.
app.UseExceptionHandler(errors => errors.Run(async context =>
{
    context.Response.StatusCode = StatusCodes.Status500InternalServerError;
    await context.Response.WriteAsJsonAsync(
        new PullPrintingBackend.Models.ApiError("server_error", "Something went wrong on the server. Please try again."));
}));

app.Use(async (context, next) =>
{
    var headers = context.Response.Headers;
    headers["X-Content-Type-Options"] = "nosniff";
    headers["Referrer-Policy"] = "no-referrer";
    headers["X-Frame-Options"] = "DENY";
    headers["Content-Security-Policy"] = "frame-ancestors 'none'";
    await next();
});

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

// The work-account callback only exists once Microsoft or Google sign-in is set up.
app.Use(async (context, next) =>
{
    if (context.Request.Path.StartsWithSegments("/api/auth/callback") &&
        !context.RequestServices.GetRequiredService<IOptions<WorkspaceOptions>>().Value.Enabled)
    {
        context.Response.StatusCode = StatusCodes.Status404NotFound;
        return;
    }
    await next();
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
