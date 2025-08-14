using System.Printing;
using PullPrintingBackend.Models;

namespace PullPrintingBackend.Services
{
    public class PrintService
    {
        public void ReleaseJob(PrintJob job, string printerName)
        {
            LocalPrintServer server = new LocalPrintServer();
            PrintQueue queue = server.GetPrintQueue(printerName);
            queue.AddJob(job.FileName);
            job.IsReleased = true;
        }
    }
}
