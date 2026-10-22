using System.Net;
using System.Net.Http.Headers;
using System.Net.Http.Json;
using System.Text.Json;
using Microsoft.AspNetCore.Hosting;
using Microsoft.AspNetCore.Mvc.Testing;
using Microsoft.Extensions.Configuration;

namespace PullPrintingBackend.Tests;

public class ApiFactory : WebApplicationFactory<Program>
{
    public const string Key = "test-signing-key-that-is-long-enough-for-hs256";

    protected virtual bool DemoEnabled => true;

    /// <summary>Tests call the API a lot from one address, so the limits are raised unless a test is about them.</summary>
    protected virtual int LoginsPerMinute => 1000;

    protected override void ConfigureWebHost(IWebHostBuilder builder)
    {
        builder.UseEnvironment("Testing");
        builder.ConfigureAppConfiguration((_, config) => config.AddInMemoryCollection(new Dictionary<string, string?>
        {
            ["Demo:Enabled"] = DemoEnabled ? "true" : "false",
            ["Demo:SigningKey"] = Key,
            ["RateLimit:LoginPerMinute"] = LoginsPerMinute.ToString(),
            ["RateLimit:PerMinute"] = "100000",
        }));
    }
}

public class DemoOffFactory : ApiFactory
{
    protected override bool DemoEnabled => false;
}

public class DefaultLimitsFactory : ApiFactory
{
    protected override int LoginsPerMinute => 20;
}

public record Session(string Token, string UserId, string Name, bool IsAdmin);

public class ApiTests : IClassFixture<ApiFactory>
{
    private readonly ApiFactory _factory;
    public ApiTests(ApiFactory factory) => _factory = factory;

    private static readonly JsonSerializerOptions Json = new(JsonSerializerDefaults.Web);

    private async Task<(HttpClient Client, Session Session)> SignIn(bool admin = false)
    {
        var client = _factory.CreateClient();
        var response = await client.PostAsJsonAsync("/api/auth/demo-login", new { admin });
        response.EnsureSuccessStatusCode();
        var session = (await response.Content.ReadFromJsonAsync<Session>(Json))!;
        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", session.Token);
        return (client, session);
    }

    private static async Task<JsonElement> Body(HttpResponseMessage response) =>
        (await response.Content.ReadFromJsonAsync<JsonElement>(Json));

    private static async Task<List<JsonElement>> Held(HttpClient client) =>
        (await Body(await client.GetAsync("/api/jobs/held"))).EnumerateArray().ToList();

    private static async Task<string[]> HeldNames(HttpClient client) =>
        (await Held(client)).Select(j => j.GetProperty("fileName").GetString()!).ToArray();

    // ---- authentication ----------------------------------------------------

    [Theory]
    [InlineData("GET", "/api/jobs/held")]
    [InlineData("GET", "/api/jobs/quota")]
    [InlineData("GET", "/api/jobs")]
    [InlineData("GET", "/api/auth/me")]
    [InlineData("GET", "/api/admin/users")]
    [InlineData("POST", "/api/jobs/release")]
    [InlineData("POST", "/api/jobs/sample")]
    [InlineData("POST", "/api/admin/set-quota")]
    public async Task Endpoints_need_a_token(string method, string path)
    {
        var client = _factory.CreateClient();
        var response = await client.SendAsync(new HttpRequestMessage(new HttpMethod(method), path));
        Assert.Equal(HttpStatusCode.Unauthorized, response.StatusCode);
    }

    [Fact]
    public async Task Garbage_and_wrongly_signed_tokens_are_rejected()
    {
        var client = _factory.CreateClient();
        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", "not-a-token");
        Assert.Equal(HttpStatusCode.Unauthorized, (await client.GetAsync("/api/jobs/held")).StatusCode);

        // A well-formed token signed with some other key.
        var forged = new System.IdentityModel.Tokens.Jwt.JwtSecurityTokenHandler().WriteToken(
            new System.IdentityModel.Tokens.Jwt.JwtSecurityToken(
                "pullprint-demo", "pullprint-demo",
                new[] { new System.Security.Claims.Claim("uid", "u2"), new System.Security.Claims.Claim("role", "Admin") },
                expires: DateTime.UtcNow.AddHours(1),
                signingCredentials: new Microsoft.IdentityModel.Tokens.SigningCredentials(
                    new Microsoft.IdentityModel.Tokens.SymmetricSecurityKey(
                        System.Text.Encoding.UTF8.GetBytes("a-completely-different-signing-key-123456")),
                    Microsoft.IdentityModel.Tokens.SecurityAlgorithms.HmacSha256)));
        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", forged);
        Assert.Equal(HttpStatusCode.Unauthorized, (await client.GetAsync("/api/jobs")).StatusCode);
    }

