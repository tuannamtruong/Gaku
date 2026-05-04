using Gaku.Core.Entities;
using Microsoft.EntityFrameworkCore;

namespace Gaku.Infrastructure.Data;

public partial class GakuDbContext(DbContextOptions<GakuDbContext> options) : DbContext(options)
{
    public DbSet<Trail> Trails => Set<Trail>();
    public DbSet<Waypoint> Waypoints => Set<Waypoint>();
    public DbSet<Location> Locations => Set<Location>();

    protected override void OnModelCreating(ModelBuilder modelBuilder)
    {
        base.OnModelCreating(modelBuilder);
        modelBuilder.HasPostgresExtension("postgis");
        modelBuilder.ApplyConfigurationsFromAssembly(typeof(GakuDbContext).Assembly);
    }
}
