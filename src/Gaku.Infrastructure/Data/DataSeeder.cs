using Gaku.Domain.Entities;
using Gaku.Domain.Enums;
using Gaku.Domain.ValueObjects;
using Microsoft.EntityFrameworkCore;

namespace Gaku.Infrastructure.Data;

public class DataSeeder(GakuDbContext context)
{
    public async Task SeedAsync()
    {
        if (await context.Trails.AnyAsync())
            return;

        var zugspitze = Trail.Create(
            name: "Zugspitze Summit Trail",
            description: "A challenging ascent to Germany's highest peak via the Reintal valley. Stunning views of the Alps across four countries from the 2962 m summit.",
            difficulty: DifficultyLevel.Hard,
            distanceKm: 19.0,
            elevationGainMeters: 2200,
            startPoint: new Coordinates(47.4567, 10.9845),
            endPoint: new Coordinates(47.4211, 10.9850),
            country: "Germany",
            region: "Bavaria",
            type: TrailType.OneWay);
        zugspitze.AddTag("alpine");
        zugspitze.AddTag("summit");
        zugspitze.AddTag("bavaria");
        zugspitze.AddWaypoint(Waypoint.Create("Eibsee Trailhead", new Coordinates(47.4567, 10.9845), 1, zugspitze.Id, 974, "Start at the Eibsee lake car park"));
        zugspitze.AddWaypoint(Waypoint.Create("Reintalangerhütte", new Coordinates(47.4388, 10.9812), 2, zugspitze.Id, 1366, "Mountain refuge with refreshments"));
        zugspitze.AddWaypoint(Waypoint.Create("Zugspitze Summit", new Coordinates(47.4211, 10.9850), 3, zugspitze.Id, 2962, "Germany's highest point"));

        var treCime = Trail.Create(
            name: "Tre Cime di Lavaredo Loop",
            description: "Iconic circuit around the three famous Dolomite peaks. The loop offers breathtaking close-up views of the vertical north faces and the surrounding mountain landscape.",
            difficulty: DifficultyLevel.Moderate,
            distanceKm: 10.3,
            elevationGainMeters: 550,
            startPoint: new Coordinates(46.6188, 12.3026),
            endPoint: new Coordinates(46.6188, 12.3026),
            country: "Italy",
            region: "South Tyrol",
            type: TrailType.Loop);
        treCime.AddTag("dolomites");
        treCime.AddTag("iconic");
        treCime.AddTag("loop");
        treCime.AddWaypoint(Waypoint.Create("Rifugio Auronzo", new Coordinates(46.6188, 12.3026), 1, treCime.Id, 2320, "Starting point, café and accommodation"));
        treCime.AddWaypoint(Waypoint.Create("Rifugio Lavaredo", new Coordinates(46.6243, 12.2967), 2, treCime.Id, 2344, "Below the south face of Cima Piccola"));
        treCime.AddWaypoint(Waypoint.Create("Rifugio Locatelli", new Coordinates(46.6312, 12.3021), 3, treCime.Id, 2405, "Best viewpoint of the north faces"));

        var chamonix = Trail.Create(
            name: "Chamonix to Montenvers",
            description: "A classic trail ascending through pine forest from the centre of Chamonix to the Mer de Glace glacier viewpoint above the Montenvers railway station.",
            difficulty: DifficultyLevel.Moderate,
            distanceKm: 5.5,
            elevationGainMeters: 870,
            startPoint: new Coordinates(45.9237, 6.8694),
            endPoint: new Coordinates(45.9325, 6.9141),
            country: "France",
            region: "Auvergne-Rhône-Alpes",
            type: TrailType.OneWay);
        chamonix.AddTag("glacier");
        chamonix.AddTag("mont-blanc");
        chamonix.AddTag("forest");
        chamonix.AddWaypoint(Waypoint.Create("Chamonix Town Centre", new Coordinates(45.9237, 6.8694), 1, chamonix.Id, 1035, "Start near the main square"));
        chamonix.AddWaypoint(Waypoint.Create("Montenvers Station", new Coordinates(45.9325, 6.9141), 2, chamonix.Id, 1913, "Glacier viewpoint and museum"));

        var zugspitzeArea = Location.Create(
            name: "Zugspitze Area",
            country: "Germany",
            center: new Coordinates(47.4211, 10.9850),
            region: "Bavaria");

        var dolomites = Location.Create(
            name: "Dolomites",
            country: "Italy",
            center: new Coordinates(46.6188, 12.3026),
            region: "South Tyrol");

        var chamonixValley = Location.Create(
            name: "Chamonix Valley",
            country: "France",
            center: new Coordinates(45.9237, 6.8694),
            region: "Auvergne-Rhône-Alpes");

        context.Trails.AddRange(zugspitze, treCime, chamonix);
        context.Locations.AddRange(zugspitzeArea, dolomites, chamonixValley);
        await context.SaveChangesAsync();
    }
}
