using Gaku.Application.DTOs;
using Gaku.Application.Interfaces;
using Gaku.Domain.ValueObjects;

namespace Gaku.Application.Services;

public class MapService(IOpenStreetMapService osmService) : IMapService
{
    public async Task<MapInfoDto> GetMapInfoAsync(
        double latitude, double longitude, int zoom, CancellationToken cancellationToken = default)
    {
        var center = new Coordinates(latitude, longitude);
        var mapInfo = await osmService.GetMapInfoAsync(center, zoom, cancellationToken);
        var trails = await osmService.GetTrailsInBoundsAsync(mapInfo.Bounds, cancellationToken);

        return new MapInfoDto(
            new CoordinatesDto(mapInfo.Center.Latitude, mapInfo.Center.Longitude),
            mapInfo.Zoom,
            mapInfo.TileUrl,
            new BoundingBoxDto(
                mapInfo.Bounds.MinLatitude, mapInfo.Bounds.MinLongitude,
                mapInfo.Bounds.MaxLatitude, mapInfo.Bounds.MaxLongitude),
            trails.Select(t => new OsmTrailDataDto(
                t.OsmId, t.Name, t.Surface, t.Difficulty,
                t.Path.Select(p => new CoordinatesDto(p.Latitude, p.Longitude)).ToList()
            )).ToList());
    }

    public async Task<IReadOnlyList<LocationDto>> SearchLocationsAsync(
        string query, CancellationToken cancellationToken = default)
    {
        var results = await osmService.SearchLocationsAsync(query, cancellationToken);

        return results.Select(r => new LocationDto(
            r.OsmId, r.OsmType, r.DisplayName, r.Country,
            new CoordinatesDto(r.Location.Latitude, r.Location.Longitude),
            r.Bounds is null ? null : new BoundingBoxDto(
                r.Bounds.MinLatitude, r.Bounds.MinLongitude,
                r.Bounds.MaxLatitude, r.Bounds.MaxLongitude)
        )).ToList();
    }
}
