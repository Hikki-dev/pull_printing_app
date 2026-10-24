using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using PullPrintingBackend.Models;
using PullPrintingBackend.Services;

namespace PullPrintingBackend.Controllers
{
    [ApiController]
    [Route("api/[controller]")]
    [Authorize]
    public class PrintersController : ControllerBase
    {
        private readonly IPrintStore _store;
        public PrintersController(IPrintStore store) => _store = store;

        /// <summary>
        /// The printers people can print to. Administrators also see switched-off ones, so they can switch them back on.
        /// </summary>
        [HttpGet]
        public IReadOnlyList<Printer> List() =>
            _store.Printers(User.UserId()).Where(p => p.Enabled || User.IsInRole(Claims.AdminRole)).ToList();
    }
}
