# syntax=docker/dockerfile:1
#
# Entry point projects: Api, Web
#
# Shared stages
#   restore           NuGet restore for entry point projects
#   build             compiles entry point projects and library projects
#   publish-api
#   publish-web
#   publish-migrator
#
# Targets:
#   ci        build plus the test projects
#   test      runs the test suites in-image
#   api       Gaku.Api runtime image
#   web       Gaku.Web runtime image
#   migrator  self-contained EF Core migrations bundle


ARG DOTNET_VERSION=10.0

################################################################################################################################
# Restore entry point projects dependencies.
# Later stages can use --no-restore .
FROM mcr.microsoft.com/dotnet/sdk:${DOTNET_VERSION} AS restore
WORKDIR /src

# Path to NuGet HTTP cache for mounting
ENV NUGET_HTTP_CACHE_PATH=/root/.local/share/NuGet/http-cache

# Project files are copied to keep this layer cached when source code changes.
COPY global.json .
COPY Directory.Build.props .
COPY Gaku.sln .

COPY src/Gaku.Domain/Gaku.Domain.csproj                               src/Gaku.Domain/
COPY src/Gaku.Application/Gaku.Application.csproj                     src/Gaku.Application/
COPY src/Gaku.Infrastructure/Gaku.Infrastructure.csproj               src/Gaku.Infrastructure/
COPY src/Gaku.Api/Gaku.Api.csproj                                     src/Gaku.Api/
COPY src/Gaku.Web/Gaku.Web.csproj                                     src/Gaku.Web/

# Restore entry-point projects.
RUN --mount=type=cache,target=$NUGET_HTTP_CACHE_PATH \
    dotnet restore src/Gaku.Api/Gaku.Api.csproj \
 && dotnet restore src/Gaku.Web/Gaku.Web.csproj

################################################################################################################################
# Build entry-point projects
# Later stages can use --no-build.
FROM restore AS build
COPY . .
RUN --mount=type=cache,target=$NUGET_HTTP_CACHE_PATH \
dotnet build src/Gaku.Api/Gaku.Api.csproj -c Release --no-restore \
&& dotnet build src/Gaku.Web/Gaku.Web.csproj -c Release --no-restore

################################################################################################################################
# Restore and build the whole solution, which adds the test projects referenced by the sln
# on top of `build`.
# The pipelines run the test suites in this image.
#
# .sln instead of tests/*.csproj invidually: `ci` inherits `build`'s, so MSBuild skips the earlier-compiled projects anyway.
# For each named invidual test project, an extra MSBuild startup is needed.
FROM build AS ci
RUN --mount=type=cache,target=$NUGET_HTTP_CACHE_PATH \
dotnet restore Gaku.sln
RUN --mount=type=cache,target=$NUGET_HTTP_CACHE_PATH \
dotnet build Gaku.sln -c Release --no-restore

################################################################################################################################
# Run test suites in `ci` image.
# Not used by the pipelines.
FROM ci AS test
RUN mkdir -p /TestResults/domain /TestResults/application /TestResults/infrastructure /TestResults/web
# Every suite runs even one fails along the way
RUN status=0 \
    ; dotnet test tests/Gaku.Domain.Tests/Gaku.Domain.Tests.csproj \
        -c Release --no-build \
        --logger "junit;LogFilePath=/TestResults/domain/junit.xml" \
        --results-directory /TestResults/domain \
      || status=1 \
    ; dotnet test tests/Gaku.Application.Tests/Gaku.Application.Tests.csproj \
        -c Release --no-build \
        --logger "junit;LogFilePath=/TestResults/application/junit.xml" \
        --results-directory /TestResults/application \
      || status=1 \
    ; dotnet test tests/Gaku.Infrastructure.Tests/Gaku.Infrastructure.Tests.csproj \
        -c Release --no-build \
        --logger "junit;LogFilePath=/TestResults/infrastructure/junit.xml" \
        --results-directory /TestResults/infrastructure \
      || status=1 \
    ; dotnet test tests/Gaku.Web.Tests/Gaku.Web.Tests.csproj \
        -c Release --no-build \
        --logger "junit;LogFilePath=/TestResults/web/junit.xml" \
        --results-directory /TestResults/web \
      || status=1 \
    ; exit $status

