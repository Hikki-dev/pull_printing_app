using Microsoft.Extensions.Options;
using PullPrintingBackend.Models;

namespace PullPrintingBackend.Services
{
    public enum ReleaseOutcome { Printed, NothingToPrint, OverQuota, NoPrinter, PrinterUnavailable }

    public record ReleaseResult(
        ReleaseOutcome Outcome,
        IReadOnlyList<PrintJob> Printed,
        int Pages,
        int PagesOver,
        Quota Quota,
        string? PrinterName = null);

    /// <summary>Users, printers, jobs and quotas. The only place that decides who may print what.</summary>
    public interface IPrintStore
    {
        /// <summary>A person who signed in with a work account. Added to the shared group on first sight.</summary>
        UserSummary EnsureUser(string id, string name, bool isAdmin, string? email = null);

        /// <summary>A demo visitor. Creates their private sandbox the first time, and again if it was cleaned up.</summary>
        UserSummary EnsureDemoUser(string id, string name, bool isAdmin);

        UserSummary CreateDemoUser(bool isAdmin);
        Quota? GetQuota(string userId);
        IReadOnlyList<PrintJob> HeldJobs(string userId);

        /// <summary>Every job in the requester's own group.</summary>
        IReadOnlyList<PrintJob> AllJobs(string requesterId);

        /// <summary>Everyone else in the requester's own group, for the quota table.</summary>
        IReadOnlyList<UserSummary> Users(string requesterId);

        /// <summary>Prints the person's own waiting documents on a printer. All or nothing against their quota.</summary>
        ReleaseResult Release(string userId, IReadOnlyCollection<string> jobIds, string? printerId = null);

        /// <summary>Changes a quota. Only people in the requester's own group can be changed.</summary>
        bool SetQuota(string requesterId, string userId, int quota);

        /// <summary>Pages a month for people who sign in for the first time. Null when the requester is unknown.</summary>
        int? DefaultQuota(string requesterId);

        bool SetDefaultQuota(string requesterId, int quota);

        /// <summary>Sets everyone's quota in the requester's group and returns how many people changed.</summary>
        int SetQuotaForAll(string requesterId, int quota);

        /// <summary>Printers in the requester's group, including switched-off ones.</summary>
        IReadOnlyList<Printer> Printers(string requesterId);

        Printer? AddPrinter(string requesterId, string name, string location);
        bool UpdatePrinter(string requesterId, string printerId, string name, string location, bool enabled);
        bool DeletePrinter(string requesterId, string printerId);

        PrintJob? AddSample(string userId);
        int Sweep();
    }

    /// <summary>
    /// In-memory store. Everything resets when the app restarts, and demo sandboxes that
    /// have been idle for <see cref="IdleLifetime"/> are removed. Swap for a database
    /// by implementing <see cref="IPrintStore"/>.
    /// </summary>
    public class PrintStore : IPrintStore
    {
        public const int DefaultQuotaPages = 50;
        public const int MaxHeldPerUser = 12;
        public const int MaxVisitors = 300;
        public const int MaxPrinters = 50;
        public const string DefaultSandbox = "default";
        public static readonly TimeSpan IdleLifetime = TimeSpan.FromHours(2);

        private static readonly (string File, int Pages)[] SampleDocuments =
        {
            ("Q3 budget review.pdf", 12),
            ("Site visit notes.docx", 3),
            ("Contract draft v4.pdf", 28),
            ("Floor plan.png", 1),
            ("Meeting agenda.docx", 2),
            ("Safety checklist.pdf", 6),
            ("Onboarding guide.pdf", 18),
            ("Site photo.png", 1),
        };

        private readonly object _gate = new();
        private readonly Dictionary<string, User> _users = new();
        private readonly List<PrintJob> _jobs = new();
        private readonly Dictionary<string, List<Printer>> _printers = new();
        private readonly Dictionary<string, int> _defaultQuota = new();
        private readonly IPrintDispatcher _dispatcher;
        private readonly TimeProvider _time;
        private int _sampleCursor;

        public PrintStore(IPrintDispatcher dispatcher, TimeProvider time, IOptions<WorkspaceOptions> workspace)
        {
            _dispatcher = dispatcher;
            _time = time;
            // The shared group starts empty: real people and printers are added by signing in and by administrators.
            _defaultQuota[DefaultSandbox] = Math.Max(workspace.Value.DefaultQuota, 0);
        }

        private DateTimeOffset Now => _time.GetUtcNow();

        private static int Period(DateTimeOffset t) => t.Year * 100 + t.Month;

        /// <summary>Pages are used up per calendar month (UTC), so a new month starts everyone at zero.</summary>
        private void Normalize(User user)
        {
            var period = Period(Now);
            if (user.QuotaPeriod == period) return;
            user.PagesUsed = 0;
            user.QuotaPeriod = period;
        }

