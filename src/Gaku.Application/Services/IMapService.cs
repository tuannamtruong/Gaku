using Gaku.Application.DTOs;

namespace Gaku.Application.Services;

public interface IMapService
{
    Task<MapInfoDto> GetMapInfoAsync(double latitude, double longitude, int zoom, CancellationToken cancellationToken = default);
    Task<IReadOnlyList<LocationDto>> SearchLocationsAsync(string query, CancellationToken cancellationToken = default);
}
