# Gaku

Trail discovery for hiking in Europe — an ASP.NET Core 10 application that renders OpenStreetMap
hiking paths on a Leaflet map and stores curated trails in PostgreSQL with PostGIS spatial
indexing.

This wiki holds the design and operations documentation. Setup instructions, the API surface, and
the quick start live in the [README](https://github.com/tuannamtruong/Gaku#readme).

## 1. Start here

| If you want to | Read |
| --- | --- |
| See how Gaku fits with the outside world | [System Context](System-Context) |
| Understand the layering and a request end to end | [Architecture Overview](Architecture-Overview) |
| Find the type that does a particular job | [Class Diagrams](Class-Diagrams) |
| Work on entities, migrations, or spatial queries | [Database Schema](Database-Schema) |
| Change how trails are fetched from OpenStreetMap | [OSM Integration](OSM-Integration) |
| Deploy to the local cluster, or debug one | [Infrastructure](Infrastructure) |
| Run, debug, or extend the pipeline | [CICD Workflow](CICD-Workflow) |
| Know what ships next | [CICD Roadmap](CICD-Roadmap) |

## 2. The shape of the system

Five projects in a clean-architecture arrangement. `Gaku.Domain` holds the business model and
references nothing. `Gaku.Application` declares what the system can do and the contracts
infrastructure must satisfy. `Gaku.Infrastructure` implements those contracts against EF Core,
PostGIS, and the OpenStreetMap APIs. `Gaku.Api` and `Gaku.Web` are the two front doors, and they
reach infrastructure only through `Program.cs`.

Trails come from two places, and the distinction explains most of the code. Curated trails are
stored locally in PostGIS with waypoints and elevation, queried by radius through `ST_DWithin`.
Ambient trails are pulled live from the Overpass API for whatever bounding box the map is showing,
and never persisted. [Architecture Overview](Architecture-Overview) traces both paths.

## 3. About these pages

Every page here is generated from a markdown file under
[`docs/`](https://github.com/tuannamtruong/Gaku/tree/master/docs) and republished on each push to
`master`. **Edits made in the wiki editor are overwritten on the next publish.** To change a page,
edit its source file and open a pull request; the mapping from source file to page name is in
[`docs/wiki/manifest.txt`](https://github.com/tuannamtruong/Gaku/blob/master/docs/wiki/manifest.txt).
