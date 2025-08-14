namespace PullPrintingBackend.Models
{
    public class PrintJob
    {
        public string Id { get; set; }
        public string UserId { get; set; }
        public string FileName { get; set; }
        public bool IsReleased { get; set; }
        public DateTime SubmittedAt { get; set; }
    }
}
