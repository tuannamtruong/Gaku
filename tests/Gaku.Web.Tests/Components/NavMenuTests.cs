using Bunit;
using Xunit;
using FluentAssertions;
using Gaku.Web.Components.Layout;

namespace Gaku.Web.Tests.Components;

public class NavMenuTests : TestContext
{
    [Fact]
    public void NavMenu_RendersMapLink()
    {
        var cut = RenderComponent<NavMenu>();

        var links = cut.FindAll("a");
        links.Should().Contain(l => l.TextContent.Contains("Map"));
    }

    [Fact]
    public void NavMenu_RendersTrailsLink()
    {
        var cut = RenderComponent<NavMenu>();

        var links = cut.FindAll("a");
        links.Should().Contain(l => l.TextContent.Contains("Trails"));
    }

    [Fact]
    public void NavMenu_RendersBrandName()
    {
        var cut = RenderComponent<NavMenu>();

        cut.Markup.Should().Contain("Gaku");
    }
}
