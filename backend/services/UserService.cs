using PullPrintingBackend.Models;

namespace PullPrintingBackend.Services
{
    public class UserService
    {
        private List<User> _users = new();

        public User GetUserById(string id) => _users.FirstOrDefault(u => u.Id == id);

        public void UpdateQuota(string userId, int quota)
        {
            var user = GetUserById(userId);
            if (user != null) user.PrintQuota = quota;
        }
    }
}
