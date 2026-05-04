using Gaku.Application.DTOs;
using Gaku.Core.Entities;
using Gaku.Core.Interfaces;
using Gaku.Core.ValueObjects;

namespace Gaku.Application.Services;

public class TrailService(ITrailRepository trailRepository, IUnitOfWork unitOfWork) : ITrailService
{
    public async Task<TrailDto?> GetByIdAsync(Guid id, CancellationToken cancellationToken = default)
    {
        var trail = await trailRepository.GetByIdAsync(id, cancellationToken);
        return trail is null ? null : ToDto(trail);
    }

    public async Task<IReadOnlyList<TrailSummaryDto>> GetAllAsync(CancellationToken cancellationToken = default)
    {
        var trails = await trailRepository.GetAllAsync(cancellationToken);
        return trails.Select(ToSummaryDto).ToList();
    }

    public async Task<IReadOnlyList<TrailSummaryDto>> GetNearbyAsync(
        double latitude, double longitude, double radiusKm, CancellationToken cancellationToken = default)
    {
        var center = new Coordinates(latitude, longitude);
        var trails = await trailRepository.GetNearbyAsync(center, radiusKm, cancellationToken);
        return trails.Select(ToSummaryDto).ToList();
    }

    public async Task<IReadOnlyList<TrailSummaryDto>> SearchAsync(string query, CancellationToken cancellationToken = default)
    {
        var trails = await trailRepository.SearchAsync(query, cancellationToken);
        return trails.Select(ToSummaryDto).ToList();
    }

    public async Task<TrailDto> CreateAsync(CreateTrailRequest request, CancellationToken cancellationToken = default)
    {
        var trail = Trail.Create(
            request.Name,
            request.Description,
            request.Difficulty,
            request.DistanceKm,
            request.ElevationGainMeters,
            new Coordinates(request.StartLatitude, request.StartLongitude),
            new Coordinates(request.EndLatitude, request.EndLongitude),
            request.Country,
            request.Region,
            request.Type);

        foreach (var tag in request.Tags ?? [])
            trail.AddTag(tag);

        await trailRepository.AddAsync(trail, cancellationToken);
        await unitOfWork.SaveChangesAsync(cancellationToken);

        return ToDto(trail);
    }

    public async Task UpdateAsync(Guid id, UpdateTrailRequest request, CancellationToken cancellationToken = default)
    {
        var trail = await trailRepository.GetByIdAsync(id, cancellationToken)
            ?? throw new KeyNotFoundException($"Trail '{id}' was not found.");

        trail.Update(request.Name, request.Description, request.Difficulty, request.DistanceKm, request.ElevationGainMeters);
        await trailRepository.UpdateAsync(trail, cancellationToken);
        await unitOfWork.SaveChangesAsync(cancellationToken);
    }

    public async Task DeleteAsync(Guid id, CancellationToken cancellationToken = default)
    {
        await trailRepository.DeleteAsync(id, cancellationToken);
        await unitOfWork.SaveChangesAsync(cancellationToken);
    }

    private static TrailDto ToDto(Trail t) => new(
        t.Id, t.Name, t.Description, t.Difficulty,
        t.DistanceKm, t.ElevationGainMeters,
        new CoordinatesDto(t.StartPoint.Latitude, t.StartPoint.Longitude),
        new CoordinatesDto(t.EndPoint.Latitude, t.EndPoint.Longitude),
        t.Country, t.Region, t.Type, t.Tags,
        t.Waypoints.Select(w => new WaypointDto(
            w.Id, w.Name,
            new CoordinatesDto(w.Location.Latitude, w.Location.Longitude),
            w.ElevationMeters, w.Description, w.Order)).ToList(),
        t.CreatedAt, t.UpdatedAt);

    private static TrailSummaryDto ToSummaryDto(Trail t) => new(
        t.Id, t.Name, t.Difficulty, t.DistanceKm, t.ElevationGainMeters,
        new CoordinatesDto(t.StartPoint.Latitude, t.StartPoint.Longitude),
        t.Country, t.Region, t.Type, t.Tags);
}
