# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- Comprehensive documentation structure in `docs/services/`
- Service-specific guides for Caddy, SearXNG, OpenWebUI, Ollama, and CLI-Proxy-API-Plus
- `CONTRIBUTING.md` with guidelines for adding new services
- `TELEMETRY.MD` with OpenTelemetry monitoring documentation
- Volume labels for automated backup management (`com.backup`, `com.service`)
- CPU limits and reservations for OpenWebUI (2.0 CPUs limit, 1.0 reservation)
- `.editorconfig` for consistent code formatting across editors

### Changed
- YAML anchors (`x-logging`) to eliminate logging configuration duplication
- Environment variables in `docker-compose.yml` (removed redundant quotes)
- `SEARXNG_LIMITER` default changed from `false` to `true` for DDoS protection
- Health check intervals optimized for Raspberry Pi 5 performance
- `.gitignore` updated to protect `cli-proxy-api-plus/config/config.yaml` and log files

### Security
- Added `.gitignore` entries for sensitive configuration files
- Enabled rate limiting for SearXNG by default
- Documented CORS security best practices for OpenWebUI

## [1.0.0] - 2026-01-15

### Initial Release

**Architecture**: Docker Compose stack for Raspberry Pi 5

**Services**:
- OpenWebUI (Web interface for LLMs)
- Ollama (Local model inference)
- SearXNG (Privacy-respecting metasearch)
- Caddy (Reverse proxy with automatic HTTPS)
- Valkey (Redis-compatible cache for SearXNG)
- CLI-Proxy-API-Plus (API proxy for external LLM providers)

**Features**:
- Automated backup and restore scripts (`scripts/backup.sh`, `scripts/restore.sh`)
- Docker health checks for all critical services
- Resource limits optimized for Raspberry Pi 5 (16GB RAM)
- Secure configuration with environment variables
- Comprehensive README with setup instructions

**Optimizations for RPi5**:
- Memory limits for all services to prevent system crashes
- Valkey caching for ultra-fast SearXNG results
- RAG server architecture (offloading heavy LLM to remote APIs)

---

## How to Update This Changelog

When making changes:

1. Add your changes under `[Unreleased]` section
2. Use categories: `Added`, `Changed`, `Deprecated`, `Removed`, `Fixed`, `Security`
3. Before releasing a new version, move `[Unreleased]` changes to a new version section

Example:
```markdown
## [Unreleased]

### Added
- New feature XYZ

### Fixed
- Bug in service ABC
```

Then on release:
```markdown
## [1.1.0] - 2026-01-XX

### Added
- New feature XYZ

### Fixed
- Bug in service ABC
```
