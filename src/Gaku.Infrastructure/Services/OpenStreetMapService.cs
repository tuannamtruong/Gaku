using System.Net.Http.Json;
using System.Text.Json;
using System.Text.Json.Serialization;
using Gaku.Application.Interfaces;
using Gaku.Domain.ValueObjects;
using Microsoft.Extensions.Logging;

namespace Gaku.Infrastructure.Services;

public class OpenStreetMapService(
    IHttpClientFactory httpClientFactory,
    ILogger<OpenStreetMapService> logger) : IOpenStreetMapService
{
    private const string TileUrl = "https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png";

    public Task<MapInfo> GetMapInfoAsync(Coordinates center, int zoom, CancellationToken cancellationToken = default)
    {
        var bounds = ComputeBounds(center, zoom);
        return Task.FromResult(new MapInfo(center, zoom, TileUrl, bounds));
    }

    public async Task<IReadOnlyList<NominatimResult>> SearchLocationsAsync(
        string query, CancellationToken cancellationToken = default)
    {
        var client = httpClientFactory.CreateClient(HttpClientNames.Nominatim);
        var url = $"/search?q={Uri.EscapeDataString(query)}&format=json&addressdetails=1&limit=10&countrycodes=";

        try
        {
            var response = await client.GetFromJsonAsync<List<NominatimApiResponse>>(
                url, JsonOptions, cancellationToken);

            return response?.Select(ToNominatimResult).ToList() ?? [];
        }
        catch (Exception ex)
        {
            logger.LogError(ex, "Nominatim search failed for query '{Query}'", query);
            return [];
        }
    }

    public async Task<IReadOnlyList<OsmTrailData>> GetTrailsInBoundsAsync(
        BoundingBox bounds, CancellationToken cancellationToken = default)
    {
        var client = httpClientFactory.CreateClient(HttpClientNames.Overpass);
        var bbox = $"{bounds.MinLatitude},{bounds.MinLongitude},{bounds.MaxLatitude},{bounds.MaxLongitude}";
        var query = $"""
            [out:json][timeout:25];
            (
              way["highway"~"path|track"]["sac_scale"]({bbox});
              way["route"="hiking"]({bbox});
            );
            out body;
            >;
            out skel qt;
            """;

        try
        {
            var content = new FormUrlEncodedContent([
                new KeyValuePair<string, string>("data", query)
            ]);

            var response = await client.PostAsync("/api/interpreter", content, cancellationToken);
            response.EnsureSuccessStatusCode();

            var result = await response.Content.ReadFromJsonAsync<OverpassResponse>(
                JsonOptions, cancellationToken);

            return ParseOverpassElements(result);
        }
        catch (Exception ex)
        {
            logger.LogError(ex, "Overpass query failed for bounds {Bounds}", bounds);
            return [];
        }
    }

    private static IReadOnlyList<OsmTrailData> ParseOverpassElements(OverpassResponse? result)
    {
        if (result?.Elements is null) return [];

        var nodes = result.Elements
            .Where(e => e.Type == "node")
            .ToDictionary(e => e.Id, e => new Coordinates(e.Lat ?? 0, e.Lon ?? 0));

        return result.Elements
            .Where(e => e.Type == "way" && e.Tags is not null && e.Nodes is not null)
            .Select(e => new OsmTrailData(
                e.Id,
                e.Tags!.GetValueOrDefault("name", $"Trail {e.Id}"),
                e.Tags!.GetValueOrDefault("surface"),
                e.Tags!.GetValueOrDefault("sac_scale"),
                e.Nodes!.Where(nodes.ContainsKey).Select(n => nodes[n]).ToList()))
            .Where(t => t.Path.Count > 1)
            .ToList();
    }

    private static BoundingBox ComputeBounds(Coordinates center, int zoom)
    {
        // Approximate degrees per tile at given zoom level
        var delta = 360.0 / Math.Pow(2, zoom);
        return new BoundingBox(
            center.Latitude - delta / 2,
            center.Longitude - delta / 2,
            center.Latitude + delta / 2,
            center.Longitude + delta / 2);
    }

    private static NominatimResult ToNominatimResult(NominatimApiResponse r) => new(
        r.OsmId,
        r.OsmType ?? "node",
        r.DisplayName ?? string.Empty,
        r.Address?.Country ?? string.Empty,
        new Coordinates(r.Lat, r.Lon),
        r.BoundingBox is { Length: 4 }
            ? new BoundingBox(
                double.Parse(r.BoundingBox[0]), double.Parse(r.BoundingBox[2]),
                double.Parse(r.BoundingBox[1]), double.Parse(r.BoundingBox[3]))
            : null);

    private static readonly JsonSerializerOptions JsonOptions = new()
    {
        PropertyNameCaseInsensitive = true,
        NumberHandling = JsonNumberHandling.AllowReadingFromString
    };

    // Internal response models for deserialization
    private sealed class NominatimApiResponse
    {
        [JsonPropertyName("osm_id")] public long OsmId { get; set; }
        [JsonPropertyName("osm_type")] public string? OsmType { get; set; }
        [JsonPropertyName("display_name")] public string? DisplayName { get; set; }
        [JsonPropertyName("lat")] public double Lat { get; set; }
        [JsonPropertyName("lon")] public double Lon { get; set; }
        [JsonPropertyName("boundingbox")] public string[]? BoundingBox { get; set; }
        [JsonPropertyName("address")] public NominatimAddress? Address { get; set; }
    }

    private sealed class NominatimAddress
    {
        [JsonPropertyName("country")] public string? Country { get; set; }
    }

    private sealed class OverpassResponse
    {
        [JsonPropertyName("elements")] public List<OverpassElement>? Elements { get; set; }
    }

    private sealed class OverpassElement
    {
        [JsonPropertyName("type")] public string Type { get; set; } = string.Empty;
        [JsonPropertyName("id")] public long Id { get; set; }
        [JsonPropertyName("lat")] public double? Lat { get; set; }
        [JsonPropertyName("lon")] public double? Lon { get; set; }
        [JsonPropertyName("nodes")] public List<long>? Nodes { get; set; }
        [JsonPropertyName("tags")] public Dictionary<string, string>? Tags { get; set; }
    }
}

public static class HttpClientNames
{
    public const string Nominatim = "Nominatim";
    public const string Overpass = "Overpass";
}
