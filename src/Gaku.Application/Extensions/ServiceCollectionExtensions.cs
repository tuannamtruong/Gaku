using Gaku.Application.Services;
using Microsoft.Extensions.DependencyInjection;

namespace Gaku.Application.Extensions;

public static class ServiceCollectionExtensions
{
    public static IServiceCollection AddApplication(this IServiceCollection services)
    {
        services.AddScoped<ITrailService, TrailService>();
        services.AddScoped<IMapService, MapService>();
        return services;
    }
}
