# CI/CD Workflow

## Overview

```mermaid
flowchart TD
    Dev["Developer pushes code"]
    GH["GitHub"]
    Smee["Smee.io\nrelay channel"]
    SmeeClient["Smee client\nsidecar container"]
    Jenkins["Jenkins"]
    Build["Restore & Build\nCompile all projects"]
    TD["Test — Domain"]
    TA["Test — Application"]
    TI["Test — Infrastructure"]
    Copy["Collect test results"]
    JUnit["Publish JUnit report"]
    Cleanup["Remove build artifacts"]

    Dev -->|git push| GH
    GH -->|webhook| Smee
    Smee -->|relay| SmeeClient
    SmeeClient -->|forward| Jenkins
    Jenkins --> Build
    Build --> TD
    Build --> TA
    Build --> TI
    TD --> Copy
    TA --> Copy
    TI --> Copy
    Copy --> JUnit
    JUnit --> Cleanup
```

## Container Roles

| Container | Image | Purpose |
|---|---|---|
| `gaku-jenkins` | built from `jenkins/local/Dockerfile` | Jenkins server — hosts UI, schedules jobs, runs pipeline |
| `smee` | `node:lts-alpine` | Runs `smee-relay.js` — SSE client that forwards GitHub webhook payloads to Jenkins |
| `gaku-ci-<build>` | built from `docker/Dockerfile.ci` | Ephemeral per-build container — compiles and tests .NET code |

## File Map

```
jenkins/local/
  Dockerfile           custom Jenkins image (adds Docker CLI to jenkins/jenkins:lts-jdk21)
  docker-compose.yml   two services: gaku-jenkins + smee relay sidecar
  smee-relay.js        pure Node.js SSE client; no npm packages; converts Smee payloads to JSON for Jenkins
  .env                 single var: SMEE_URL=https://smee.io/<channel-id>  (not committed)

docker/
  Dockerfile.ci        multi-stage: stage build (restore + compile all projects), stage test (unused by Jenkinsfile — tests run via docker run on the build stage image)

Jenkinsfile            declarative pipeline — builds CI image, runs three test containers, publishes JUnit results, removes image
```

## Stage Detail

```mermaid
sequenceDiagram
    participant J as Jenkins Server
    participant D as Docker Daemon
    participant C as Build Container

    J->>D: Build the CI image from source
    D-->>J: Image ready

    loop Domain / Application / Infrastructure
        J->>D: Start a container and run tests
        D->>C: Execute tests inside container
        C-->>D: Tests finish (pass or fail)
        J->>D: Copy test results to workspace
        J->>D: Remove the container
    end

    J->>D: Remove the CI image
    J->>J: Publish test results
```
