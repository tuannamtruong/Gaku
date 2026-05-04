using Gaku.Application.DTOs;
using Gaku.Domain.Enums;

namespace Gaku.Application.Services;

public interface ITrailService
{
    Task<TrailDto?> GetByIdAsync(Guid id, CancellationToken cancellationToken = default);
    Task<IReadOnlyList<TrailSummaryDto>> GetAllAsync(CancellationToken cancellationToken = default);
    Task<IReadOnlyList<TrailSummaryDto>> GetNearbyAsync(double latitude, double longitude, double radiusKm, CancellationToken cancellationToken = default);
    Task<IReadOnlyList<TrailSummaryDto>> SearchAsync(string query, CancellationToken cancellationToken = default);
    Task<TrailDto> CreateAsync(CreateTrailRequest request, CancellationToken cancellationToken = default);
    Task UpdateAsync(Guid id, UpdateTrailRequest request, CancellationToken cancellationToken = default);
    Task DeleteAsync(Guid id, CancellationToken cancellationToken = default);
}

public record CreateTrailRequest(
    string Name,
    string Description,
    DifficultyLevel Difficulty,
    double DistanceKm,
    int ElevationGainMeters,
    double StartLatitude,
    double StartLongitude,
    double EndLatitude,
    double EndLongitude,
    string Country,
    string Region,
    TrailType Type,
    IReadOnlyList<string>? Tags = null);

public record UpdateTrailRequest(
    string Name,
    string Description,
    DifficultyLevel Difficulty,
    double DistanceKm,
    int ElevationGainMeters);
