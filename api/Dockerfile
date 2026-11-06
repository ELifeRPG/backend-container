# ELifeRPG backend API: the released binaries on the current ASP.NET Core runtime.
#
# Versions are bumped by Renovate: the runtime by its dockerfile manager, the backend release by the
# custom regex manager in renovate.json (the `# renovate:` comment above the ENV). The ENV stays in
# the image, so `docker inspect` shows which release it contains. Either bump only ships once CI's
# smoke test (scripts/smoke-test.sh) has booted the combination.

FROM mcr.microsoft.com/dotnet/aspnet:11.0.0-preview.6 AS runtime
# renovate: datasource=github-releases depName=ELifeRPG/backend
ENV ELIFERPG_BACKEND_VERSION=0.1.0

# A separate stage so the downloaded tarball never ends up in the image's layers.
FROM runtime AS fetch
ADD https://github.com/ELifeRPG/backend/releases/download/v${ELIFERPG_BACKEND_VERSION}/backend-api-${ELIFERPG_BACKEND_VERSION}.tar.gz /tmp/app.tar.gz
RUN mkdir /app && tar -xzf /tmp/app.tar.gz -C /app

FROM runtime
WORKDIR /app
COPY --from=fetch /app .
USER $APP_UID
ENTRYPOINT ["dotnet", "ELifeRPG.Api.dll"]
