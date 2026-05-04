using FluentAssertions;
using Xunit;
using Gaku.Core.ValueObjects;

namespace Gaku.Core.Tests.ValueObjects;

public class CoordinatesTests
{
    [Fact]
    public void Constructor_ValidLatLon_Succeeds()
    {
        var coord = new Coordinates(48.8566, 2.3522);

        coord.Latitude.Should().Be(48.8566);
        coord.Longitude.Should().Be(2.3522);
    }

    [Theory]
    [InlineData(-91)]
    [InlineData(91)]
    public void Constructor_InvalidLatitude_Throws(double lat)
    {
        var act = () => new Coordinates(lat, 0);
        act.Should().Throw<ArgumentOutOfRangeException>().WithParameterName("latitude");
    }

    [Theory]
    [InlineData(-181)]
    [InlineData(181)]
    public void Constructor_InvalidLongitude_Throws(double lon)
    {
        var act = () => new Coordinates(0, lon);
        act.Should().Throw<ArgumentOutOfRangeException>().WithParameterName("longitude");
    }

    [Fact]
    public void DistanceToKm_ParisToLondon_ReturnsApprox340Km()
    {
        var paris = new Coordinates(48.8566, 2.3522);
        var london = new Coordinates(51.5074, -0.1278);

        var dist = paris.DistanceToKm(london);

        dist.Should().BeApproximately(340, 5);
    }

    [Fact]
    public void Equality_SameValues_AreEqual()
    {
        var a = new Coordinates(46.0, 7.0);
        var b = new Coordinates(46.0, 7.0);

        a.Should().Be(b);
    }
}
