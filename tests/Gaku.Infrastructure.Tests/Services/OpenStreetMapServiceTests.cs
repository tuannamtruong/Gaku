using FluentAssertions;
using Xunit;
using Gaku.Application.Interfaces;
using Gaku.Domain.ValueObjects;
using Gaku.Infrastructure.Services;
using Microsoft.Extensions.Logging.Abstractions;
using NSubstitute;
using RichardSzalay.MockHttp;
using System.Globalization;
using System.Net.Http.Json;
using System.Text.Json;

namespace Gaku.Infrastructure.Tests.Services;

public class OpenStreetMapServiceTests
{
    [Fact]
    public async Task GetMapInfoAsync_ReturnsTileUrlAndBounds()
    {
        var factory = Substitute.For<IHttpClientFactory>();
        var sut = new OpenStreetMapService(factory, NullLogger<OpenStreetMapService>.Instance);
        var center = new Coordinates(46.8, 8.2);

        var result = await sut.GetMapInfoAsync(center, 7);

        result.Center.Should().Be(center);
        result.Zoom.Should().Be(7);
        result.TileUrl.Should().Contain("openstreetmap.org");
        result.Bounds.MinLatitude.Should().BeLessThan(center.Latitude);
        result.Bounds.MaxLatitude.Should().BeGreaterThan(center.Latitude);
    }

    [Fact]
    public async Task SearchLocationsAsync_ParsesNominatimResponse()
    {
        var nominatimJson = """
            [
              {
                "osm_id": 12345,
                "osm_type": "node",
                "display_name": "Chamonix-Mont-Blanc, Haute-Savoie, France",
                "lat": "45.9237",
                "lon": "6.8694",
                "boundingbox": ["45.90", "45.95", "6.85", "6.90"],
                "address": { "country": "France" }
              }
            ]
            """;

        var mockHttp = new MockHttpMessageHandler();
        mockHttp.When("https://nominatim.openstreetmap.org/*")
            .Respond("application/json", nominatimJson);

        var factory = Substitute.For<IHttpClientFactory>();
        factory.CreateClient(HttpClientNames.Nominatim)
            .Returns(new HttpClient(mockHttp) { BaseAddress = new Uri("https://nominatim.openstreetmap.org") });
        factory.CreateClient(HttpClientNames.Overpass)
            .Returns(new HttpClient());

        var sut = new OpenStreetMapService(factory, NullLogger<OpenStreetMapService>.Instance);

        var results = await sut.SearchLocationsAsync("Chamonix");

        results.Should().HaveCount(1);
        results[0].DisplayName.Should().Contain("Chamonix");
        results[0].Country.Should().Be("France");
        results[0].OsmId.Should().Be(12345);
        results[0].Location.Latitude.Should().BeApproximately(45.9237, 0.001);
    }

    [Fact]
    public async Task SearchLocationsAsync_OnHttpError_ReturnsEmpty()
    {
        var mockHttp = new MockHttpMessageHandler();
        mockHttp.When("*").Respond(System.Net.HttpStatusCode.InternalServerError);

        var factory = Substitute.For<IHttpClientFactory>();
        factory.CreateClient(HttpClientNames.Nominatim)
            .Returns(new HttpClient(mockHttp) { BaseAddress = new Uri("https://nominatim.openstreetmap.org") });

        var sut = new OpenStreetMapService(factory, NullLogger<OpenStreetMapService>.Instance);

        var results = await sut.SearchLocationsAsync("Broken");

        results.Should().BeEmpty();
    }

    [Fact]
    public async Task GetTrailsInBoundsAsync_UsesDotDecimalSeparator_UnderGermanLocale()
    {
        string? capturedBody = null;
        var handler = new CapturingHttpHandler(req =>
        {
            capturedBody = req.Content!.ReadAsStringAsync().GetAwaiter().GetResult();
            return new HttpResponseMessage(System.Net.HttpStatusCode.OK)
            {
                Content = new StringContent("""{"elements":[]}""", System.Text.Encoding.UTF8, "application/json")
            };
        });

        var factory = Substitute.For<IHttpClientFactory>();
        factory.CreateClient(HttpClientNames.Overpass)
            .Returns(new HttpClient(handler) { BaseAddress = new Uri("https://overpass-api.de") });

        var sut = new OpenStreetMapService(factory, NullLogger<OpenStreetMapService>.Instance);
        var bounds = new BoundingBox(45.39375, 6.79375, 48.20625, 9.60625);

        var originalCulture = CultureInfo.CurrentCulture;
        try
        {
            CultureInfo.CurrentCulture = new CultureInfo("de-DE");
            await sut.GetTrailsInBoundsAsync(bounds);
        }
        finally
        {
            CultureInfo.CurrentCulture = originalCulture;
        }

        capturedBody.Should().NotBeNull();
        capturedBody.Should().Contain("45.39375", "bbox must use dot as decimal separator regardless of OS locale");
        capturedBody.Should().NotContain("45,39375", "comma decimal separator breaks the Overpass query");
    }

    private sealed class CapturingHttpHandler(Func<HttpRequestMessage, HttpResponseMessage> respond)
        : HttpMessageHandler
    {
        protected override Task<HttpResponseMessage> SendAsync(
            HttpRequestMessage request, CancellationToken cancellationToken) =>
            Task.FromResult(respond(request));
    }
}
