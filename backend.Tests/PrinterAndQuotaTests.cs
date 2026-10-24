using System.Net;
using System.Net.Http.Headers;
using System.Net.Http.Json;
using System.Text.Json;
using Microsoft.Extensions.Logging.Abstractions;
using Microsoft.Extensions.Options;
using PullPrintingBackend.Models;
using PullPrintingBackend.Services;

namespace PullPrintingBackend.Tests;

public class PrinterAndQuotaStoreTests
{
    private class FakeClock : TimeProvider
    {
        public DateTimeOffset Now { get; set; } = new(2026, 10, 22, 9, 0, 0, TimeSpan.Zero);
        public override DateTimeOffset GetUtcNow() => Now;
    }

    private static PrintStore NewStore(FakeClock? clock = null, int defaultQuota = 50) =>
        new(new SimulatedPrintDispatcher(NullLogger<SimulatedPrintDispatcher>.Instance),
            clock ?? new FakeClock(),
            Options.Create(new WorkspaceOptions { DefaultQuota = defaultQuota }));

    [Fact]
    public void Pages_used_start_again_when_the_month_changes()
    {
        var clock = new FakeClock { Now = new(2026, 10, 31, 23, 0, 0, TimeSpan.Zero) };
        var store = NewStore(clock);
        var visitor = store.CreateDemoUser(isAdmin: false);
        var ids = store.HeldJobs(visitor.UserId).Take(2).Select(j => j.Id).ToList();

        var printed = store.Release(visitor.UserId, ids);
        Assert.Equal(ReleaseOutcome.Printed, printed.Outcome);
        Assert.True(store.GetQuota(visitor.UserId)!.Used > 0);

        clock.Now = new(2026, 11, 1, 0, 30, 0, TimeSpan.Zero);
        Assert.Equal(0, store.GetQuota(visitor.UserId)!.Used);
    }

    [Fact]
    public void Pages_used_do_not_reset_within_the_same_month()
    {
        var clock = new FakeClock { Now = new(2026, 10, 1, 0, 0, 0, TimeSpan.Zero) };
        var store = NewStore(clock);
        var visitor = store.CreateDemoUser(isAdmin: false);
        store.Release(visitor.UserId, store.HeldJobs(visitor.UserId).Take(1).Select(j => j.Id).ToList());
        var used = store.GetQuota(visitor.UserId)!.Used;

        clock.Now = new(2026, 10, 31, 23, 59, 0, TimeSpan.Zero);
        Assert.Equal(used, store.GetQuota(visitor.UserId)!.Used);
    }

    [Fact]
    public void The_default_quota_is_used_for_people_who_sign_in_later_and_not_for_those_already_there()
    {
        var store = NewStore(defaultQuota: 40);
        var boss = store.EnsureUser("boss", "Boss", isAdmin: true);
        var early = store.EnsureUser("early", "Early", isAdmin: false);
        Assert.Equal(40, early.Quota.Total);

        Assert.True(store.SetDefaultQuota(boss.UserId, 120));
        Assert.Equal(120, store.DefaultQuota(boss.UserId));
        Assert.Equal(120, store.EnsureUser("late", "Late", isAdmin: false).Quota.Total);
        Assert.Equal(40, store.GetQuota("early")!.Total);
    }

    [Fact]
    public void Giving_everyone_the_same_pages_changes_the_whole_group_and_only_that_group()
    {
        var store = NewStore();
        var boss = store.EnsureUser("boss", "Boss", isAdmin: true);
        store.EnsureUser("a", "A", isAdmin: false);
        store.EnsureUser("b", "B", isAdmin: false);
        var visitor = store.CreateDemoUser(isAdmin: false);
        var visitorBefore = store.GetQuota(visitor.UserId)!.Total;

        var changed = store.SetQuotaForAll(boss.UserId, 15);

        Assert.True(changed >= 2);
        Assert.Equal(15, store.GetQuota("a")!.Total);
        Assert.Equal(15, store.GetQuota("b")!.Total);
        Assert.Equal(visitorBefore, store.GetQuota(visitor.UserId)!.Total);
    }

