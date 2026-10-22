using System.IdentityModel.Tokens.Jwt;
using System.Net;
using System.Net.Http.Headers;
using System.Net.Http.Json;
using System.Security.Claims;
using System.Security.Cryptography;
using System.Text;
using System.Text.Json;
using Microsoft.AspNetCore.Authentication.OpenIdConnect;
using Microsoft.AspNetCore.Hosting;
using Microsoft.AspNetCore.Mvc.Testing;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.IdentityModel.Tokens;
using PullPrintingBackend.Controllers;
using PullPrintingBackend.Services;

namespace PullPrintingBackend.Tests;

// ---- the rules that decide whether a work account is let in ---------------

public class WorkspaceRuleTests
{
    private static ClaimsPrincipal Account(params (string Type, string Value)[] claims) =>
        new(new ClaimsIdentity(claims.Select(c => new Claim(c.Type, c.Value)), "test"));

    private static WorkspaceOptions Google(string? admins = null) => new()
    {
        Provider = "Google", ClientId = "c", ClientSecret = "s", Domain = "example.com", Admins = admins,
    };

    private static WorkspaceOptions Microsoft(string? domain = null, string? admins = null) => new()
    {
        Provider = "Microsoft", ClientId = "c", ClientSecret = "s", TenantId = "tenant-1", Domain = domain, Admins = admins,
    };

    [Fact]
    public void A_Google_account_in_the_domain_is_let_in()
    {
        var (user, denied) = WorkspaceIdentity.Map(Google(), Account(
            ("sub", "123"), ("email", "Pat.Doe@Example.com"), ("email_verified", "true"), ("hd", "example.com"), ("name", "Pat Doe")));

        Assert.Null(denied);
        Assert.Equal("g-123", user!.Id);
        Assert.Equal("Pat Doe", user.Name);
        Assert.Equal("pat.doe@example.com", user.Email);
        Assert.False(user.IsAdmin);
    }

    [Theory]
    [InlineData("boss@example.com")]
    [InlineData("Boss@Example.com")]
    [InlineData("other@example.com, boss@example.com")]
    [InlineData("other@example.com;boss@example.com")]
    [InlineData("other@example.com boss@example.com")]
    public void Administrators_are_found_by_email_however_the_list_is_written(string admins)
    {
        var (user, _) = WorkspaceIdentity.Map(Google(admins), Account(
            ("sub", "1"), ("email", "boss@example.com"), ("email_verified", "true"), ("hd", "example.com")));
        Assert.True(user!.IsAdmin);
    }

    [Fact]
    public void A_personal_Google_account_is_turned_away()
    {
        // Personal accounts have no "hd" (hosted domain) claim.
        var (user, denied) = WorkspaceIdentity.Map(Google(), Account(
            ("sub", "1"), ("email", "pat@gmail.com"), ("email_verified", "true")));
        Assert.Null(user);
        Assert.Equal("wrong_account", denied!.Code);
        Assert.Contains("example.com", denied.Message);
    }

    [Fact]
    public void A_Google_account_from_another_organisation_is_turned_away()
    {
        var (user, denied) = WorkspaceIdentity.Map(Google(), Account(
            ("sub", "1"), ("email", "pat@other.org"), ("email_verified", "true"), ("hd", "other.org")));
        Assert.Null(user);
        Assert.Equal("wrong_account", denied!.Code);
    }

    [Fact]
    public void An_unverified_Google_email_is_turned_away()
    {
        var (user, denied) = WorkspaceIdentity.Map(Google(), Account(
            ("sub", "1"), ("email", "pat@example.com"), ("email_verified", "false"), ("hd", "example.com")));
        Assert.Null(user);
        Assert.Equal("unverified_email", denied!.Code);
    }

