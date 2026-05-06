using Gaku.Application.DTOs;
using Gaku.Application.Services;
using Microsoft.AspNetCore.Http.HttpResults;

namespace Gaku.Api.Endpoints;

public static class MapEndpoints
{
    public static IEndpointRouteBuilder MapMapEndpoints(this IEndpointRouteBuilder app)
    {
        var group = app.MapGroup("/api/map").WithTags("Map");

        group.MapGet("/info", GetMapInfo);
        group.MapGet("/locations/search", SearchLocations);

        return app;
    }

    private static async Task<Ok<MapInfoDto>> GetMapInfo(
        double lat, double lon, int zoom, IMapService service, CancellationToken ct)
    {
        var info = await service.GetMapInfoAsync(lat, lon, zoom, ct);
        return TypedResults.Ok(info);
    }

    private static async Task<Ok<IReadOnlyList<LocationDto>>> SearchLocations(
        string q, IMapService service, CancellationToken ct)
    {
        var results = await service.SearchLocationsAsync(q, ct);
        return TypedResults.Ok(results);
    }
}
