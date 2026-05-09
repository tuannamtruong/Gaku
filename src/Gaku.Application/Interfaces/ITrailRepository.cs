using Gaku.Domain.Entities;
using Gaku.Domain.ValueObjects;

namespace Gaku.Application.Interfaces;

/// <summary>Persistence contract for <see cref="Trail"/> aggregate roots.</summary>
public interface ITrailRepository
{
    /// <summary>Returns the trail with the given <paramref name="id"/>, or <c>null</c> if not found.</summary>
    Task<Trail?> GetByIdAsync(Guid id, CancellationToken cancellationToken = default);

    /// <summary>Returns all trails in the database.</summary>
    Task<IReadOnlyList<Trail>> GetAllAsync(CancellationToken cancellationToken = default);

    /// <summary>
    /// Returns trails whose start location is within <paramref name="radiusKm"/> kilometres of
    /// <paramref name="center"/>, using PostGIS <c>ST_DWithin</c> on the spatial index.
    /// </summary>
    Task<IReadOnlyList<Trail>> GetNearbyAsync(Coordinates center, double radiusKm, CancellationToken cancellationToken = default);

    /// <summary>Returns trails whose name or description contains <paramref name="query"/> (case-insensitive).</summary>
    Task<IReadOnlyList<Trail>> SearchAsync(string query, CancellationToken cancellationToken = default);

    /// <summary>Persists a new <paramref name="trail"/> to the store.</summary>
    Task AddAsync(Trail trail, CancellationToken cancellationToken = default);

    /// <summary>Applies changes made to an existing <paramref name="trail"/>.</summary>
    Task UpdateAsync(Trail trail, CancellationToken cancellationToken = default);

    /// <summary>Removes the trail with the given <paramref name="id"/>.</summary>
    Task DeleteAsync(Guid id, CancellationToken cancellationToken = default);
}
