using Bunit;
using Xunit;
using FluentAssertions;
using Gaku.Application.DTOs;
using Gaku.Application.Services;
using Gaku.Domain.Enums;
using Gaku.Web.Pages;
using Microsoft.Extensions.DependencyInjection;
using NSubstitute;

namespace Gaku.Web.Tests.Components;

public class TrailsPageTests : TestContext
{
    private readonly ITrailService _trailService = Substitute.For<ITrailService>();

    public TrailsPageTests()
    {
        Services.AddSingleton(_trailService);
    }

    [Fact]
    public async Task Trails_ShowsTrailsFromService()
    {
        _trailService.GetAllAsync(Arg.Any<CancellationToken>()).Returns([
            new TrailSummaryDto(
                Guid.NewGuid(), "Via Alpina", DifficultyLevel.Hard,
                2600, 150000, new CoordinatesDto(46.5, 8.0),
                "Europe", "Alps", TrailType.OneWay, ["classic"])
        ]);

        var cut = RenderComponent<Trails>();
        cut.WaitForState(() => cut.Find(".trail-card") is not null);

        cut.FindAll(".trail-card").Should().HaveCount(1);
        cut.Markup.Should().Contain("Via Alpina");
    }

    [Fact]
    public async Task Trails_WhenEmpty_ShowsNoTrailsMessage()
    {
        _trailService.GetAllAsync(Arg.Any<CancellationToken>()).Returns([]);

        var cut = RenderComponent<Trails>();
        cut.WaitForState(() => !cut.Markup.Contains("Loading"));

        cut.Markup.Should().Contain("No trails found");
    }
}
