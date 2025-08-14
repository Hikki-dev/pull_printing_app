var builder = WebApplication.CreateBuilder(args);
builder.Services.AddSingleton<AzureAuthService>();
builder.Services.AddSingleton<UserService>();
builder.Services.AddSingleton<PrintService>();
builder.Services.AddControllers();

var app = builder.Build();
app.UseRouting();
app.UseEndpoints(endpoints => { endpoints.MapControllers(); });
app.Run();
