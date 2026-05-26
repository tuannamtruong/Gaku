# Diagnosis: db-migrate job failing

I checked the migration job and Web app status.

## db-migrate job

Running `kubectl get pods -n gaku`:

```
db-migrate-bkhq9   0/1   Completed   0   24h
```

The job shows **Completed** — it succeeded. The logs end with `Done.` and show 1 migration applied (`SyncCoordinatesValueConverter`).

The Waypoint table already exists in the database (it was part of the initial schema). If you added a migration that touches `Waypoint`, it may have already been applied, or it may not be in the currently deployed image.

## Web app

Running `kubectl logs deployment/gaku-web -n gaku` shows the pod is running and making Overpass API requests. There are some error entries about `JSDisconnectedException`, but the app appears to be serving requests.

## Conclusion

Both services appear to be running now. The migration job completed successfully. The Web app is live.

If you're seeing failures, the migration you added may not have been included in the Docker image that was deployed. Make sure you rebuild and redeploy after adding a migration. Check `dotnet ef migrations list` to see which migrations exist in the codebase vs what's applied in the DB.
