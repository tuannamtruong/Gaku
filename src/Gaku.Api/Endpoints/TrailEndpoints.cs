using Gaku.Application.DTOs;
using Gaku.Application.Services;
using Microsoft.AspNetCore.Http.HttpResults;

namespace Gaku.Api.Endpoints;

public static class TrailEndpoints
{
    public static IEndpointRouteBuilder MapTrailEndpoints(this IEndpointRouteBuilder app)
    {
        var group = app.MapGroup("/api/trails").WithTags("Trails");

        group.MapGet("/", GetAll);
        group.MapGet("/{id:guid}", GetById);
        group.MapGet("/nearby", GetNearby);
        group.MapGet("/search", Search);
        group.MapPost("/", Create);
        group.MapPut("/{id:guid}", Update);
        group.MapDelete("/{id:guid}", Delete);

        return app;
    }

    private static async Task<Ok<IReadOnlyList<TrailSummaryDto>>> GetAll(
        ITrailService service, CancellationToken ct)
    {
        var trails = await service.GetAllAsync(ct);
        return TypedResults.Ok(trails);
    }

    private static async Task<Results<Ok<TrailDto>, NotFound>> GetById(
        Guid id, ITrailService service, CancellationToken ct)
    {
        var trail = await service.GetByIdAsync(id, ct);
        return trail is null ? TypedResults.NotFound() : TypedResults.Ok(trail);
    }

    private static async Task<Ok<IReadOnlyList<TrailSummaryDto>>> GetNearby(
        double lat, double lon, double radiusKm, ITrailService service, CancellationToken ct)
    {
        var trails = await service.GetNearbyAsync(lat, lon, radiusKm, ct);
        return TypedResults.Ok(trails);
    }

    private static async Task<Ok<IReadOnlyList<TrailSummaryDto>>> Search(
        string q, ITrailService service, CancellationToken ct)
    {
        var trails = await service.SearchAsync(q, ct);
        return TypedResults.Ok(trails);
    }

    private static async Task<Created<TrailDto>> Create(
        CreateTrailRequest request, ITrailService service, CancellationToken ct)
    {
        var trail = await service.CreateAsync(request, ct);
        return TypedResults.Created($"/api/trails/{trail.Id}", trail);
    }

    private static async Task<Results<NoContent, NotFound>> Update(
        Guid id, UpdateTrailRequest request, ITrailService service, CancellationToken ct)
    {
        try
        {
            await service.UpdateAsync(id, request, ct);
            return TypedResults.NoContent();
        }
        catch (KeyNotFoundException)
        {
            return TypedResults.NotFound();
        }
    }

    private static async Task<NoContent> Delete(
        Guid id, ITrailService service, CancellationToken ct)
    {
        await service.DeleteAsync(id, ct);
        return TypedResults.NoContent();
    }
}
