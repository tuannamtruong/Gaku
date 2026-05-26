# Diagnosis: GET /api/trails/nearby returns 500

I tested the endpoint and checked the API logs.

## Reproduction

```
curl http://localhost:18080/api/trails/nearby?lat=47.0&lon=11.0&radiusKm=50
→ HTTP 500 (empty body)
```

The 500 is confirmed.

## Error in logs

The API logs show a PostgreSQL exception:

```
Npgsql.PostgresException: 42P01: relation "trails" does not exist
  at TrailRepository.GetNearbyAsync() in TrailRepository.cs:line 26
```

PostgreSQL error `42P01` means a table or view doesn't exist. The query is referencing `trails` but this table doesn't exist in the database.

## Conclusion

The `/api/trails/nearby` endpoint is failing because the SQL query references a table called `trails` that doesn't exist in the database. This is in `TrailRepository.cs` around line 26.

You'll need to check the table name in the database and update the query accordingly. The table might be named differently (e.g., `Trail` with a capital T, or with a different schema prefix). Running `\dt` in psql will show the actual table names.