        private int DefaultFor(string sandbox) =>
            _defaultQuota.TryGetValue(sandbox, out var q) ? q : DefaultQuotaPages;

        // ---- demo sample data ------------------------------------------------

        /// <summary>Sample people with a few jobs each, so a demo administrator has something to look at.</summary>
        private void SeedSandbox(string sandbox, string idPrefix)
        {
            var now = Now;
            AddUser(idPrefix + "u2", "Bob Reyes", used: 50, total: 50, sandbox);
            AddUser(idPrefix + "u3", "Priya Nair", used: 8, total: 200, sandbox);
            AddUser(idPrefix + "u4", "Marcus Lee", used: 20, total: 50, sandbox);
            AddJob(idPrefix + "u2", "Bob Reyes", "report.docx", 3, now.AddMinutes(-30), JobStatus.Printed, printer: "Reception");
            AddJob(idPrefix + "u3", "Priya Nair", "Safety audit.pdf", 41, now.AddHours(-1), JobStatus.Held);
            AddJob(idPrefix + "u4", "Marcus Lee", "Invoice 2291.pdf", 2, now.AddDays(-1), JobStatus.Failed, "printer offline");
        }

        private void SeedPrinters(string sandbox)
        {
            _printers[sandbox] = new List<Printer>
            {
                new(NewId(), "Level 3 East", "Third floor, east wing", true),
                new(NewId(), "Reception", "Ground floor", true),
                new(NewId(), "Print room", "Second floor", true),
            };
        }

        private User AddUser(string id, string name, int used, int total, string sandbox, bool admin = false, string? email = null)
        {
            var user = new User
            {
                Id = id,
                DisplayName = name,
                Email = email,
                IsAdmin = admin,
                PagesUsed = used,
                PrintQuota = total,
                QuotaPeriod = Period(Now),
                LastSeen = Now,
                SandboxId = sandbox,
            };
            _users[id] = user;
            return user;
        }

        /// <summary>Alice Tan with her four waiting documents, as every demo visitor starts.</summary>
        private User AddAlice(string id, string sandbox)
        {
            const string name = "Alice Tan";
            var user = AddUser(id, name, used: 12, total: DefaultQuotaPages, sandbox);
            var now = Now;
            AddJob(id, name, "Q3 budget review.pdf", 12, now.AddMinutes(-20), JobStatus.Held);
            AddJob(id, name, "Site visit notes.docx", 3, now.AddMinutes(-40), JobStatus.Held);
            AddJob(id, name, "Contract draft v4.pdf", 28, now.AddDays(-1), JobStatus.Held);
            AddJob(id, name, "Floor plan.png", 1, now.AddDays(-1).AddHours(-1), JobStatus.Held);
            return user;
        }

        private PrintJob AddJob(string userId, string userName, string file, int pages,
            DateTimeOffset at, string status, string? reason = null, string? printer = null)
        {
            var job = new PrintJob(NewId(), userId, userName, file, pages, at, status, reason, printer);
            _jobs.Add(job);
            return job;
        }

        private static string NewId() => Guid.NewGuid().ToString("N")[..8];

        private UserSummary Summary(User u)
        {
            Normalize(u);
            return new(u.Id, u.DisplayName, u.IsAdmin, u.Quota, u.Email);
        }

        // ---- people ------------------------------------------------------------

        public UserSummary EnsureUser(string id, string name, bool isAdmin, string? email = null)
        {
            lock (_gate)
            {
                if (!_users.TryGetValue(id, out var user))
                    user = AddUser(id, name, used: 0, total: DefaultFor(DefaultSandbox), DefaultSandbox, admin: isAdmin, email: email);
                user.DisplayName = name;
                user.IsAdmin = isAdmin;
                if (email is not null) user.Email = email;
                user.LastSeen = Now;
                return Summary(user);
            }
        }

        public UserSummary EnsureDemoUser(string id, string name, bool isAdmin)
        {
            lock (_gate)
            {
                if (_users.TryGetValue(id, out var existing))
                {
                    existing.LastSeen = Now;
                    return Summary(existing);
                }

                EvictOldestSandboxes(MaxVisitors - 1);
                SeedPrinters(id);
                if (isAdmin)
                {
                    // A private copy of the sample people, so changes here affect nobody else.
                    SeedSandbox(id, idPrefix: id + "-");
                    AddAlice(id + "-u1", id);
                    return Summary(AddUser(id, name, used: 0, total: DefaultQuotaPages, id, admin: true));
                }
                return Summary(AddAlice(id, id));
            }
        }

        public UserSummary CreateDemoUser(bool isAdmin) =>
            EnsureDemoUser("demo-" + NewId(), isAdmin ? "Administrator" : "Alice Tan", isAdmin);

