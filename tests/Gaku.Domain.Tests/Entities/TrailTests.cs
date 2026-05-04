using FluentAssertions;
using Xunit;
using Gaku.Domain.Entities;
using Gaku.Domain.Enums;
using Gaku.Domain.ValueObjects;

namespace Gaku.Domain.Tests.Entities;

public class TrailTests
{
    private static readonly Coordinates Alps = new(46.5, 8.0);
    private static readonly Coordinates Pyrenees = new(42.8, 0.7);

    [Fact]
    public void Create_WithValidData_ReturnsTrail()
    {
        var trail = Trail.Create(
            "Tour du Mont Blanc", "Classic circuit route",
            DifficultyLevel.Hard, 170, 10000,
            Alps, Alps, "France/Italy/Switzerland", "Alps", TrailType.Loop);

        trail.Id.Should().NotBeEmpty();
        trail.Name.Should().Be("Tour du Mont Blanc");
        trail.DistanceKm.Should().Be(170);
        trail.ElevationGainMeters.Should().Be(10000);
        trail.CreatedAt.Should().BeCloseTo(DateTime.UtcNow, TimeSpan.FromSeconds(5));
        trail.UpdatedAt.Should().BeNull();
    }

    [Theory]
    [InlineData("")]
    [InlineData("   ")]
    public void Create_WithEmptyName_Throws(string name)
    {
        var act = () => Trail.Create(name, "desc",
            DifficultyLevel.Easy, 10, 500, Alps, Alps, "France", "Alps", TrailType.Loop);

        act.Should().Throw<ArgumentException>();
    }

    [Fact]
    public void Create_WithZeroDistance_Throws()
    {
        var act = () => Trail.Create("Trail", "desc",
            DifficultyLevel.Easy, 0, 500, Alps, Alps, "France", "Alps", TrailType.Loop);

        act.Should().Throw<ArgumentOutOfRangeException>();
    }

    [Fact]
    public void AddTag_NormalisesAndDeduplicates()
    {
        var trail = CreateTrail();

        trail.AddTag("Alpine");
        trail.AddTag("alpine");
        trail.AddTag("  ALPINE  ");

        trail.Tags.Should().ContainSingle().Which.Should().Be("alpine");
    }

    [Fact]
    public void Update_ChangesPropertiesAndSetsUpdatedAt()
    {
        var trail = CreateTrail();

        trail.Update("New Name", "New desc", DifficultyLevel.Expert, 200, 12000);

        trail.Name.Should().Be("New Name");
        trail.Difficulty.Should().Be(DifficultyLevel.Expert);
        trail.UpdatedAt.Should().NotBeNull()
            .And.BeCloseTo(DateTime.UtcNow, TimeSpan.FromSeconds(5));
    }

    [Fact]
    public void AddWaypoint_AppendsToCollection()
    {
        var trail = CreateTrail();
        var waypoint = Waypoint.Create("Summit", Alps, 1, trail.Id, 4807);

        trail.AddWaypoint(waypoint);

        trail.Waypoints.Should().ContainSingle().Which.Name.Should().Be("Summit");
    }

    private static Trail CreateTrail() =>
        Trail.Create("Via Alpina", "Long-distance route",
            DifficultyLevel.Moderate, 2600, 150000,
            Alps, Pyrenees, "Europe", "Alps", TrailType.OneWay);
}