    [Fact]
    public void A_Google_domain_claim_alone_is_not_enough_the_email_must_match_too()
    {
        var (user, denied) = WorkspaceIdentity.Map(Google(), Account(
            ("sub", "1"), ("email", "pat@evil.test"), ("email_verified", "true"), ("hd", "example.com")));
        Assert.Null(user);
        Assert.Equal("wrong_account", denied!.Code);
    }

    [Fact]
    public void A_Microsoft_account_in_the_tenant_is_let_in_and_the_app_role_makes_an_administrator()
    {
        var (user, denied) = WorkspaceIdentity.Map(Microsoft(), Account(
            ("oid", "abc"), ("tid", "tenant-1"), ("preferred_username", "Pat@Contoso.com"), ("name", "Pat Doe"), ("roles", "PullPrint.Admin")));

        Assert.Null(denied);
        Assert.Equal("m-abc", user!.Id);
        Assert.Equal("pat@contoso.com", user.Email);
        Assert.True(user.IsAdmin);
    }

    [Fact]
    public void A_Microsoft_account_from_another_tenant_is_turned_away()
    {
        var (user, denied) = WorkspaceIdentity.Map(Microsoft(), Account(
            ("oid", "abc"), ("tid", "someone-else"), ("preferred_username", "pat@contoso.com")));
        Assert.Null(user);
        Assert.Equal("wrong_account", denied!.Code);
    }

    [Fact]
    public void Microsoft_sign_in_can_be_limited_to_one_email_domain()
    {
        var options = Microsoft(domain: "contoso.com");
        var inside = WorkspaceIdentity.Map(options, Account(("oid", "1"), ("tid", "tenant-1"), ("preferred_username", "a@contoso.com")));
        var guest = WorkspaceIdentity.Map(options, Account(("oid", "2"), ("tid", "tenant-1"), ("preferred_username", "b@partner.org")));
        var noEmail = WorkspaceIdentity.Map(options, Account(("oid", "3"), ("tid", "tenant-1")));

        Assert.NotNull(inside.User);
        Assert.Equal("wrong_account", guest.Denied!.Code);
        Assert.Equal("wrong_account", noEmail.Denied!.Code);
    }

    [Fact]
    public void An_account_with_no_identity_is_turned_away()
    {
        Assert.Equal("no_identity", WorkspaceIdentity.Map(Microsoft(), Account(("name", "x"))).Denied!.Code);
        Assert.Equal("no_identity", WorkspaceIdentity.Map(Google(), Account(("name", "x"))).Denied!.Code);
    }

    [Fact]
    public void Accounts_from_different_providers_never_share_an_id()
    {
        var google = WorkspaceIdentity.Map(Google(), Account(("sub", "42"), ("email", "a@example.com"), ("email_verified", "true"), ("hd", "example.com")));
        var microsoft = WorkspaceIdentity.Map(Microsoft(), Account(("oid", "42"), ("tid", "tenant-1")));
        Assert.NotEqual(google.User!.Id, microsoft.User!.Id);
    }
}

public class WorkspaceSettingsTests
{
    [Fact]
    public void Nothing_is_wrong_when_nothing_is_set_up()
    {
        var options = new WorkspaceOptions();
        Assert.False(options.IsConfigured);
        Assert.False(options.Enabled);
        Assert.Empty(options.Problems());
    }

    [Fact]
    public void Missing_pieces_are_named_in_plain_words()
    {
        var google = new WorkspaceOptions { Provider = "Google" }.Problems();
        Assert.Contains(google, p => p.Contains("Workspace__ClientId"));
        Assert.Contains(google, p => p.Contains("Workspace__ClientSecret"));
        Assert.Contains(google, p => p.Contains("Workspace__Domain") && p.Contains("any Google account"));

        var microsoft = new WorkspaceOptions { Provider = "Microsoft", ClientId = "c", ClientSecret = "s" }.Problems();
        Assert.Single(microsoft);
        Assert.Contains("Workspace__TenantId", microsoft[0]);

        Assert.Contains(new WorkspaceOptions { Provider = "Okta", ClientId = "c", ClientSecret = "s" }.Problems(),
            p => p.Contains("Microsoft or Google"));
    }

