using Gaku.Application.Extensions;
using Gaku.Infrastructure.Extensions;
using Gaku.Api.Endpoints;
using Scalar.AspNetCore;

DotNetEnv.Env.TraversePath().Load();

var builder = WebApplication.CreateBuilder(args);

builder.Services.AddApplication();
builder.Services.AddInfrastructure(builder.Configuration);

builder.Services.AddOpenApi();
builder.Services.AddCors(options =>
    options.AddDefaultPolicy(policy =>
        policy.AllowAnyOrigin().AllowAnyMethod().AllowAnyHeader()));

var app = builder.Build();

using (var scope = app.Services.CreateScope())
{
    var seeder = scope.ServiceProvider.GetRequiredService<Gaku.Infrastructure.Data.DataSeeder>();
    try { await seeder.SeedAsync(); }
    catch (Exception ex)
    {
        var logger = scope.ServiceProvider.GetRequiredService<ILogger<Program>>();
        logger.LogError(ex, "Seeding failed — continuing without seed data");
    }
}

if (app.Environment.IsDevelopment())
{
    app.MapOpenApi();
    app.MapScalarApiReference();
}

app.UseCors();
app.UseHttpsRedirection();

app.MapGet("/api/health", () => Results.Ok());
app.MapTrailEndpoints();
app.MapMapEndpoints();

app.Run();

// Expose for integration tests
public partial class Program { }