    [Fact]
    public async Task Demo_sign_in_returns_a_token_that_names_the_visitor()
    {
        var (client, session) = await SignIn();
        Assert.Equal("Alice Tan", session.Name);
        Assert.False(session.IsAdmin);

        var me = await Body(await client.GetAsync("/api/auth/me"));
        Assert.Equal(session.UserId, me.GetProperty("userId").GetString());
        Assert.False(me.GetProperty("isAdmin").GetBoolean());
    }

    [Fact]
    public async Task Demo_sign_in_can_be_switched_off_and_then_its_tokens_stop_working()
    {
        var (_, session) = await SignIn();

        using var off = new DemoOffFactory();
        var client = off.CreateClient();
        Assert.Equal(HttpStatusCode.NotFound,
            (await client.PostAsJsonAsync("/api/auth/demo-login", new { admin = false })).StatusCode);

        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", session.Token);
        Assert.Equal(HttpStatusCode.Unauthorized, (await client.GetAsync("/api/jobs/held")).StatusCode);
    }

    [Fact]
    public async Task Normal_users_cannot_use_admin_routes()
    {
        var (client, session) = await SignIn();
        Assert.Equal(HttpStatusCode.Forbidden, (await client.GetAsync("/api/jobs")).StatusCode);
        Assert.Equal(HttpStatusCode.Forbidden, (await client.GetAsync("/api/admin/users")).StatusCode);
        Assert.Equal(HttpStatusCode.Forbidden,
            (await client.PostAsJsonAsync("/api/admin/set-quota", new { userId = session.UserId, quota = 9999 })).StatusCode);

        // And the quota was not changed.
        var quota = await Body(await client.GetAsync("/api/jobs/quota"));
        Assert.Equal(50, quota.GetProperty("total").GetInt32());
    }

    [Fact]
    public async Task Admins_see_the_jobs_of_their_own_sample_people_and_nobody_elses()
    {
        var (visitor, _) = await SignIn();
        var visitorJobIds = (await Held(visitor)).Select(j => j.GetProperty("id").GetString()).ToHashSet();

        var (admin, _) = await SignIn(admin: true);
        var response = await admin.GetAsync("/api/jobs");
        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
        var jobs = (await Body(response)).EnumerateArray().ToList();
        var names = jobs.Select(j => j.GetProperty("fileName").GetString()).ToList();
        Assert.Contains("Safety audit.pdf", names);
        Assert.Contains("Invoice 2291.pdf", names);

        // The visitor's documents are not in the administrator's view.
        Assert.DoesNotContain(jobs, j => visitorJobIds.Contains(j.GetProperty("id").GetString()));
    }

    [Fact]
    public async Task Sign_in_attempts_are_rate_limited()
    {
        using var factory = new DefaultLimitsFactory();
        var client = factory.CreateClient();
        HttpStatusCode last = HttpStatusCode.OK;
        for (var i = 0; i < 25; i++)
            last = (await client.PostAsJsonAsync("/api/auth/demo-login", new { admin = false })).StatusCode;
        Assert.Equal(HttpStatusCode.TooManyRequests, last);
    }

    [Fact]
    public async Task Health_check_needs_no_token()
    {
        var response = await _factory.CreateClient().GetAsync("/healthz");
        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
    }

    // ---- documents and quota -----------------------------------------------

    [Fact]
    public async Task A_visitor_sees_only_their_own_waiting_documents()
    {
        var (client, _) = await SignIn();
        var names = await HeldNames(client);
        Assert.Equal(
            new[] { "Q3 budget review.pdf", "Site visit notes.docx", "Contract draft v4.pdf", "Floor plan.png" },
            names);
        Assert.DoesNotContain("Safety audit.pdf", names);

        var quota = await Body(await client.GetAsync("/api/jobs/quota"));
        Assert.Equal(12, quota.GetProperty("used").GetInt32());
        Assert.Equal(50, quota.GetProperty("total").GetInt32());
        Assert.Equal(38, quota.GetProperty("left").GetInt32());
    }