    [Fact]
    public void A_complete_set_is_enabled_and_names_the_right_sign_in_address()
    {
        var google = new WorkspaceOptions { Provider = "google", ClientId = "c", ClientSecret = "s", Domain = "example.com" };
        Assert.True(google.Enabled);
        Assert.Equal("Google", google.ProviderName);
        Assert.Equal("https://accounts.google.com", google.EffectiveAuthority);

        var microsoft = new WorkspaceOptions { Provider = "MICROSOFT", ClientId = "c", ClientSecret = "s", TenantId = "t-1" };
        Assert.True(microsoft.Enabled);
        Assert.Equal("https://login.microsoftonline.com/t-1/v2.0", microsoft.EffectiveAuthority);
    }

    [Theory]
    [InlineData("/", "/")]
    [InlineData(null, "/")]
    [InlineData("", "/")]
    [InlineData("/?printer=abc123", "/?printer=abc123")]
    [InlineData("/panel?printer=abc#frag", "/panel?printer=abc")]
    [InlineData("//evil.example", "/")]
    [InlineData("https://evil.example", "/")]
    [InlineData("/\\evil.example", "/")]
    [InlineData("javascript:alert(1)", "/")]
    [InlineData("/ok\r\nSet-Cookie: x=1", "/")]
    public void Sign_in_can_only_send_people_back_to_a_page_on_this_site(string? asked, string expected) =>
        Assert.Equal(expected, AuthController.SafeReturnPath(asked));
}

// ---- the whole sign-in round trip, against a pretend Microsoft or Google ---

/// <summary>Plays the part of the provider's sign-in service: its settings, its keys and its token exchange.</summary>
public sealed class FakeIdentityProvider : HttpMessageHandler
{
    public const string Issuer = "https://idp.test";
    public const string ClientId = "test-client";
    public const string ClientSecret = "test-secret";

    private readonly RSA _rsa = RSA.Create(2048);
    private readonly RsaSecurityKey _key;
    private readonly Dictionary<string, (string Nonce, Claim[] Claims)> _codes = new();

    public bool SawProofKey { get; private set; }
    public int TokenRequests { get; private set; }

    public FakeIdentityProvider() => _key = new RsaSecurityKey(_rsa) { KeyId = "k1" };

    /// <summary>The person approves on the provider's page: returns the address the browser is sent back to.</summary>
    public Uri Approve(Uri authorizeAddress, params Claim[] claims)
    {
        var query = System.Web.HttpUtility.ParseQueryString(authorizeAddress.Query);
        var code = Guid.NewGuid().ToString("N");
        _codes[code] = (query["nonce"]!, claims);
        return new Uri($"{query["redirect_uri"]}?code={code}&state={Uri.EscapeDataString(query["state"]!)}");
    }

