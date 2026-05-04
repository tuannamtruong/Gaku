using Gaku.Domain.ValueObjects;

namespace Gaku.Application.Interfaces;

/// <summary>
/// Facade over OpenStreetMap external services: Nominatim (geocoding) and the Overpass API (trail data).
/// </summary>
public interface IOpenStreetMapService
{
    /// <summary>Builds map metadata — tile URL, bounds, and zoom — for the given <paramref name="center"/>.</summary>
    Task<MapInfo> GetMapInfoAsync(Coordinates center, int zoom, CancellationToken cancellationToken = default);

    /// <summary>
    /// Geocodes <paramref name="query"/> via Nominatim and returns matching locations.
    /// Rate-limited to 1 request/second per Nominatim policy.
    /// </summary>
    Task<IReadOnlyList<NominatimResult>> SearchLocationsAsync(string query, CancellationToken cancellationToken = default);

    /// <summary>
    /// Fetches hiking paths within <paramref name="bounds"/> from the Overpass API
    /// (<c>highway=path/track</c> with <c>sac_scale</c> or <c>route=hiking</c>).
    /// </summary>
    Task<IReadOnlyList<OsmTrailData>> GetTrailsInBoundsAsync(BoundingBox bounds, CancellationToken cancellationToken = default);
}

/// <summary>Map display metadata returned by <see cref="IOpenStreetMapService.GetMapInfoAsync"/>.</summary>
public record MapInfo(
    Coordinates Center,
    int Zoom,
    string TileUrl,
    BoundingBox Bounds);

/// <summary>A single geocoding result from the Nominatim <c>/search</c> endpoint.</summary>
public record NominatimResult(
    long OsmId,
    string OsmType,
    string DisplayName,
    string Country,
    Coordinates Location,
    BoundingBox? Bounds);

/// <summary>Raw trail geometry and tags retrieved from the Overpass API.</summary>
public record OsmTrailData(
    long OsmId,
    string Name,
    string? Surface,
    string? Difficulty,
    IReadOnlyList<Coordinates> Path);

/// <summary>Axis-aligned geographic bounding box expressed in WGS-84 decimal degrees.</summary>
public record BoundingBox(
    double MinLatitude,
    double MinLongitude,
    double MaxLatitude,
    double MaxLongitude);
