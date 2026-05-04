namespace Gaku.Application.DTOs;

public record WaypointDto(
    Guid Id,
    string Name,
    CoordinatesDto Location,
    double? ElevationMeters,
    string? Description,
    int Order);