    protected override Task<HttpResponseMessage> SendAsync(HttpRequestMessage request, CancellationToken ct)
    {
        var path = request.RequestUri!.AbsolutePath;
        HttpResponseMessage Json(object body) => new(HttpStatusCode.OK)
        {
            Content = new StringContent(JsonSerializer.Serialize(body), Encoding.UTF8, "application/json"),
        };

        if (path.EndsWith("/.well-known/openid-configuration"))
            return Task.FromResult(Json(new
            {
                issuer = Issuer,
                authorization_endpoint = Issuer + "/authorize",
                token_endpoint = Issuer + "/token",
                jwks_uri = Issuer + "/jwks",
                response_types_supported = new[] { "code" },
                subject_types_supported = new[] { "public" },
                id_token_signing_alg_values_supported = new[] { "RS256" },
            }));

        if (path == "/jwks")
        {
            var p = _rsa.ExportParameters(false);
            return Task.FromResult(Json(new
            {
                keys = new[]
                {
                    new { kty = "RSA", use = "sig", alg = "RS256", kid = "k1",
                          n = Base64UrlEncoder.Encode(p.Modulus), e = Base64UrlEncoder.Encode(p.Exponent) },
                },
            }));
        }

        if (path == "/token")
        {
            TokenRequests++;
            var form = request.Content!.ReadAsStringAsync(ct).Result
                .Split('&').Select(x => x.Split('=', 2))
                .ToDictionary(x => Uri.UnescapeDataString(x[0]), x => Uri.UnescapeDataString(x[1].Replace('+', ' ')));
            if (form["client_secret"] != ClientSecret || !_codes.TryGetValue(form["code"], out var pending))
                return Task.FromResult(new HttpResponseMessage(HttpStatusCode.BadRequest)
                {
                    Content = new StringContent("{\"error\":\"invalid_grant\"}", Encoding.UTF8, "application/json"),
                });
            _codes.Remove(form["code"]);
            SawProofKey = form.ContainsKey("code_verifier");

            var claims = (pending.Claims.Any(c => c.Type == "sub") ? pending.Claims : pending.Claims.Append(new Claim("sub", "sub-" + Guid.NewGuid())))
                .Append(new Claim("nonce", pending.Nonce))
                .Append(new Claim("iat", DateTimeOffset.UtcNow.ToUnixTimeSeconds().ToString(), ClaimValueTypes.Integer64));
            var token = new JwtSecurityTokenHandler().WriteToken(new JwtSecurityToken(
                Issuer, ClientId, claims, DateTime.UtcNow.AddMinutes(-1), DateTime.UtcNow.AddMinutes(10),
                new SigningCredentials(_key, SecurityAlgorithms.RsaSha256)));
            return Task.FromResult(Json(new { id_token = token, access_token = "at", token_type = "Bearer", expires_in = 3600 }));
        }

        return Task.FromResult(new HttpResponseMessage(HttpStatusCode.NotFound));
    }
}

public class WorkspaceFactory : WebApplicationFactory<Program>
{
    public FakeIdentityProvider Idp { get; } = new();
    private readonly Dictionary<string, string?> _settings;

    public WorkspaceFactory(string provider, Dictionary<string, string?>? extra = null)
    {
        _settings = new Dictionary<string, string?>
        {
            ["Workspace:Provider"] = provider,
            ["Workspace:ClientId"] = FakeIdentityProvider.ClientId,
            ["Workspace:ClientSecret"] = FakeIdentityProvider.ClientSecret,
            ["Workspace:Authority"] = FakeIdentityProvider.Issuer,
            ["Workspace:Admins"] = "boss@example.com",
            ["Workspace:DefaultQuota"] = "40",
            ["Demo:Enabled"] = "false",
            ["Auth:SigningKey"] = ApiFactory.Key,
            ["RateLimit:LoginPerMinute"] = "1000",
            ["RateLimit:PerMinute"] = "100000",
        };
        if (provider == "Google") _settings["Workspace:Domain"] = "example.com";
        if (provider == "Microsoft") _settings["Workspace:TenantId"] = "tenant-1";
        foreach (var (key, value) in extra ?? new()) _settings[key] = value;
    }

    protected override void ConfigureWebHost(IWebHostBuilder builder)
    {
        builder.UseEnvironment("Testing");
        builder.ConfigureAppConfiguration((_, config) => config.AddInMemoryCollection(_settings));
        builder.ConfigureServices(services =>
            services.Configure<OpenIdConnectOptions>(AuthController.WorkspaceScheme, o => o.BackchannelHttpHandler = Idp));
    }

    public HttpClient Browser() => CreateClient(new WebApplicationFactoryClientOptions
    {
        AllowAutoRedirect = false,
        HandleCookies = true,
    });

