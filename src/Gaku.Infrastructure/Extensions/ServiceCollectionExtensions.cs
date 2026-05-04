using Gaku.Application.Interfaces;
using Gaku.Domain.Interfaces;
using Gaku.Infrastructure.Data;
using Gaku.Infrastructure.Repositories;
using Gaku.Infrastructure.Services;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;

namespace Gaku.Infrastructure.Extensions;

public static class ServiceCollectionExtensions
{
    public static IServiceCollection AddInfrastructure(
        this IServiceCollection services, IConfiguration configuration)
    {
        services.AddDbContext<GakuDbContext>(options =>
            options.UseNpgsql(
                configuration.GetConnectionString("DefaultConnection"),
                npgsql => npgsql
                    .UseNetTopologySuite()
                    .MigrationsAssembly(typeof(GakuDbContext).Assembly.FullName)));

        services.AddScoped<IUnitOfWork>(sp => sp.GetRequiredService<GakuDbContext>());
        services.AddScoped<ITrailRepository, TrailRepository>();
        services.AddScoped<IOpenStreetMapService, OpenStreetMapService>();

        services.AddHttpClient(HttpClientNames.Nominatim, client =>
        {
            client.BaseAddress = new Uri("https://nominatim.openstreetmap.org");
            // OSM usage policy requires a meaningful User-Agent
            client.DefaultRequestHeaders.UserAgent.ParseAdd("Gaku/1.0 (hiking-app)");
        });

        services.AddHttpClient(HttpClientNames.Overpass, client =>
        {
            client.BaseAddress = new Uri("https://overpass-api.de");
            client.Timeout = TimeSpan.FromSeconds(60);
        });

        return services;
    }
}
