using Gaku.Core.Entities;
using Gaku.Core.ValueObjects;

namespace Gaku.Core.Interfaces;

public interface ITrailRepository
{
    Task<Trail?> GetByIdAsync(Guid id, CancellationToken cancellationToken = default);
    Task<IReadOnlyList<Trail>> GetAllAsync(CancellationToken cancellationToken = default);
    Task<IReadOnlyList<Trail>> GetNearbyAsync(Coordinates center, double radiusKm, CancellationToken cancellationToken = default);
    Task<IReadOnlyList<Trail>> SearchAsync(string query, CancellationToken cancellationToken = default);
    Task AddAsync(Trail trail, CancellationToken cancellationToken = default);
    Task UpdateAsync(Trail trail, CancellationToken cancellationToken = default);
    Task DeleteAsync(Guid id, CancellationToken cancellationToken = default);
}