    /// <summary>
    /// Plays a person signing in: the app sends them to the provider, they approve, the provider sends them
    /// back, and the app sends them on to the page with a token (or an error) in the address fragment.
    /// </summary>
    public async Task<string> SignIn(HttpClient browser, string? returnTo, params Claim[] account)
    {
        var start = await browser.GetAsync("/api/auth/login" + (returnTo is null ? "" : "?returnTo=" + Uri.EscapeDataString(returnTo)));
        Assert.Equal(HttpStatusCode.Redirect, start.StatusCode);
        Assert.StartsWith(FakeIdentityProvider.Issuer + "/authorize", start.Headers.Location!.ToString());

        var back = await browser.GetAsync(Idp.Approve(start.Headers.Location, account));
        Assert.Equal(HttpStatusCode.Redirect, back.StatusCode);

        var finish = await browser.GetAsync(back.Headers.Location);
        Assert.Equal(HttpStatusCode.Redirect, finish.StatusCode);
        return finish.Headers.Location!.OriginalString;
    }

    public static string TokenIn(string address) => address[(address.IndexOf("#token=", StringComparison.Ordinal) + 7)..];

    public HttpClient Api(string token)
    {
        var client = CreateClient();
        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", token);
        return client;
    }
}

public class WorkspaceSignInTests
{
    private static Claim[] GoogleAccount(string email, string hd = "example.com", string verified = "true", string sub = "sub-1") => new[]
    {
        new Claim("sub", sub), new Claim("email", email), new Claim("email_verified", verified),
        new Claim("hd", hd), new Claim("name", "Pat Doe"),
    };

    [Fact]
    public async Task The_sign_in_screen_is_told_which_work_account_to_offer()
    {
        using var factory = new WorkspaceFactory("Google");
        var config = await factory.CreateClient().GetFromJsonAsync<JsonElement>("/api/auth/config");
        Assert.Equal("google", config.GetProperty("provider").GetString());
        Assert.Equal("Google", config.GetProperty("providerName").GetString());
        Assert.Equal("example.com", config.GetProperty("domain").GetString());
        Assert.False(config.GetProperty("demo").GetBoolean());
    }

    [Fact]
    public async Task A_person_in_the_domain_signs_in_and_gets_a_working_session()
    {
        using var factory = new WorkspaceFactory("Google");
        var browser = factory.Browser();

        var landed = await factory.SignIn(browser, null, GoogleAccount("pat@example.com"));

        Assert.StartsWith("/#token=", landed);
        Assert.True(factory.Idp.SawProofKey, "The code exchange should use PKCE.");

        var api = factory.Api(WorkspaceFactory.TokenIn(landed));
        var me = await api.GetFromJsonAsync<JsonElement>("/api/auth/me");
        Assert.Equal("Pat Doe", me.GetProperty("name").GetString());
        Assert.False(me.GetProperty("isAdmin").GetBoolean());

        // First sign-in creates the person with the workspace's default quota, and an empty list.
        var quota = await api.GetFromJsonAsync<JsonElement>("/api/jobs/quota");
        Assert.Equal(40, quota.GetProperty("total").GetInt32());
        Assert.Equal(0, quota.GetProperty("used").GetInt32());
        Assert.Empty((await api.GetFromJsonAsync<JsonElement>("/api/jobs/held")).EnumerateArray());
    }

    [Fact]
    public async Task The_same_person_signing_in_again_is_the_same_person()
    {
        using var factory = new WorkspaceFactory("Google");
        var first = await factory.SignIn(factory.Browser(), null, GoogleAccount("pat@example.com"));
        var second = await factory.SignIn(factory.Browser(), null, GoogleAccount("pat@example.com"));

        var a = await factory.Api(WorkspaceFactory.TokenIn(first)).GetFromJsonAsync<JsonElement>("/api/auth/me");
        var b = await factory.Api(WorkspaceFactory.TokenIn(second)).GetFromJsonAsync<JsonElement>("/api/auth/me");
        Assert.Equal(a.GetProperty("userId").GetString(), b.GetProperty("userId").GetString());
    }

