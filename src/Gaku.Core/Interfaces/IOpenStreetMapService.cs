using Gaku.Core.ValueObjects;

namespace Gaku.Core.Interfaces;

public interface IOpenStreetMapService
{
    Task<MapInfo> GetMapInfoAsync(Coordinates center, int zoom, CancellationToken cancellationToken = default);
    Task<IReadOnlyList<NominatimResult>> SearchLocationsAsync(string query, CancellationToken cancellationToken = default);
    Task<IReadOnlyList<OsmTrailData>> GetTrailsInBoundsAsync(BoundingBox bounds, CancellationToken cancellationToken = default);
}

public record MapInfo(
    Coordinates Center,
    int Zoom,
    string TileUrl,
    BoundingBox Bounds);

public record NominatimResult(
    long OsmId,
    string OsmType,
    string DisplayName,
    string Country,
    Coordinates Location,
    BoundingBox? Bounds);

public record OsmTrailData(
    long OsmId,
    string Name,
    string? Surface,
    string? Difficulty,
    IReadOnlyList<Coordinates> Path);

public record BoundingBox(
    double MinLatitude,
    double MinLongitude,
    double MaxLatitude,
    double MaxLongitude);