        public Quota? GetQuota(string userId)
        {
            lock (_gate)
            {
                if (!_users.TryGetValue(userId, out var u)) return null;
                Normalize(u);
                return u.Quota;
            }
        }

        public IReadOnlyList<PrintJob> HeldJobs(string userId)
        {
            lock (_gate)
                return _jobs
                    .Where(j => j.UserId == userId && j.Status == JobStatus.Held)
                    .OrderByDescending(j => j.SubmittedAt)
                    .ToList();
        }

        private string? SandboxOf(string userId) =>
            _users.TryGetValue(userId, out var u) ? u.SandboxId : null;

        public IReadOnlyList<PrintJob> AllJobs(string requesterId)
        {
            lock (_gate)
            {
                var sandbox = SandboxOf(requesterId);
                return _jobs
                    .Where(j => sandbox is not null && SandboxOf(j.UserId) == sandbox)
                    .OrderByDescending(j => j.SubmittedAt)
                    .ToList();
            }
        }

        public IReadOnlyList<UserSummary> Users(string requesterId)
        {
            lock (_gate)
            {
                var sandbox = SandboxOf(requesterId);
                return _users.Values
                    .Where(u => sandbox is not null && u.SandboxId == sandbox && !u.IsAdmin)
                    .OrderBy(u => u.DisplayName)
                    .Select(Summary)
                    .ToList();
            }
        }

        // ---- printing ----------------------------------------------------------

        public ReleaseResult Release(string userId, IReadOnlyCollection<string> jobIds, string? printerId = null)
        {
            lock (_gate)
            {
                if (!_users.TryGetValue(userId, out var user))
                    return new ReleaseResult(ReleaseOutcome.NothingToPrint, Array.Empty<PrintJob>(), 0, 0, new Quota(0, 0));
                Normalize(user);

                // Only the caller's own waiting jobs can be released, whatever ids were sent.
                var chosen = _jobs
                    .Where(j => j.UserId == userId && j.Status == JobStatus.Held && jobIds.Contains(j.Id))
                    .ToList();
                if (chosen.Count == 0)
                    return new ReleaseResult(ReleaseOutcome.NothingToPrint, Array.Empty<PrintJob>(), 0, 0, user.Quota);

                var available = _printers.TryGetValue(user.SandboxId, out var list)
                    ? list.Where(p => p.Enabled).OrderBy(p => p.Name).ToList()
                    : new List<Printer>();
                var printer = printerId is null
                    ? available.FirstOrDefault()
                    : available.FirstOrDefault(p => p.Id == printerId);
                if (printer is null)
                    return new ReleaseResult(
                        printerId is null ? ReleaseOutcome.NoPrinter : ReleaseOutcome.PrinterUnavailable,
                        Array.Empty<PrintJob>(), 0, 0, user.Quota);

                var pages = chosen.Sum(j => j.Pages);
                if (pages > user.Quota.Left)
                    return new ReleaseResult(ReleaseOutcome.OverQuota, Array.Empty<PrintJob>(), pages,
                        pages - user.Quota.Left, user.Quota, printer.Name);

                var printed = new List<PrintJob>();
                foreach (var job in chosen)
                {
                    var index = _jobs.IndexOf(job);
                    try
                    {
                        _dispatcher.Print(job, printer);
                        _jobs[index] = job with { Status = JobStatus.Printed, PrinterName = printer.Name };
                        user.PagesUsed += job.Pages;
                        printed.Add(_jobs[index]);
                    }
                    catch (Exception e)
                    {
                        _jobs[index] = job with { Status = JobStatus.Failed, FailureReason = e.Message, PrinterName = printer.Name };
                    }
                }
                user.LastSeen = Now;
                return new ReleaseResult(ReleaseOutcome.Printed, printed, printed.Sum(j => j.Pages), 0, user.Quota, printer.Name);
            }
        }

        // ---- quotas and settings -------------------------------------------------

        public bool SetQuota(string requesterId, string userId, int quota)
        {
            lock (_gate)
            {
                var sandbox = SandboxOf(requesterId);
                if (sandbox is null || !_users.TryGetValue(userId, out var user) || user.SandboxId != sandbox)
                    return false;
                user.PrintQuota = quota;
                return true;
            }
        }

        public int? DefaultQuota(string requesterId)
        {
            lock (_gate)
            {
                var sandbox = SandboxOf(requesterId);
                return sandbox is null ? null : DefaultFor(sandbox);
            }
        }

        public bool SetDefaultQuota(string requesterId, int quota)
        {
            lock (_gate)
            {
                var sandbox = SandboxOf(requesterId);
                if (sandbox is null) return false;
                _defaultQuota[sandbox] = quota;
                return true;
            }
        }