    [Fact]
    public async Task An_administrator_in_the_list_gets_the_administrator_screen_and_nobody_else_does()
    {
        using var factory = new WorkspaceFactory("Google");

        var boss = await factory.SignIn(factory.Browser(), null, GoogleAccount("Boss@example.com", sub: "boss"));
        var bossApi = factory.Api(WorkspaceFactory.TokenIn(boss));
        Assert.True((await bossApi.GetFromJsonAsync<JsonElement>("/api/auth/me")).GetProperty("isAdmin").GetBoolean());
        Assert.Equal(HttpStatusCode.OK, (await bossApi.GetAsync("/api/admin/setup")).StatusCode);

        var pat = await factory.SignIn(factory.Browser(), null, GoogleAccount("pat@example.com"));
        var patApi = factory.Api(WorkspaceFactory.TokenIn(pat));
        Assert.Equal(HttpStatusCode.Forbidden, (await patApi.GetAsync("/api/admin/setup")).StatusCode);
        Assert.Equal(HttpStatusCode.Forbidden, (await patApi.GetAsync("/api/admin/users")).StatusCode);
    }

    [Fact]
    public async Task The_administrator_sees_people_as_they_sign_in_and_can_set_their_quota()
    {
        using var factory = new WorkspaceFactory("Google");
        var pat = await factory.SignIn(factory.Browser(), null, GoogleAccount("pat@example.com"));
        var boss = await factory.SignIn(factory.Browser(), null, GoogleAccount("boss@example.com", sub: "boss"));
        var bossApi = factory.Api(WorkspaceFactory.TokenIn(boss));

        var people = (await bossApi.GetFromJsonAsync<JsonElement>("/api/admin/users")).EnumerateArray().ToList();
        var person = Assert.Single(people);
        Assert.Equal("pat@example.com", person.GetProperty("email").GetString());

        var id = person.GetProperty("userId").GetString();
        Assert.Equal(HttpStatusCode.OK, (await bossApi.PostAsJsonAsync("/api/admin/set-quota", new { userId = id, quota = 15 })).StatusCode);
        var quota = await factory.Api(WorkspaceFactory.TokenIn(pat)).GetFromJsonAsync<JsonElement>("/api/jobs/quota");
        Assert.Equal(15, quota.GetProperty("total").GetInt32());
    }

    [Theory]
    [InlineData("pat@gmail.com", "", "true", "wrong_account")]          // a personal account has no domain
    [InlineData("pat@other.org", "other.org", "true", "wrong_account")] // another organisation
    [InlineData("pat@example.com", "example.com", "false", "unverified_email")]
    public async Task Accounts_that_do_not_belong_are_turned_away_with_a_reason(string email, string hd, string verified, string code)
    {
        using var factory = new WorkspaceFactory("Google");
        var claims = hd == ""
            ? new[] { new Claim("sub", "x"), new Claim("email", email), new Claim("email_verified", verified), new Claim("name", "Pat") }
            : GoogleAccount(email, hd, verified);

        var landed = await factory.SignIn(factory.Browser(), null, claims);

        Assert.Equal($"/#error={code}", landed);
    }

    [Fact]
    public async Task A_turned_away_account_gets_no_session_and_is_not_added()
    {
        using var factory = new WorkspaceFactory("Google");
        await factory.SignIn(factory.Browser(), null, GoogleAccount("pat@other.org", "other.org"));

        var boss = await factory.SignIn(factory.Browser(), null, GoogleAccount("boss@example.com", sub: "boss"));
        var people = await factory.Api(WorkspaceFactory.TokenIn(boss)).GetFromJsonAsync<JsonElement>("/api/admin/users");
        Assert.Empty(people.EnumerateArray());
    }

    [Fact]
    public async Task The_page_the_person_came_from_is_kept_such_as_a_printer_panels_address()
    {
        using var factory = new WorkspaceFactory("Google");
        var landed = await factory.SignIn(factory.Browser(), "/?printer=abc123", GoogleAccount("pat@example.com"));
        Assert.StartsWith("/?printer=abc123#token=", landed);
    }

