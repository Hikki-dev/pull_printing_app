using PullPrintingBackend.Models;

namespace PullPrintingBackend.Services
{
    /// <summary>
    /// Sends a released job to a physical printer. Throw to mark the job as failed;
    /// the message becomes the failure reason shown to administrators.
    /// </summary>
    public interface IPrintDispatcher
    {
        void Print(PrintJob job, Printer printer);
    }

    /// <summary>Demo dispatcher: logs the job and prints nothing.</summary>
    public class SimulatedPrintDispatcher : IPrintDispatcher
    {
        private readonly ILogger<SimulatedPrintDispatcher> _log;
        public SimulatedPrintDispatcher(ILogger<SimulatedPrintDispatcher> log) => _log = log;

        public void Print(PrintJob job, Printer printer) =>
            _log.LogInformation("Simulated print: {File} ({Pages} pages) for {User} on {Printer}",
                job.FileName, job.Pages, job.UserName, printer.Name);
    }
}