    [Fact]
    public async Task Printing_uses_up_pages_and_removes_the_documents_from_the_list()
    {
        var (client, _) = await SignIn();
        var held = await Held(client);
        var ids = held.Take(2).Select(j => j.GetProperty("id").GetString()).ToList();

        var response = await client.PostAsJsonAsync("/api/jobs/release", new { jobIds = ids });
        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
        var body = await Body(response);
        Assert.Equal(15, body.GetProperty("pages").GetInt32());
        Assert.Equal(27, body.GetProperty("quota").GetProperty("used").GetInt32());

        Assert.Equal(new[] { "Contract draft v4.pdf", "Floor plan.png" }, await HeldNames(client));
    }

    [Fact]
    public async Task Going_over_quota_prints_nothing_and_says_by_how_much()
    {
        var (client, _) = await SignIn();
        var ids = (await Held(client)).Select(j => j.GetProperty("id").GetString()).ToList(); // 44 pages, 38 left

        var response = await client.PostAsJsonAsync("/api/jobs/release", new { jobIds = ids });
        Assert.Equal(HttpStatusCode.Conflict, response.StatusCode);
        var body = await Body(response);
        Assert.Equal("quota_exceeded", body.GetProperty("error").GetString());
        Assert.Equal(6, body.GetProperty("pagesOver").GetInt32());

        Assert.Equal(4, (await Held(client)).Count);
        var quota = await Body(await client.GetAsync("/api/jobs/quota"));
        Assert.Equal(12, quota.GetProperty("used").GetInt32());
    }

    [Fact]
    public async Task Someone_elses_document_cannot_be_printed()
    {
        var (client, _) = await SignIn();
        var (admin, _) = await SignIn(admin: true);
        var all = (await Body(await admin.GetAsync("/api/jobs"))).EnumerateArray().ToList();
        var priyas = all.First(j => j.GetProperty("fileName").GetString() == "Safety audit.pdf").GetProperty("id").GetString();

        var response = await client.PostAsJsonAsync("/api/jobs/release", new { jobIds = new[] { priyas } });
        Assert.Equal(HttpStatusCode.NotFound, response.StatusCode);

        var after = (await Body(await admin.GetAsync("/api/jobs"))).EnumerateArray()
            .First(j => j.GetProperty("id").GetString() == priyas);
        Assert.Equal("Held", after.GetProperty("status").GetString());
    }

    [Fact]
    public async Task Visitors_are_isolated_from_each_other()
    {
        var (first, _) = await SignIn();
        var (second, _) = await SignIn();
        var ids = (await Held(first)).Take(2).Select(j => j.GetProperty("id").GetString()).ToList();
        Assert.Equal(HttpStatusCode.OK, (await first.PostAsJsonAsync("/api/jobs/release", new { jobIds = ids })).StatusCode);

        Assert.Equal(2, (await Held(first)).Count);
        Assert.Equal(4, (await Held(second)).Count);
        var quota = await Body(await second.GetAsync("/api/jobs/quota"));
        Assert.Equal(12, quota.GetProperty("used").GetInt32());
    }

    [Fact]
    public async Task Bad_release_requests_are_refused()
    {
        var (client, _) = await SignIn();
        Assert.Equal(HttpStatusCode.BadRequest,
            (await client.PostAsJsonAsync("/api/jobs/release", new { jobIds = Array.Empty<string>() })).StatusCode);
        Assert.Equal(HttpStatusCode.NotFound,
            (await client.PostAsJsonAsync("/api/jobs/release", new { jobIds = new[] { "nope" } })).StatusCode);

        var id = (await Held(client)).First().GetProperty("id").GetString();
        Assert.Equal(HttpStatusCode.OK, (await client.PostAsJsonAsync("/api/jobs/release", new { jobId = id })).StatusCode);
        // Printing the same document twice is refused and charges nothing more.
        Assert.Equal(HttpStatusCode.NotFound, (await client.PostAsJsonAsync("/api/jobs/release", new { jobId = id })).StatusCode);
        var quota = await Body(await client.GetAsync("/api/jobs/quota"));
        Assert.Equal(24, quota.GetProperty("used").GetInt32());
    }

    [Fact]
    public async Task Sample_documents_are_new_ones_first_and_run_out()
    {
        var (client, _) = await SignIn();
        var added = new List<string>();
        for (var i = 0; i < 4; i++)
        {
            var response = await client.PostAsync("/api/jobs/sample", null);
            Assert.Equal(HttpStatusCode.OK, response.StatusCode);
            added.Add((await Body(response)).GetProperty("fileName").GetString()!);
        }
        Assert.Equal(
            new[] { "Meeting agenda.docx", "Safety checklist.pdf", "Onboarding guide.pdf", "Site photo.png" },
            added.OrderBy(n => n).Select(n => n).OrderBy(n => Array.IndexOf(
                new[] { "Meeting agenda.docx", "Safety checklist.pdf", "Onboarding guide.pdf", "Site photo.png" }, n)));
        Assert.Equal(8, (await Held(client)).Count);
        Assert.Equal(HttpStatusCode.Conflict, (await client.PostAsync("/api/jobs/sample", null)).StatusCode);
    }