    [Fact]
    public void A_demo_visitor_starts_with_three_printers_and_a_workspace_with_none()
    {
        var store = NewStore();
        var visitor = store.CreateDemoUser(isAdmin: false);
        var boss = store.EnsureUser("boss", "Boss", isAdmin: true);

        Assert.Equal(new[] { "Level 3 East", "Print room", "Reception" },
            store.Printers(visitor.UserId).Select(p => p.Name).ToArray());
        Assert.Empty(store.Printers(boss.UserId));
    }

    [Fact]
    public void Printers_can_be_added_renamed_switched_off_and_removed()
    {
        var store = NewStore();
        var boss = store.EnsureUser("boss", "Boss", isAdmin: true);

        var added = store.AddPrinter(boss.UserId, "Studio", "Level 1")!;
        Assert.Equal("Studio", store.Printers(boss.UserId).Single().Name);

        Assert.True(store.UpdatePrinter(boss.UserId, added.Id, "Design studio", "Level 2", enabled: false));
        var changed = store.Printers(boss.UserId).Single();
        Assert.Equal(("Design studio", "Level 2", false), (changed.Name, changed.Location, changed.Enabled));

        Assert.True(store.DeletePrinter(boss.UserId, added.Id));
        Assert.Empty(store.Printers(boss.UserId));
        Assert.False(store.DeletePrinter(boss.UserId, added.Id));
        Assert.False(store.UpdatePrinter(boss.UserId, "nope", "x", "", true));
    }

    [Fact]
    public void One_group_cannot_change_or_see_another_groups_printers()
    {
        var store = NewStore();
        var boss = store.EnsureUser("boss", "Boss", isAdmin: true);
        var visitor = store.CreateDemoUser(isAdmin: true);
        var theirs = store.Printers(visitor.UserId).First();

        Assert.False(store.UpdatePrinter(boss.UserId, theirs.Id, "Hijacked", "", true));
        Assert.False(store.DeletePrinter(boss.UserId, theirs.Id));
        Assert.Equal("Level 3 East", store.Printers(visitor.UserId).First().Name);
    }

    [Fact]
    public void There_is_a_limit_to_how_many_printers_can_be_added()
    {
        var store = NewStore();
        var boss = store.EnsureUser("boss", "Boss", isAdmin: true);
        for (var i = 0; i < PrintStore.MaxPrinters; i++)
            Assert.NotNull(store.AddPrinter(boss.UserId, $"P{i}", ""));
        Assert.Null(store.AddPrinter(boss.UserId, "One too many", ""));
    }

    [Fact]
    public void Printing_names_the_printer_used_and_picks_the_first_one_that_is_on_by_default()
    {
        var store = NewStore();
        var visitor = store.CreateDemoUser(isAdmin: false);
        var first = store.Printers(visitor.UserId).First();
        store.UpdatePrinter(visitor.UserId, first.Id, first.Name, first.Location, enabled: false);

        var any = store.Release(visitor.UserId, store.HeldJobs(visitor.UserId).Take(1).Select(j => j.Id).ToList());
        Assert.Equal(ReleaseOutcome.Printed, any.Outcome);
        Assert.Equal("Print room", any.PrinterName);

        var chosen = store.Printers(visitor.UserId).Last();
        var picked = store.Release(visitor.UserId, store.HeldJobs(visitor.UserId).Take(1).Select(j => j.Id).ToList(), chosen.Id);
        Assert.Equal(chosen.Name, picked.PrinterName);
        Assert.Equal(chosen.Name, picked.Printed.Single().PrinterName);
    }

    [Fact]
    public void A_switched_off_or_unknown_printer_prints_nothing_and_costs_nothing()
    {
        var store = NewStore();
        var visitor = store.CreateDemoUser(isAdmin: false);
        var off = store.Printers(visitor.UserId).First();
        store.UpdatePrinter(visitor.UserId, off.Id, off.Name, off.Location, enabled: false);
        var ids = store.HeldJobs(visitor.UserId).Take(1).Select(j => j.Id).ToList();
        var before = store.GetQuota(visitor.UserId)!.Used;

        Assert.Equal(ReleaseOutcome.PrinterUnavailable, store.Release(visitor.UserId, ids, off.Id).Outcome);
        Assert.Equal(ReleaseOutcome.PrinterUnavailable, store.Release(visitor.UserId, ids, "no-such-printer").Outcome);
        Assert.Equal(before, store.GetQuota(visitor.UserId)!.Used);
        Assert.Equal(ids.Count, store.HeldJobs(visitor.UserId).Count(j => ids.Contains(j.Id)));
    }

