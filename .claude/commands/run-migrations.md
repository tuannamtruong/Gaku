Run EF Core database migrations for the Gaku project.

Steps:
1. Check the current migration state with: `dotnet ef migrations list --project src/Gaku.Infrastructure --startup-project src/Gaku.Api`
2. If $ARGUMENTS is "add", prompt for a migration name and run: `dotnet ef migrations add <name> --project src/Gaku.Infrastructure --startup-project src/Gaku.Api`
3. If $ARGUMENTS is "apply" or is empty, apply pending migrations: `dotnet ef database update --project src/Gaku.Infrastructure --startup-project src/Gaku.Api`
4. If $ARGUMENTS is "revert", roll back the last migration: `dotnet ef database update --project src/Gaku.Infrastructure --startup-project src/Gaku.Api <previous-migration>`
5. Report the result — list applied migrations and confirm the database is up to date.

Always ensure the PostgreSQL container is running before applying migrations.
