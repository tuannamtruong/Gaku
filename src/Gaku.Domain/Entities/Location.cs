using Gaku.Domain.ValueObjects;

namespace Gaku.Domain.Entities;

public class Location
{
    public Guid Id { get; private set; }
    public string Name { get; private set; } = string.Empty;
    public string Country { get; private set; } = string.Empty;
    public string? Region { get; private set; }
    public Coordinates Center { get; private set; } = default!;
    public long? OsmId { get; private set; }
    public string? OsmType { get; private set; }

    private Location() { }

    public static Location Create(
        string name,
        string country,
        Coordinates center,
        string? region = null,
        long? osmId = null,
        string? osmType = null)
    {
        ArgumentException.ThrowIfNullOrWhiteSpace(name);
        ArgumentException.ThrowIfNullOrWhiteSpace(country);
        ArgumentNullException.ThrowIfNull(center);

        return new Location
        {
            Id = Guid.NewGuid(),
            Name = name,
            Country = country,
            Center = center,
            Region = region,
            OsmId = osmId,
            OsmType = osmType
        };
    }
}
