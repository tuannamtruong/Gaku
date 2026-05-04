using Gaku.Core.Entities;
using Gaku.Core.Interfaces;
using Gaku.Core.ValueObjects;
using Gaku.Infrastructure.Data;
using Microsoft.EntityFrameworkCore;

namespace Gaku.Infrastructure.Repositories;

public class TrailRepository(GakuDbContext context) : ITrailRepository
{
    public async Task<Trail?> GetByIdAsync(Guid id, CancellationToken cancellationToken = default) =>
        await context.Trails
            .Include(t => t.Waypoints)
            .FirstOrDefaultAsync(t => t.Id == id, cancellationToken);

    public async Task<IReadOnlyList<Trail>> GetAllAsync(CancellationToken cancellationToken = default) =>
        await context.Trails
            .Include(t => t.Waypoints)
            .OrderBy(t => t.Name)
            .ToListAsync(cancellationToken);

    public async Task<IReadOnlyList<Trail>> GetNearbyAsync(
        Coordinates center, double radiusKm, CancellationToken cancellationToken = default)
    {
        // Uses PostGIS ST_DWithin for spatial proximity query (radius in metres).
        return await context.Trails
            .FromSqlRaw("""
                SELECT * FROM trails
                WHERE ST_DWithin(
                    start_point::geography,
                    ST_SetSRID(ST_MakePoint({0}, {1}), 4326)::geography,
                    {2}
                )
                ORDER BY ST_Distance(
                    start_point::geography,
                    ST_SetSRID(ST_MakePoint({0}, {1}), 4326)::geography
                )
                """, center.Longitude, center.Latitude, radiusKm * 1000)
            .ToListAsync(cancellationToken);
    }

    public async Task<IReadOnlyList<Trail>> SearchAsync(string query, CancellationToken cancellationToken = default) =>
        await context.Trails
            .Where(t => EF.Functions.ILike(t.Name, $"%{query}%")
                     || EF.Functions.ILike(t.Description, $"%{query}%")
                     || EF.Functions.ILike(t.Country, $"%{query}%")
                     || EF.Functions.ILike(t.Region, $"%{query}%"))
            .OrderBy(t => t.Name)
            .ToListAsync(cancellationToken);

    public async Task AddAsync(Trail trail, CancellationToken cancellationToken = default) =>
        await context.Trails.AddAsync(trail, cancellationToken);

    public Task UpdateAsync(Trail trail, CancellationToken cancellationToken = default)
    {
        context.Trails.Update(trail);
        return Task.CompletedTask;
    }

    public async Task DeleteAsync(Guid id, CancellationToken cancellationToken = default)
    {
        var trail = await context.Trails.FindAsync([id], cancellationToken);
        if (trail is not null)
            context.Trails.Remove(trail);
    }
}
