using Gaku.Application.DTOs;
using Microsoft.JSInterop;

namespace Gaku.Web.Services;

public sealed class LeafletInterop(IJSRuntime js) : IAsyncDisposable
{
    private IJSObjectReference? _module;

    private async Task<IJSObjectReference> GetModuleAsync() =>
        _module ??= await js.InvokeAsync<IJSObjectReference>(
            "import", "./js/leaflet-interop.js");

    public async Task InitMapAsync(string elementId, double lat, double lon, int zoom)
    {
        var module = await GetModuleAsync();
        await module.InvokeVoidAsync("initMap", elementId, lat, lon, zoom);
    }

    public async Task RenderTrailsAsync(string elementId, IReadOnlyList<OsmTrailDataDto> trails)
    {
        var module = await GetModuleAsync();
        await module.InvokeVoidAsync("renderTrails", elementId, trails);
    }

    public async Task SetViewAsync(string elementId, double lat, double lon, int zoom)
    {
        var module = await GetModuleAsync();
        await module.InvokeVoidAsync("setView", elementId, lat, lon, zoom);
    }

    public async Task DestroyMapAsync(string elementId)
    {
        if (_module is null) return;
        await _module.InvokeVoidAsync("destroyMap", elementId);
    }

    public async ValueTask DisposeAsync()
    {
        if (_module is not null)
            await _module.DisposeAsync();
    }
}