################################################################################################################################
# API image
# Publish the api entry-point project.
FROM build AS publish-api
RUN dotnet publish src/Gaku.Api/Gaku.Api.csproj -c Release --no-build -o /app/publish

# Ship api image
FROM mcr.microsoft.com/dotnet/aspnet:${DOTNET_VERSION} AS api
ARG GIT_COMMIT=unknown
ARG BUILD_NUMBER=local
ARG BUILD_TIMESTAMP=unknown
WORKDIR /app
COPY --from=publish-api /app/publish .
ENV ASPNETCORE_URLS=http://+:8080
ENV ASPNETCORE_ENVIRONMENT=Production
EXPOSE 8080
LABEL org.opencontainers.image.revision="${GIT_COMMIT}" \
      org.opencontainers.image.version="${BUILD_NUMBER}" \
      org.opencontainers.image.created="${BUILD_TIMESTAMP}"
ENTRYPOINT ["dotnet", "Gaku.Api.dll"]

################################################################################################################################
# Web image
# Publish the web entry-point project.
FROM build AS publish-web
RUN --mount=type=cache,target=$NUGET_HTTP_CACHE_PATH \
    dotnet tool install --global dotnet-counters
RUN dotnet publish src/Gaku.Web/Gaku.Web.csproj -c Release --no-build -o /app/publish

# Ship web image
FROM mcr.microsoft.com/dotnet/aspnet:${DOTNET_VERSION} AS web
ARG GIT_COMMIT=unknown
ARG BUILD_NUMBER=local
ARG BUILD_TIMESTAMP=unknown
# curl for manual debugging inside the container
RUN apt-get update && apt-get install -y curl && rm -rf /var/lib/apt/lists/*
WORKDIR /app
COPY --from=publish-web /app/publish .
COPY --from=publish-web /root/.dotnet/tools /root/.dotnet/tools
ENV PATH="$PATH:/root/.dotnet/tools"
ENV ASPNETCORE_URLS=http://+:8080
ENV ASPNETCORE_ENVIRONMENT=Production
EXPOSE 8080
LABEL org.opencontainers.image.revision="${GIT_COMMIT}" \
      org.opencontainers.image.version="${BUILD_NUMBER}" \
      org.opencontainers.image.created="${BUILD_TIMESTAMP}"
ENTRYPOINT ["dotnet", "Gaku.Web.dll"]

################################################################################################################################
# build migrator image 
# `--self-contained --target-runtime linux-x64` needs a RID-specific build, which cannot reuse the portable output from `build`.
FROM build AS publish-migrator
RUN --mount=type=cache,target=$NUGET_HTTP_CACHE_PATH \
dotnet tool install --global dotnet-ef --version 10.0.7
ENV PATH="$PATH:/root/.dotnet/tools"

# EF Core needs a placeholder connection string for design-time configuration while creating the migrations bundle.
# No real database connection is established during the build.
ENV ConnectionStrings__DefaultConnection="Host=design-time;Database=gaku;Username=gaku;Password=gaku"

# Create a self-contained migrations bundle so the runtime image only needs .NET runtime dependencies. 
RUN --mount=type=cache,target=$NUGET_HTTP_CACHE_PATH \
dotnet ef migrations bundle \
--project src/Gaku.Infrastructure \
--startup-project src/Gaku.Api \
--configuration Release \
--self-contained --target-runtime linux-x64 \
--output /app/migrate --force

################################################################################################################################
# ship migrator image
FROM mcr.microsoft.com/dotnet/runtime-deps:${DOTNET_VERSION} AS migrator
ARG GIT_COMMIT=unknown
ARG BUILD_NUMBER=local
ARG BUILD_TIMESTAMP=unknown
LABEL org.opencontainers.image.revision="${GIT_COMMIT}" \
org.opencontainers.image.version="${BUILD_NUMBER}" \
org.opencontainers.image.created="${BUILD_TIMESTAMP}"
WORKDIR /app
COPY --from=publish-migrator /app/migrate /app/migrate

ENTRYPOINT ["/bin/sh", "-c", "exec /app/migrate --connection \"${ConnectionStrings__DefaultConnection:?connection string not set}\""]