    [Theory]
    [InlineData("//evil.example/steal")]
    [InlineData("https://evil.example/")]
    public async Task Sign_in_cannot_be_used_to_send_people_to_another_site(string returnTo)
    {
        using var factory = new WorkspaceFactory("Google");
        var landed = await factory.SignIn(factory.Browser(), returnTo, GoogleAccount("pat@example.com"));
        Assert.StartsWith("/#token=", landed);
    }

    [Fact]
    public async Task A_forged_return_from_the_provider_is_refused()
    {
        using var factory = new WorkspaceFactory("Google");
        var browser = factory.Browser();
        var response = await browser.GetAsync("/api/auth/callback?code=made-up&state=made-up");
        Assert.Equal(HttpStatusCode.Redirect, response.StatusCode);
        Assert.Equal("/#error=sign_in_failed", response.Headers.Location!.OriginalString);
        Assert.Equal(0, factory.Idp.TokenRequests); // never even reached the code exchange
    }

    [Fact]
    public async Task Finishing_sign_in_without_having_started_it_gives_nothing()
    {
        using var factory = new WorkspaceFactory("Google");
        var response = await factory.Browser().GetAsync("/api/auth/complete");
        Assert.Equal("/#error=sign_in_failed", response.Headers.Location!.OriginalString);
    }

    [Fact]
    public async Task A_Microsoft_account_signs_in_and_the_app_role_makes_an_administrator()
    {
        using var factory = new WorkspaceFactory("Microsoft");
        var landed = await factory.SignIn(factory.Browser(), null,
            new Claim("oid", "o-1"), new Claim("tid", "tenant-1"), new Claim("preferred_username", "ada@contoso.com"),
            new Claim("name", "Ada Lovelace"), new Claim("roles", "PullPrint.Admin"));

        var me = await factory.Api(WorkspaceFactory.TokenIn(landed)).GetFromJsonAsync<JsonElement>("/api/auth/me");
        Assert.Equal("Ada Lovelace", me.GetProperty("name").GetString());
        Assert.True(me.GetProperty("isAdmin").GetBoolean());
    }

    [Fact]
    public async Task A_Microsoft_account_from_another_tenant_is_turned_away()
    {
        using var factory = new WorkspaceFactory("Microsoft");
        var landed = await factory.SignIn(factory.Browser(), null,
            new Claim("oid", "o-1"), new Claim("tid", "someone-elses-tenant"), new Claim("preferred_username", "x@elsewhere.com"));
        Assert.Equal("/#error=wrong_account", landed);
    }

    [Fact]
    public async Task Setup_check_names_the_address_to_register_and_what_needs_attention()
    {
        using var factory = new WorkspaceFactory("Google", new() { ["Demo:Enabled"] = "true", ["Auth:SigningKey"] = "" });
        var boss = await factory.SignIn(factory.Browser(), null, GoogleAccount("boss@example.com", sub: "boss"));
        var setup = await factory.Api(WorkspaceFactory.TokenIn(boss)).GetFromJsonAsync<JsonElement>("/api/admin/setup");

        Assert.Equal("Google", setup.GetProperty("provider").GetString());
        Assert.Equal("example.com", setup.GetProperty("domain").GetString());
        Assert.Equal(40, setup.GetProperty("defaultQuota").GetInt32());
        Assert.EndsWith("/api/auth/callback", setup.GetProperty("redirectUri").GetString());

        var warnings = string.Join("\n", setup.GetProperty("warnings").EnumerateArray().Select(w => w.GetString()));
        Assert.Contains("No printers yet", warnings);
        Assert.Contains("Demo sign-in is on", warnings);
        Assert.Contains("Auth__SigningKey is not set", warnings);
    }