    [Fact]
    public void A_printer_from_another_group_cannot_be_used()
    {
        var store = NewStore();
        var a = store.CreateDemoUser(isAdmin: false);
        var b = store.CreateDemoUser(isAdmin: false);
        var bsPrinter = store.Printers(b.UserId).First();
        var ids = store.HeldJobs(a.UserId).Take(1).Select(j => j.Id).ToList();

        Assert.Equal(ReleaseOutcome.PrinterUnavailable, store.Release(a.UserId, ids, bsPrinter.Id).Outcome);
    }

    [Fact]
    public void With_no_printers_at_all_the_outcome_says_so()
    {
        var store = NewStore();
        var visitor = store.CreateDemoUser(isAdmin: false);
        foreach (var p in store.Printers(visitor.UserId)) store.DeletePrinter(visitor.UserId, p.Id);

        var ids = store.HeldJobs(visitor.UserId).Take(1).Select(j => j.Id).ToList();
        Assert.Equal(ReleaseOutcome.NoPrinter, store.Release(visitor.UserId, ids).Outcome);
    }
}

public class PrinterAndQuotaApiTests : IClassFixture<ApiFactory>
{
    private readonly ApiFactory _factory;
    public PrinterAndQuotaApiTests(ApiFactory factory) => _factory = factory;

    private static readonly JsonSerializerOptions Json = new(JsonSerializerDefaults.Web);

    private async Task<HttpClient> SignIn(bool admin)
    {
        var client = _factory.CreateClient();
        var response = await client.PostAsJsonAsync("/api/auth/demo-login", new { admin });
        var session = (await response.Content.ReadFromJsonAsync<Session>(Json))!;
        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", session.Token);
        return client;
    }

    [Fact]
    public async Task A_visitor_can_list_printers_but_not_manage_them()
    {
        var client = await SignIn(admin: false);
        var list = await client.GetFromJsonAsync<JsonElement>("/api/printers", Json);
        Assert.Equal(3, list.GetArrayLength());

        Assert.Equal(HttpStatusCode.Forbidden,
            (await client.PostAsJsonAsync("/api/admin/printers", new { name = "X" })).StatusCode);
        Assert.Equal(HttpStatusCode.Forbidden,
            (await client.PostAsJsonAsync("/api/admin/default-quota", new { quota = 10 })).StatusCode);
        Assert.Equal(HttpStatusCode.Forbidden,
            (await client.PostAsJsonAsync("/api/admin/set-quota-all", new { quota = 10 })).StatusCode);
        Assert.Equal(HttpStatusCode.Forbidden, (await client.GetAsync("/api/admin/setup")).StatusCode);
    }

    [Fact]
    public async Task An_administrator_adds_switches_off_and_removes_a_printer()
    {
        var admin = await SignIn(admin: true);

        var added = await admin.PostAsJsonAsync("/api/admin/printers", new { name = "Studio", location = "L1" });
        Assert.Equal(HttpStatusCode.OK, added.StatusCode);
        var printer = await added.Content.ReadFromJsonAsync<JsonElement>(Json);
        var id = printer.GetProperty("id").GetString()!;

        var off = await admin.PutAsJsonAsync($"/api/admin/printers/{id}", new { name = "Studio", location = "L1", enabled = false });
        Assert.Equal(HttpStatusCode.OK, off.StatusCode);
        var listed = (await admin.GetFromJsonAsync<JsonElement>("/api/printers", Json)).EnumerateArray()
            .First(p => p.GetProperty("id").GetString() == id);
        Assert.False(listed.GetProperty("enabled").GetBoolean());

        Assert.Equal(HttpStatusCode.OK, (await admin.DeleteAsync($"/api/admin/printers/{id}")).StatusCode);
        Assert.Equal(HttpStatusCode.NotFound, (await admin.DeleteAsync($"/api/admin/printers/{id}")).StatusCode);
    }

