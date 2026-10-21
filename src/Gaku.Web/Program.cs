using Gaku.Application.Extensions;
using Gaku.Infrastructure.Extensions;
using Prometheus;
using Gaku.Web;
using Gaku.Web.Services;

DotNetEnv.Env.TraversePath().Load();

var builder = WebApplication.CreateBuilder(args);

builder.Services.AddRazorComponents()
    .AddInteractiveServerComponents();

builder.Services.AddApplication();
builder.Services.AddInfrastructure(builder.Configuration);

builder.Services.AddScoped<LeafletInterop>();

// Separate port so /metrics stays off the Service port the Ingress routes to. Unset outside Kubernetes.
if (builder.Configuration.GetValue<int?>("METRICS_PORT") is { } metricsPort)
    builder.Services.AddMetricServer(options => options.Port = (ushort)metricsPort);

var app = builder.Build();

if (!app.Environment.IsDevelopment())
{
    app.UseExceptionHandler("/Error", createScopeForErrors: true);
    app.UseHsts();
    app.UseHttpsRedirection();
}
app.UseStaticFiles();
app.UseAntiforgery();

app.MapRazorComponents<App>()
    .AddInteractiveServerRenderMode();

app.MapGet("/health", () => Results.Ok());

app.Run();
