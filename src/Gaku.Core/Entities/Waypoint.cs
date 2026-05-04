using Gaku.Core.ValueObjects;

namespace Gaku.Core.Entities;

public class Waypoint
{
    public Guid Id { get; private set; }
    public string Name { get; private set; } = string.Empty;
    public Coordinates Location { get; private set; } = default!;
    public double? ElevationMeters { get; private set; }
    public string? Description { get; private set; }
    public int Order { get; private set; }
    public Guid TrailId { get; private set; }

    private Waypoint() { }

    public static Waypoint Create(
        string name,
        Coordinates location,
        int order,
        Guid trailId,
        double? elevationMeters = null,
        string? description = null)
    {
        ArgumentException.ThrowIfNullOrWhiteSpace(name);
        ArgumentNullException.ThrowIfNull(location);

        return new Waypoint
        {
            Id = Guid.NewGuid(),
            Name = name,
            Location = location,
            Order = order,
            TrailId = trailId,
            ElevationMeters = elevationMeters,
            Description = description
        };
    }
}
