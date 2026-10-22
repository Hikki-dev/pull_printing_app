# One image that serves both the web app and the API, for a free demo host.
# Build:  docker build -t pull-print-demo .
# Run:    docker run -p 8080:8080 pull-print-demo     then open http://localhost:8080

# 1) The web app (Flutter), built to talk to the API on the same address.
FROM ghcr.io/cirruslabs/flutter:stable AS web
WORKDIR /src
COPY pubspec.yaml pubspec.lock .metadata ./
COPY frontend ./frontend
COPY web ./web
RUN flutter pub get
RUN flutter build web -t frontend/lib/main.dart --release --no-web-resources-cdn \
    --dart-define=USE_MOCK=false

# 2) The API (ASP.NET Core).
FROM mcr.microsoft.com/dotnet/sdk:8.0 AS api
WORKDIR /src
COPY backend ./backend
RUN dotnet publish backend -c Release -o /out

# 3) Run both together: the API serves the web app from wwwroot.
FROM mcr.microsoft.com/dotnet/aspnet:8.0
WORKDIR /app
COPY --from=api /out .
COPY --from=web /src/build/web ./wwwroot
ENV ASPNETCORE_ENVIRONMENT=Production \
    Demo__Enabled=true
USER $APP_UID
EXPOSE 8080
# Hosts such as Render tell the app which port to use through PORT.
CMD ["sh", "-c", "ASPNETCORE_URLS=http://0.0.0.0:${PORT:-8080} exec dotnet PullPrintingBackend.dll"]
