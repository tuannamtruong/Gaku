using Gaku.Core.Enums;
using Gaku.Core.ValueObjects;

namespace Gaku.Core.Entities;

public class Trail
{
    public Guid Id { get; private set; }
    public string Name { get; private set; } = string.Empty;
    public string Description { get; private set; } = string.Empty;
    public DifficultyLevel Difficulty { get; private set; }
    public double DistanceKm { get; private set; }
    public int ElevationGainMeters { get; private set; }
    public Coordinates StartPoint { get; private set; } = default!;
    public Coordinates EndPoint { get; private set; } = default!;
    public string Country { get; private set; } = string.Empty;
    public string Region { get; private set; } = string.Empty;
    public TrailType Type { get; private set; }
    public DateTime CreatedAt { get; private set; }
    public DateTime? UpdatedAt { get; private set; }

    // EF Core accesses the backing fields directly via configuration
    public List<string> Tags { get; private set; } = [];

    private readonly List<Waypoint> _waypoints = [];
    public IReadOnlyList<Waypoint> Waypoints => _waypoints.AsReadOnly();

    private Trail() { }

    public static Trail Create(
        string name,
        string description,
        DifficultyLevel difficulty,
        double distanceKm,
        int elevationGainMeters,
        Coordinates startPoint,
        Coordinates endPoint,
        string country,
        string region,
        TrailType type)
    {
        ArgumentException.ThrowIfNullOrWhiteSpace(name);
        ArgumentException.ThrowIfNullOrWhiteSpace(country);
        ArgumentOutOfRangeException.ThrowIfNegativeOrZero(distanceKm);
        ArgumentNullException.ThrowIfNull(startPoint);
        ArgumentNullException.ThrowIfNull(endPoint);

        return new Trail
        {
            Id = Guid.NewGuid(),
            Name = name,
            Description = description,
            Difficulty = difficulty,
            DistanceKm = distanceKm,
            ElevationGainMeters = elevationGainMeters,
            StartPoint = startPoint,
            EndPoint = endPoint,
            Country = country,
            Region = region,
            Type = type,
            CreatedAt = DateTime.UtcNow
        };
    }

    public void AddWaypoint(Waypoint waypoint)
    {
        ArgumentNullException.ThrowIfNull(waypoint);
        _waypoints.Add(waypoint);
    }

    public void AddTag(string tag)
    {
        ArgumentException.ThrowIfNullOrWhiteSpace(tag);
        var normalised = tag.ToLowerInvariant().Trim();
        if (!Tags.Contains(normalised, StringComparer.OrdinalIgnoreCase))
            Tags.Add(normalised);
    }

    public void Update(
        string name,
        string description,
        DifficultyLevel difficulty,
        double distanceKm,
        int elevationGainMeters)
    {
        ArgumentException.ThrowIfNullOrWhiteSpace(name);
        ArgumentOutOfRangeException.ThrowIfNegativeOrZero(distanceKm);

        Name = name;
        Description = description;
        Difficulty = difficulty;
        DistanceKm = distanceKm;
        ElevationGainMeters = elevationGainMeters;
        UpdatedAt = DateTime.UtcNow;
    }
}