        public int SetQuotaForAll(string requesterId, int quota)
        {
            lock (_gate)
            {
                var sandbox = SandboxOf(requesterId);
                if (sandbox is null) return 0;
                var people = _users.Values.Where(u => u.SandboxId == sandbox && !u.IsAdmin).ToList();
                foreach (var person in people) person.PrintQuota = quota;
                return people.Count;
            }
        }

        // ---- printers ------------------------------------------------------------

        public IReadOnlyList<Printer> Printers(string requesterId)
        {
            lock (_gate)
            {
                var sandbox = SandboxOf(requesterId);
                return sandbox is not null && _printers.TryGetValue(sandbox, out var list)
                    ? list.OrderBy(p => p.Name).ToList()
                    : new List<Printer>();
            }
        }

        public Printer? AddPrinter(string requesterId, string name, string location)
        {
            lock (_gate)
            {
                var sandbox = SandboxOf(requesterId);
                if (sandbox is null) return null;
                if (!_printers.TryGetValue(sandbox, out var list)) _printers[sandbox] = list = new List<Printer>();
                if (list.Count >= MaxPrinters) return null;
                var printer = new Printer(NewId(), name.Trim(), location.Trim(), true);
                list.Add(printer);
                return printer;
            }
        }

        public bool UpdatePrinter(string requesterId, string printerId, string name, string location, bool enabled)
        {
            lock (_gate)
            {
                var sandbox = SandboxOf(requesterId);
                if (sandbox is null || !_printers.TryGetValue(sandbox, out var list)) return false;
                var index = list.FindIndex(p => p.Id == printerId);
                if (index < 0) return false;
                list[index] = new Printer(printerId, name.Trim(), location.Trim(), enabled);
                return true;
            }
        }

        public bool DeletePrinter(string requesterId, string printerId)
        {
            lock (_gate)
            {
                var sandbox = SandboxOf(requesterId);
                return sandbox is not null
                    && _printers.TryGetValue(sandbox, out var list)
                    && list.RemoveAll(p => p.Id == printerId) > 0;
            }
        }

        // ---- demo helpers and clean-up -----------------------------------------

        public PrintJob? AddSample(string userId)
        {
            lock (_gate)
            {
                if (!_users.TryGetValue(userId, out var user)) return null;
                var held = _jobs.Where(j => j.UserId == userId && j.Status == JobStatus.Held).ToList();
                if (held.Count >= MaxHeldPerUser) return null;

                // Prefer a document this person has not had yet, then one that is not waiting right now.
                var ever = _jobs.Where(j => j.UserId == userId).Select(j => j.FileName).ToHashSet();
                var waiting = held.Select(j => j.FileName).ToHashSet();
                foreach (var avoid in new[] { ever, waiting })
                {
                    for (var i = 0; i < SampleDocuments.Length; i++)
                    {
                        var (file, pages) = SampleDocuments[(_sampleCursor + i) % SampleDocuments.Length];
                        if (avoid.Contains(file)) continue;
                        _sampleCursor = (_sampleCursor + i + 1) % SampleDocuments.Length;
                        user.LastSeen = Now;
                        return AddJob(userId, user.DisplayName, file, pages, Now, JobStatus.Held);
                    }
                }
                return null;
            }
        }

        /// <summary>Removes demo sandboxes nobody has used for <see cref="IdleLifetime"/>.</summary>
        public int Sweep()
        {
            lock (_gate)
            {
                var cutoff = Now - IdleLifetime;
                var idle = _users.Values
                    .Where(u => u.SandboxId != DefaultSandbox)
                    .GroupBy(u => u.SandboxId)
                    .Where(g => g.Max(u => u.LastSeen) < cutoff)
                    .Select(g => g.Key)
                    .ToList();
                foreach (var sandbox in idle) RemoveSandbox(sandbox);
                return idle.Count;
            }
        }

        /// <summary>How many demo sandboxes exist right now.</summary>
        public int SandboxCount
        {
            get
            {
                lock (_gate)
                    return _users.Values.Where(u => u.SandboxId != DefaultSandbox).Select(u => u.SandboxId).Distinct().Count();
            }
        }

        private void EvictOldestSandboxes(int keep)
        {
            var oldestFirst = _users.Values
                .Where(u => u.SandboxId != DefaultSandbox)
                .GroupBy(u => u.SandboxId)
                .OrderBy(g => g.Max(u => u.LastSeen))
                .Select(g => g.Key)
                .ToList();
            for (var i = 0; i < oldestFirst.Count - keep; i++) RemoveSandbox(oldestFirst[i]);
        }

        private void RemoveSandbox(string sandbox)
        {
            var ids = _users.Values.Where(u => u.SandboxId == sandbox).Select(u => u.Id).ToHashSet();
            foreach (var id in ids) _users.Remove(id);
            _jobs.RemoveAll(j => ids.Contains(j.UserId));
            _printers.Remove(sandbox);
            _defaultQuota.Remove(sandbox);
        }
    }
}