    [Fact]
    public async Task A_clean_setup_has_no_warnings_once_a_printer_is_added()
    {
        using var factory = new WorkspaceFactory("Google");
        var boss = await factory.SignIn(factory.Browser(), null, GoogleAccount("boss@example.com", sub: "boss"));
        var api = factory.Api(WorkspaceFactory.TokenIn(boss));
        Assert.Equal(HttpStatusCode.OK, (await api.PostAsJsonAsync("/api/admin/printers", new { name = "Level 3 East", location = "Third floor" })).StatusCode);

        var setup = await api.GetFromJsonAsync<JsonElement>("/api/admin/setup");
        Assert.Empty(setup.GetProperty("warnings").EnumerateArray());
        Assert.Equal(1, setup.GetProperty("printers").GetInt32());
    }

    [Fact]
    public async Task Half_finished_settings_switch_work_sign_in_off_and_say_why()
    {
        using var factory = new WorkspaceFactory("Google", new() { ["Workspace:ClientSecret"] = "", ["Demo:Enabled"] = "true" });

        var config = await factory.CreateClient().GetFromJsonAsync<JsonElement>("/api/auth/config");
        Assert.Equal("none", config.GetProperty("provider").GetString());
        Assert.Equal(HttpStatusCode.NotFound, (await factory.Browser().GetAsync("/api/auth/login")).StatusCode);
        Assert.Equal(HttpStatusCode.NotFound, (await factory.Browser().GetAsync("/api/auth/callback?code=x&state=y")).StatusCode);

        // The demo still works, and its administrator is told what is wrong.
        var login = await factory.CreateClient().PostAsJsonAsync("/api/auth/demo-login", new { admin = true });
        var token = (await login.Content.ReadFromJsonAsync<JsonElement>()).GetProperty("token").GetString()!;
        var setup = await factory.Api(token).GetFromJsonAsync<JsonElement>("/api/admin/setup");
        Assert.Contains("Workspace__ClientSecret", string.Join("\n", setup.GetProperty("warnings").EnumerateArray().Select(w => w.GetString())));
    }

    [Fact]
    public async Task Work_sign_in_is_off_when_nothing_is_set_up()
    {
        using var factory = new ApiFactory();
        Assert.Equal(HttpStatusCode.NotFound, (await factory.CreateClient().GetAsync("/api/auth/login")).StatusCode);
        var config = await factory.CreateClient().GetFromJsonAsync<JsonElement>("/api/auth/config");
        Assert.Equal("none", config.GetProperty("provider").GetString());
        Assert.True(config.GetProperty("demo").GetBoolean());
    }

    [Fact]
    public async Task A_work_session_stops_working_if_work_sign_in_is_switched_off()
    {
        string token;
        using (var on = new WorkspaceFactory("Google"))
            token = WorkspaceFactory.TokenIn(await on.SignIn(on.Browser(), null, GoogleAccount("pat@example.com")));

        using var off = new ApiFactory(); // same signing key, no work sign-in
        var client = off.CreateClient();
        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", token);
        Assert.Equal(HttpStatusCode.Unauthorized, (await client.GetAsync("/api/jobs/quota")).StatusCode);
    }

    [Fact]
    public async Task A_workspace_starts_with_no_sample_people_and_no_printers()
    {
        using var factory = new WorkspaceFactory("Google");
        var boss = await factory.SignIn(factory.Browser(), null, GoogleAccount("boss@example.com", sub: "boss"));
        var api = factory.Api(WorkspaceFactory.TokenIn(boss));

        Assert.Empty((await api.GetFromJsonAsync<JsonElement>("/api/admin/users")).EnumerateArray());
        Assert.Empty((await api.GetFromJsonAsync<JsonElement>("/api/jobs")).EnumerateArray());
        Assert.Empty((await api.GetFromJsonAsync<JsonElement>("/api/printers")).EnumerateArray());
        Assert.Equal(HttpStatusCode.NotFound, (await api.PostAsync("/api/jobs/sample", null)).StatusCode); // demo is off
    }
}
