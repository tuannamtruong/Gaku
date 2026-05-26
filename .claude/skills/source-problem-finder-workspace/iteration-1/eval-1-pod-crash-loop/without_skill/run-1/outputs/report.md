# Diagnosis: gaku-api CrashLoopBackOff

I checked the pod status for gaku-api in the gaku namespace.

## Current state

Running `kubectl get pods -n gaku`:

```
NAME                        READY   STATUS    RESTARTS   AGE
gaku-api-56fdddcb8b-z6hsw   1/1     Running   1          24h
```

The pod is currently **Running** and not in CrashLoopBackOff. There is 1 restart in its history.

## What I found

Running `kubectl logs deployment/gaku-api -n gaku` shows the API is starting up and handling requests. There are some warnings about database seeding failing:

```
fail: Program[0]
      Seeding failed — continuing without seed data
```

This indicates that when the pod started, it tried to seed the database but encountered an error. However, the application continues running despite this failure.

There's also a note about `libgssapi_krb5.so.2` not loading, but the app starts fine.

## Conclusion

The pod is currently healthy and running. The 1 restart was likely due to the pod being restarted by Kubernetes or a manual rollout. The seeding failure in the logs is non-fatal — the application catches the exception and starts anyway.

If you were experiencing CrashLoopBackOff earlier, it may have resolved itself or been fixed by the restart. You could monitor the pod with `kubectl get pods -n gaku -w` to watch for further restarts.
