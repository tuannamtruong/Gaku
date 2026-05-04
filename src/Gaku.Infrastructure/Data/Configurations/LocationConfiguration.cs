using Gaku.Core.Entities;
using Gaku.Core.ValueObjects;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;
using NtsGeometries = NetTopologySuite.Geometries;

namespace Gaku.Infrastructure.Data.Configurations;

public class LocationConfiguration : IEntityTypeConfiguration<Location>
{
    public void Configure(EntityTypeBuilder<Location> builder)
    {
        builder.ToTable("locations");
        builder.HasKey(l => l.Id);

        builder.Property(l => l.Name)
            .HasMaxLength(300)
            .IsRequired();

        builder.Property(l => l.Country)
            .HasMaxLength(100)
            .IsRequired();

        builder.Property(l => l.Region)
            .HasMaxLength(200);

        builder.Property(l => l.OsmType)
            .HasMaxLength(20);

        builder.Property(l => l.Center)
            .HasConversion(
                c => new NtsGeometries.Point(c.Longitude, c.Latitude) { SRID = 4326 },
                p => new Coordinates(p.Y, p.X))
            .HasColumnType("geography(Point,4326)")
            .HasColumnName("center");

        builder.HasIndex(l => l.OsmId).IsUnique();
        builder.HasIndex(l => l.Country);
    }
}
