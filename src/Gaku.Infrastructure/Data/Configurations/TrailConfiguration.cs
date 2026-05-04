using Gaku.Domain.Entities;
using Gaku.Domain.ValueObjects;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;
using NtsGeometries = NetTopologySuite.Geometries;

namespace Gaku.Infrastructure.Data.Configurations;

public class TrailConfiguration : IEntityTypeConfiguration<Trail>
{
    public void Configure(EntityTypeBuilder<Trail> builder)
    {
        builder.ToTable("trails");
        builder.HasKey(t => t.Id);

        builder.Property(t => t.Name)
            .HasMaxLength(200)
            .IsRequired();

        builder.Property(t => t.Description)
            .HasMaxLength(4000);

        builder.Property(t => t.Country)
            .HasMaxLength(100)
            .IsRequired();

        builder.Property(t => t.Region)
            .HasMaxLength(200);

        builder.Property(t => t.Difficulty)
            .HasConversion<int>();

        builder.Property(t => t.Type)
            .HasConversion<int>();

        builder.Property(t => t.Tags)
            .HasColumnType("text[]");

        // Map Coordinates value object to PostGIS geography columns using value converters.
        // The Point stores (longitude, latitude) per GeoJSON convention; X=lon, Y=lat.
        builder.Property(t => t.StartPoint)
            .HasConversion(
                c => new NtsGeometries.Point(c.Longitude, c.Latitude) { SRID = 4326 },
                p => new Coordinates(p.Y, p.X))
            .HasColumnType("geography(Point,4326)")
            .HasColumnName("start_point");

        builder.Property(t => t.EndPoint)
            .HasConversion(
                c => new NtsGeometries.Point(c.Longitude, c.Latitude) { SRID = 4326 },
                p => new Coordinates(p.Y, p.X))
            .HasColumnType("geography(Point,4326)")
            .HasColumnName("end_point");

        builder.HasMany(t => t.Waypoints)
            .WithOne()
            .HasForeignKey(w => w.TrailId)
            .OnDelete(DeleteBehavior.Cascade);

        builder.HasIndex(t => t.Country);
        builder.HasIndex(t => t.Difficulty);
        builder.HasIndex("start_point").HasMethod("gist");
    }
}
