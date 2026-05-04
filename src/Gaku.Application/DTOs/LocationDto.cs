namespace Gaku.Application.DTOs;

public record LocationDto(
    long OsmId,
    string OsmType,
    string DisplayName,
    string Country,
    CoordinatesDto Location,
    BoundingBoxDto? Bounds);