    [Theory]
    [InlineData("")]
    [InlineData("   ")]
    public async Task A_printer_needs_a_name(string name)
    {
        var admin = await SignIn(admin: true);
        var response = await admin.PostAsJsonAsync("/api/admin/printers", new { name });
        Assert.Equal(HttpStatusCode.BadRequest, response.StatusCode);
    }

    [Theory]
    [InlineData("/api/admin/default-quota", -1)]
    [InlineData("/api/admin/default-quota", 10_001)]
    [InlineData("/api/admin/set-quota-all", -5)]
    [InlineData("/api/admin/set-quota-all", 1_000_000)]
    public async Task Quota_rules_outside_the_allowed_range_are_refused(string path, int quota)
    {
        var admin = await SignIn(admin: true);
        Assert.Equal(HttpStatusCode.BadRequest, (await admin.PostAsJsonAsync(path, new { quota })).StatusCode);
    }

    [Fact]
    public async Task The_administrators_quota_rules_take_effect()
    {
        var admin = await SignIn(admin: true);

        Assert.Equal(HttpStatusCode.OK, (await admin.PostAsJsonAsync("/api/admin/default-quota", new { quota = 77 })).StatusCode);
        var setup = await admin.GetFromJsonAsync<JsonElement>("/api/admin/setup", Json);
        Assert.Equal(77, setup.GetProperty("defaultQuota").GetInt32());

        var all = await admin.PostAsJsonAsync("/api/admin/set-quota-all", new { quota = 9 });
        var changed = (await all.Content.ReadFromJsonAsync<JsonElement>(Json)).GetProperty("changed").GetInt32();
        Assert.True(changed >= 1);
        var users = await admin.GetFromJsonAsync<JsonElement>("/api/admin/users", Json);
        Assert.All(users.EnumerateArray(), u => Assert.Equal(9, u.GetProperty("quota").GetProperty("total").GetInt32()));
    }

    [Fact]
    public async Task Printing_on_an_unknown_printer_is_refused_with_a_reason_and_prints_nothing()
    {
        var client = await SignIn(admin: false);
        var held = (await client.GetFromJsonAsync<JsonElement>("/api/jobs/held", Json)).EnumerateArray().First();
        var response = await client.PostAsJsonAsync("/api/jobs/release",
            new { jobIds = new[] { held.GetProperty("id").GetString() }, printerId = "no-such-printer" });

        Assert.Equal(HttpStatusCode.Conflict, response.StatusCode);
        var body = await response.Content.ReadFromJsonAsync<JsonElement>(Json);
        Assert.Equal("printer_unavailable", body.GetProperty("error").GetString());
        var stillHeld = (await client.GetFromJsonAsync<JsonElement>("/api/jobs/held", Json)).EnumerateArray();
        Assert.Contains(stillHeld, j => j.GetProperty("id").GetString() == held.GetProperty("id").GetString());
    }

    [Fact]
    public async Task Printing_on_a_chosen_printer_says_which_one()
    {
        var client = await SignIn(admin: false);
        var printers = (await client.GetFromJsonAsync<JsonElement>("/api/printers", Json)).EnumerateArray().ToList();
        var reception = printers.First(p => p.GetProperty("name").GetString() == "Reception");
        var held = (await client.GetFromJsonAsync<JsonElement>("/api/jobs/held", Json)).EnumerateArray().First(j => j.GetProperty("pages").GetInt32() <= 12);

        var response = await client.PostAsJsonAsync("/api/jobs/release",
            new { jobIds = new[] { held.GetProperty("id").GetString() }, printerId = reception.GetProperty("id").GetString() });

        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
        var body = await response.Content.ReadFromJsonAsync<JsonElement>(Json);
        Assert.Equal("Reception", body.GetProperty("printerName").GetString());
    }
}
