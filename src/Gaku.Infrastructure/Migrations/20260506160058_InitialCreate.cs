using System;
using System.Collections.Generic;
using Microsoft.EntityFrameworkCore.Migrations;
using NetTopologySuite.Geometries;

#nullable disable

namespace Gaku.Infrastructure.Migrations
{
    /// <inheritdoc />
    public partial class InitialCreate : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AlterDatabase()
                .Annotation("Npgsql:PostgresExtension:postgis", ",,");

            migrationBuilder.CreateTable(
                name: "Location",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uuid", nullable: false),
                    Name = table.Column<string>(type: "character varying(300)", maxLength: 300, nullable: false),
                    Country = table.Column<string>(type: "character varying(100)", maxLength: 100, nullable: false),
                    Region = table.Column<string>(type: "character varying(200)", maxLength: 200, nullable: true),
                    center = table.Column<Point>(type: "geography(Point,4326)", nullable: false),
                    OsmId = table.Column<long>(type: "bigint", nullable: true),
                    OsmType = table.Column<string>(type: "character varying(20)", maxLength: 20, nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_Location", x => x.Id);
                });

            migrationBuilder.CreateTable(
                name: "Trail",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uuid", nullable: false),
                    Name = table.Column<string>(type: "character varying(200)", maxLength: 200, nullable: false),
                    Description = table.Column<string>(type: "character varying(4000)", maxLength: 4000, nullable: false),
                    Difficulty = table.Column<int>(type: "integer", nullable: false),
                    DistanceKm = table.Column<double>(type: "double precision", nullable: false),
                    ElevationGainMeters = table.Column<int>(type: "integer", nullable: false),
                    start_point = table.Column<Point>(type: "geography(Point,4326)", nullable: false),
                    end_point = table.Column<Point>(type: "geography(Point,4326)", nullable: false),
                    Country = table.Column<string>(type: "character varying(100)", maxLength: 100, nullable: false),
                    Region = table.Column<string>(type: "character varying(200)", maxLength: 200, nullable: false),
                    Type = table.Column<int>(type: "integer", nullable: false),
                    CreatedAt = table.Column<DateTime>(type: "timestamp with time zone", nullable: false),
                    UpdatedAt = table.Column<DateTime>(type: "timestamp with time zone", nullable: true),
                    Tags = table.Column<List<string>>(type: "text[]", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_Trail", x => x.Id);
                });

            migrationBuilder.CreateTable(
                name: "Waypoint",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uuid", nullable: false),
                    Name = table.Column<string>(type: "character varying(200)", maxLength: 200, nullable: false),
                    location = table.Column<Point>(type: "geography(Point,4326)", nullable: false),
                    ElevationMeters = table.Column<double>(type: "double precision", nullable: true),
                    Description = table.Column<string>(type: "character varying(1000)", maxLength: 1000, nullable: true),
                    Order = table.Column<int>(type: "integer", nullable: false),
                    TrailId = table.Column<Guid>(type: "uuid", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_Waypoint", x => x.Id);
                    table.ForeignKey(
                        name: "FK_Waypoint_Trail_TrailId",
                        column: x => x.TrailId,
                        principalTable: "Trail",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.CreateIndex(
                name: "IX_Location_Country",
                table: "Location",
                column: "Country");

            migrationBuilder.CreateIndex(
                name: "IX_Location_OsmId",
                table: "Location",
                column: "OsmId",
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_Trail_Country",
                table: "Trail",
                column: "Country");

            migrationBuilder.CreateIndex(
                name: "IX_Trail_Difficulty",
                table: "Trail",
                column: "Difficulty");

            migrationBuilder.CreateIndex(
                name: "IX_Trail_start_point",
                table: "Trail",
                column: "start_point")
                .Annotation("Npgsql:IndexMethod", "gist");

            migrationBuilder.CreateIndex(
                name: "IX_Waypoint_TrailId",
                table: "Waypoint",
                column: "TrailId");

            migrationBuilder.CreateIndex(
                name: "IX_Waypoint_TrailId_Order",
                table: "Waypoint",
                columns: new[] { "TrailId", "Order" });
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "Location");

            migrationBuilder.DropTable(
                name: "Waypoint");

            migrationBuilder.DropTable(
                name: "Trail");
        }
    }
}
