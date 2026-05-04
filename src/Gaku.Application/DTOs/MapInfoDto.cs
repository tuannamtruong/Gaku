namespace Gaku.Application.DTOs;

public record MapInfoDto(
    CoordinatesDto Center,
    int Zoom,
    string TileUrl,
    BoundingBoxDto Bounds,
    IReadOnlyList<OsmTrailDataDto> NearbyTrails);

public record OsmTrailDataDto(
    long OsmId,
    string Name,
    string? Surface,
    string? Difficulty,
    IReadOnlyList<CoordinatesDto> Path);
