# Glossary

Terms used when Gaku turns Overpass data into trails on the map. For the query itself see [osm-integration.md](osm-integration.md).

## 1. Terms

The table follows the order in which the data is built, and each term comes after the terms it depends on.

| Term | Meaning | In code |
| --- | --- | --- |
| Overpass node | An OSM element with an ID and a latitude/longitude. It carries no tags in our response (`out skel`). | `OverpassElement` with `Type == "node"` |
| Overpass way | An OSM element with an ID, tags, and an ordered list of node IDs. It has no coordinates of its own. | `OverpassElement` with `Type == "way"` |
| Point | One latitude/longitude pair, built from an Overpass node. | `Coordinates` |
| Path | The ordered points of one OSM trail, in the order the way lists its node IDs. | `OsmTrailData.Path` |
| OSM trail | A hiking trail read from Overpass and shown on the map; never stored in the database. | `OsmTrailData`, `OsmTrailDataDto` |
| Trail | A trail stored in Gaku's database, with its own waypoints. Unrelated to Overpass data. | `Trail` (domain entity) |
| Waypoint | A named stop on a stored trail. Not an OSM node. | `Waypoint` (domain entity) |

## 2. How the terms relate

```
Overpass response
├── node {id, lat, lon}              ──►  point
└── way  {id, tags, nodes: [id, …]}  ──►  OSM trail
                                            └── path: one point per node ID found in the response
```

- One way becomes at most one OSM trail; `OsmTrailData.OsmId` is the way's ID.
- Each node ID in a way becomes one point of the path, if that node is in the response. Missing IDs are skipped, so a
  path can be shorter than the way's node list.
- One node can belong to several ways, e.g. at a junction, so the same point can appear in several paths.
- A way whose path ends up with fewer than two points is dropped: the map draws a path as a line, and a line needs two
  points.

## 3. Words to use in docs and comments

| Write | Instead of | Why |
| --- | --- | --- |
| way, node | trail, point | Only while talking about the raw Overpass response, before conversion. |
| OSM trail | trail | Plain "trail" means the domain `Trail` entity. |
| point | node, coordinate | After conversion the path holds `Coordinates`, not nodes. |
| path | line, geometry, route | Matches `OsmTrailData.Path`; "route" is an OSM tag value and "line" is how the map draws it. |
| node | waypoint | `Waypoint` is a domain entity with a name and an order. |