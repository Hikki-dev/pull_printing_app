namespace PullPrintingBackend.Services
{
    /// <summary>Removes visitors who have been idle for two hours, with their documents.</summary>
    public class DemoCleanupService : BackgroundService
    {
        private readonly IPrintStore _store;
        private readonly ILogger<DemoCleanupService> _log;

        public DemoCleanupService(IPrintStore store, ILogger<DemoCleanupService> log)
        {
            _store = store;
            _log = log;
        }

        protected override async Task ExecuteAsync(CancellationToken stoppingToken)
        {
            using var timer = new PeriodicTimer(TimeSpan.FromMinutes(10));
            while (await timer.WaitForNextTickAsync(stoppingToken))
            {
                var removed = _store.Sweep();
                if (removed > 0) _log.LogInformation("Removed {Count} idle visitors.", removed);
            }
        }
    }
}
