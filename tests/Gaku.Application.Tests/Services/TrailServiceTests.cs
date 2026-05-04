using FluentAssertions;
using Xunit;
using Gaku.Application.Services;
using Gaku.Core.Entities;
using Gaku.Core.Enums;
using Gaku.Core.Interfaces;
using Gaku.Core.ValueObjects;
using NSubstitute;

namespace Gaku.Application.Tests.Services;

public class TrailServiceTests
{
    private readonly ITrailRepository _repo = Substitute.For<ITrailRepository>();
    private readonly IUnitOfWork _uow = Substitute.For<IUnitOfWork>();
    private readonly TrailService _sut;

    public TrailServiceTests() => _sut = new TrailService(_repo, _uow);

    [Fact]
    public async Task GetByIdAsync_ExistingId_ReturnsMappedDto()
    {
        var trail = CreateTrail();
        _repo.GetByIdAsync(trail.Id, Arg.Any<CancellationToken>()).Returns(trail);

        var result = await _sut.GetByIdAsync(trail.Id);

        result.Should().NotBeNull();
        result!.Name.Should().Be(trail.Name);
        result.Country.Should().Be("Switzerland");
    }

    [Fact]
    public async Task GetByIdAsync_MissingId_ReturnsNull()
    {
        _repo.GetByIdAsync(Arg.Any<Guid>(), Arg.Any<CancellationToken>()).Returns((Trail?)null);

        var result = await _sut.GetByIdAsync(Guid.NewGuid());

        result.Should().BeNull();
    }

    [Fact]
    public async Task CreateAsync_ValidRequest_PersistsAndReturnsDto()
    {
        var request = new CreateTrailRequest(
            "Haute Route", "Chamonix to Zermatt classic route",
            DifficultyLevel.Hard, 180, 12000,
            45.9237, 6.8694, 46.0207, 7.7491,
            "Switzerland/France", "Alps", TrailType.OneWay,
            ["classic", "glacier"]);

        var result = await _sut.CreateAsync(request);

        result.Name.Should().Be("Haute Route");
        result.Tags.Should().Contain("classic").And.Contain("glacier");
        await _repo.Received(1).AddAsync(Arg.Any<Trail>(), Arg.Any<CancellationToken>());
        await _uow.Received(1).SaveChangesAsync(Arg.Any<CancellationToken>());
    }

    [Fact]
    public async Task UpdateAsync_MissingTrail_ThrowsKeyNotFoundException()
    {
        _repo.GetByIdAsync(Arg.Any<Guid>(), Arg.Any<CancellationToken>()).Returns((Trail?)null);
        var request = new UpdateTrailRequest("Name", "Desc", DifficultyLevel.Easy, 10, 500);

        var act = async () => await _sut.UpdateAsync(Guid.NewGuid(), request);

        await act.Should().ThrowAsync<KeyNotFoundException>();
    }

    private static Trail CreateTrail() =>
        Trail.Create("Zermatt Loop", "Stunning Matterhorn views",
            DifficultyLevel.Moderate, 25, 1800,
            new Coordinates(46.02, 7.75), new Coordinates(46.02, 7.75),
            "Switzerland", "Valais", TrailType.Loop);
}
