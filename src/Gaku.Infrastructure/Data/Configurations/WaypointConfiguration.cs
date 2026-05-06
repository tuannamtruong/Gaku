using Gaku.Domain.Entities;
using Gaku.Domain.ValueObjects;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;
using NtsGeometries = NetTopologySuite.Geometries;

namespace Gaku.Infrastructure.Data.Configurations;

public class WaypointConfiguration : IEntityTypeConfiguration<Waypoint>
{
    public void Configure(EntityTypeBuilder<Waypoint> builder)
    {
        builder.ToTable("Waypoint");
        builder.HasKey(w => w.Id);

        builder.Property(w => w.Name)
            .HasMaxLength(200)
            .IsRequired();

        builder.Property(w => w.Description)
            .HasMaxLength(1000);

        builder.Property(w => w.Location)
            .HasConversion(
                c => new NtsGeometries.Point(c.Longitude, c.Latitude) { SRID = 4326 },
                p => new Coordinates(p.Y, p.X))
            .HasColumnType("geography(Point,4326)")
            .HasColumnName("location");

        builder.HasIndex(w => w.TrailId);
        builder.HasIndex(w => new { w.TrailId, w.Order });
    }
}
