using Microsoft.Extensions.Logging.Abstractions;
using PullPrintingBackend.Models;
using PullPrintingBackend.Services;

namespace PullPrintingBackend.Tests;

public class StoreTests
{
    private class FakeClock : TimeProvider
    {
        public DateTimeOffset Now { get; set; } = new(2026, 10, 22, 9, 0, 0, TimeSpan.Zero);
        public override DateTimeOffset GetUtcNow() => Now;
    }

    private class FailingDispatcher : IPrintDispatcher
    {
        public void Print(PrintJob job) => throw new InvalidOperationException("printer offline");
    }

    private static PrintStore NewStore(FakeClock? clock = null, IPrintDispatcher? dispatcher = null) =>
        new(dispatcher ?? new SimulatedPrintDispatcher(NullLogger<SimulatedPrintDispatcher>.Instance),
            clock ?? new FakeClock());

    [Fact]
    public void Idle_sandboxes_are_removed_with_their_documents_but_the_shared_group_stays()
    {
        var clock = new FakeClock();
        var store = NewStore(clock);
        var root = store.EnsureUser("root", "Root", isAdmin: true);
        var visitor = store.CreateDemoUser(isAdmin: false);
        var sharedJobs = store.AllJobs(root.UserId).Count;

        clock.Now += TimeSpan.FromHours(1);
        Assert.Equal(0, store.Sweep());

        clock.Now += TimeSpan.FromHours(1.5);
        Assert.Equal(1, store.Sweep());
        Assert.Null(store.GetQuota(visitor.UserId));
        Assert.Empty(store.HeldJobs(visitor.UserId));
        Assert.Equal(sharedJobs, store.AllJobs(root.UserId).Count);
        Assert.Contains(store.Users(root.UserId), u => u.Name == "Priya Nair");
    }

    [Fact]
    public void An_active_visitor_is_not_swept()
    {
        var clock = new FakeClock();
        var store = NewStore(clock);
        var visitor = store.CreateDemoUser(isAdmin: false);

        clock.Now += TimeSpan.FromHours(1.5);
        store.EnsureDemoUser(visitor.UserId, visitor.Name, false); // any request counts as activity
        clock.Now += TimeSpan.FromHours(1.5);
        Assert.Equal(0, store.Sweep());
        Assert.NotNull(store.GetQuota(visitor.UserId));
    }

    [Fact]
    public void An_active_admin_keeps_the_whole_sample_group()
    {
        var clock = new FakeClock();
        var store = NewStore(clock);
        var admin = store.CreateDemoUser(isAdmin: true);

        clock.Now += TimeSpan.FromHours(1.5);
        store.EnsureDemoUser(admin.UserId, admin.Name, true);
        clock.Now += TimeSpan.FromHours(1.5); // sample people are 3 hours old, the admin is 1.5

        Assert.Equal(0, store.Sweep());
        Assert.Equal(4, store.Users(admin.UserId).Count);
    }

    [Fact]
    public void An_admin_whose_sandbox_was_cleaned_up_gets_a_fresh_one_on_the_next_request()
    {
        var clock = new FakeClock();
        var store = NewStore(clock);
        var admin = store.CreateDemoUser(isAdmin: true);
        clock.Now += TimeSpan.FromHours(3);
        Assert.Equal(1, store.Sweep());
        Assert.Empty(store.Users(admin.UserId));

        store.EnsureDemoUser(admin.UserId, admin.Name, true);

        Assert.Equal(4, store.Users(admin.UserId).Count);
    }

    [Fact]
    public void The_number_of_sandboxes_is_capped_by_removing_the_least_recent()
    {
        var clock = new FakeClock();
        var store = NewStore(clock);
        var first = store.CreateDemoUser(isAdmin: false);
        UserSummary last = first;
        for (var i = 0; i < PrintStore.MaxVisitors + 5; i++)
        {
            clock.Now += TimeSpan.FromSeconds(1);
            last = store.CreateDemoUser(isAdmin: i % 2 == 0);
        }

        Assert.Equal(PrintStore.MaxVisitors, store.SandboxCount);
        Assert.Null(store.GetQuota(first.UserId));
        Assert.NotNull(store.GetQuota(last.UserId));
    }

    [Fact]
    public void Quotas_can_only_be_changed_inside_the_requesters_own_group()
    {
        var store = NewStore();
        var admin = store.CreateDemoUser(isAdmin: true);
        var visitor = store.CreateDemoUser(isAdmin: false);
        var alice = store.Users(admin.UserId).First(u => u.Name == "Alice Tan");

        Assert.True(store.SetQuota(admin.UserId, alice.UserId, 99));
        Assert.Equal(99, store.GetQuota(alice.UserId)!.Total);
        Assert.False(store.SetQuota(admin.UserId, visitor.UserId, 1));
        Assert.Equal(50, store.GetQuota(visitor.UserId)!.Total);
        Assert.False(store.SetQuota("nobody", alice.UserId, 1));
    }

    [Fact]
    public void A_job_the_printer_rejects_is_marked_failed_and_costs_no_pages()
    {
        var store = NewStore(dispatcher: new FailingDispatcher());
        var visitor = store.CreateDemoUser(isAdmin: false);
        var job = store.HeldJobs(visitor.UserId).First();

        var result = store.Release(visitor.UserId, new[] { job.Id });

        Assert.Empty(result.Printed);
        Assert.Equal(12, store.GetQuota(visitor.UserId)!.Used);
        var stored = store.AllJobs(visitor.UserId).Single(j => j.Id == job.Id);
        Assert.Equal(JobStatus.Failed, stored.Status);
        Assert.Equal("printer offline", stored.FailureReason);
        Assert.DoesNotContain(store.HeldJobs(visitor.UserId), j => j.Id == job.Id);
    }

    [Fact]
    public void Signing_in_with_a_new_account_creates_a_user_with_the_default_quota()
    {
        var store = NewStore();
        var user = store.EnsureUser("entra-oid-1", "Dana Cole", isAdmin: false);
        Assert.Equal(50, user.Quota.Total);
        Assert.Equal(0, user.Quota.Used);
        Assert.Empty(store.HeldJobs("entra-oid-1"));
    }
}
