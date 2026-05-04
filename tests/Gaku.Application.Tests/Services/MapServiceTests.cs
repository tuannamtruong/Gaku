using FluentAssertions;
using Xunit;
using Gaku.Application.Services;
using Gaku.Application.Interfaces;
using Gaku.Domain.ValueObjects;
using NSubstitute;

namespace Gaku.Application.Tests.Services;

public class MapServiceTests
{
    private readonly IOpenStreetMapService _osmService = Substitute.For<IOpenStreetMapService>();
    private readonly MapService _sut;

    public MapServiceTests() => _sut = new MapService(_osmService);

    [Fact]
    public async Task GetMapInfoAsync_ReturnsMappedDto()
    {
        var center = new Coordinates(46.8, 8.2);
        var bounds = new BoundingBox(46.0, 7.4, 47.6, 9.0);
        var mapInfo = new MapInfo(center, 7, "https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png", bounds);

        _osmService.GetMapInfoAsync(Arg.Any<Coordinates>(), Arg.Any<int>(), Arg.Any<CancellationToken>())
            .Returns(mapInfo);
        _osmService.GetTrailsInBoundsAsync(Arg.Any<BoundingBox>(), Arg.Any<CancellationToken>())
            .Returns([]);

        var result = await _sut.GetMapInfoAsync(46.8, 8.2, 7);

        result.Center.Latitude.Should().Be(46.8);
        result.Center.Longitude.Should().Be(8.2);
        result.Zoom.Should().Be(7);
        result.TileUrl.Should().Contain("openstreetmap");
        result.NearbyTrails.Should().BeEmpty();
    }

    [Fact]
    public async Task GetMapInfoAsync_MapsOsmTrailsToDtos()
    {
        var center = new Coordinates(46.0, 8.0);
        var bounds = new BoundingBox(45.5, 7.5, 46.5, 8.5);
        var mapInfo = new MapInfo(center, 12, "https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png", bounds);
        var osmTrail = new OsmTrailData(
            123456, "Höhenweg", "rock", "alpine",
            [new Coordinates(46.0, 8.0), new Coordinates(46.1, 8.1)]);

        _osmService.GetMapInfoAsync(Arg.Any<Coordinates>(), Arg.Any<int>(), Arg.Any<CancellationToken>())
            .Returns(mapInfo);
        _osmService.GetTrailsInBoundsAsync(Arg.Any<BoundingBox>(), Arg.Any<CancellationToken>())
            .Returns([osmTrail]);

        var result = await _sut.GetMapInfoAsync(46.0, 8.0, 12);

        result.NearbyTrails.Should().HaveCount(1);
        result.NearbyTrails[0].Name.Should().Be("Höhenweg");
        result.NearbyTrails[0].Path.Should().HaveCount(2);
    }

    [Fact]
    public async Task SearchLocationsAsync_ReturnsMappedDtos()
    {
        _osmService.SearchLocationsAsync("Zermatt", Arg.Any<CancellationToken>())
            .Returns([
                new NominatimResult(
                    123, "node", "Zermatt, Valais, Switzerland", "Switzerland",
                    new Coordinates(46.02, 7.75), null)
            ]);

        var results = await _sut.SearchLocationsAsync("Zermatt");

        results.Should().HaveCount(1);
        results[0].DisplayName.Should().Contain("Zermatt");
        results[0].Country.Should().Be("Switzerland");
    }
}
