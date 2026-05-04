using Gaku.Core.Enums;

namespace Gaku.Application.DTOs;

public record TrailDto(
    Guid Id,
    string Name,
    string Description,
    DifficultyLevel Difficulty,
    double DistanceKm,
    int ElevationGainMeters,
    CoordinatesDto StartPoint,
    CoordinatesDto EndPoint,
    string Country,
    string Region,
    TrailType Type,
    IReadOnlyList<string> Tags,
    IReadOnlyList<WaypointDto> Waypoints,
    DateTime CreatedAt,
    DateTime? UpdatedAt);

public record TrailSummaryDto(
    Guid Id,
    string Name,
    DifficultyLevel Difficulty,
    double DistanceKm,
    int ElevationGainMeters,
    CoordinatesDto StartPoint,
    string Country,
    string Region,
    TrailType Type,
    IReadOnlyList<string> Tags);