    [Fact]
    public async Task A_printed_document_does_not_come_straight_back_as_a_sample()
    {
        var (client, _) = await SignIn();
        var first = (await Held(client)).First().GetProperty("id").GetString();
        await client.PostAsJsonAsync("/api/jobs/release", new { jobId = first }); // Q3 budget review.pdf

        var sample = await Body(await client.PostAsync("/api/jobs/sample", null));
        Assert.NotEqual("Q3 budget review.pdf", sample.GetProperty("fileName").GetString());
    }

    // ---- administration -----------------------------------------------------

    private static async Task<List<JsonElement>> AdminUsers(HttpClient admin) =>
        (await Body(await admin.GetAsync("/api/admin/users"))).EnumerateArray().ToList();

    private static JsonElement Person(List<JsonElement> users, string name) =>
        users.First(u => u.GetProperty("name").GetString() == name);

    [Fact]
    public async Task An_admin_sees_sample_people_and_can_change_their_quota()
    {
        var (admin, _) = await SignIn(admin: true);
        var users = await AdminUsers(admin);
        Assert.Equal(
            new[] { "Alice Tan", "Bob Reyes", "Marcus Lee", "Priya Nair" },
            users.Select(u => u.GetProperty("name").GetString()).ToArray());
        Assert.Equal(200, Person(users, "Priya Nair").GetProperty("quota").GetProperty("total").GetInt32());

        var priya = Person(users, "Priya Nair").GetProperty("userId").GetString();
        Assert.Equal(HttpStatusCode.OK,
            (await admin.PostAsJsonAsync("/api/admin/set-quota", new { userId = priya, quota = 20 })).StatusCode);

        var after = await AdminUsers(admin);
        Assert.Equal(20, Person(after, "Priya Nair").GetProperty("quota").GetProperty("total").GetInt32());
    }

    [Fact]
    public async Task An_admin_cannot_see_or_change_a_visitors_account()
    {
        var (_, visitor) = await SignIn();
        var (admin, _) = await SignIn(admin: true);

        Assert.DoesNotContain(await AdminUsers(admin), u => u.GetProperty("userId").GetString() == visitor.UserId);
        Assert.Equal(HttpStatusCode.NotFound,
            (await admin.PostAsJsonAsync("/api/admin/set-quota", new { userId = visitor.UserId, quota = 1 })).StatusCode);
    }

    [Fact]
    public async Task Two_admins_do_not_affect_each_other()
    {
        var (first, _) = await SignIn(admin: true);
        var (second, _) = await SignIn(admin: true);

        var priya = Person(await AdminUsers(first), "Priya Nair").GetProperty("userId").GetString();
        Assert.Equal(HttpStatusCode.OK,
            (await first.PostAsJsonAsync("/api/admin/set-quota", new { userId = priya, quota = 5 })).StatusCode);

        Assert.Equal(200, Person(await AdminUsers(second), "Priya Nair").GetProperty("quota").GetProperty("total").GetInt32());
        Assert.Equal(HttpStatusCode.NotFound,
            (await second.PostAsJsonAsync("/api/admin/set-quota", new { userId = priya, quota = 1 })).StatusCode);
    }

    [Fact]
    public async Task Quota_changes_are_validated()
    {
        var (admin, session) = await SignIn(admin: true);
        Assert.Equal(HttpStatusCode.BadRequest,
            (await admin.PostAsJsonAsync("/api/admin/set-quota", new { userId = session.UserId, quota = -1 })).StatusCode);
        Assert.Equal(HttpStatusCode.BadRequest,
            (await admin.PostAsJsonAsync("/api/admin/set-quota", new { userId = session.UserId, quota = 1_000_000 })).StatusCode);
        Assert.Equal(HttpStatusCode.BadRequest,
            (await admin.PostAsJsonAsync("/api/admin/set-quota", new { userId = "", quota = 10 })).StatusCode);
        Assert.Equal(HttpStatusCode.NotFound,
            (await admin.PostAsJsonAsync("/api/admin/set-quota", new { userId = "nobody", quota = 10 })).StatusCode);
    }
}
