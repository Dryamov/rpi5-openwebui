#!/bin/bash
# Validate that critical services in docker-compose.yml have health checks

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

cd "${PROJECT_ROOT}"

echo "🔍 Validating health checks in docker-compose.yml..."

# Check if docker-compose.yml exists
if [ ! -f "docker-compose.yml" ]; then
    echo "❌ docker-compose.yml not found"
    exit 1
fi

# List of critical services that MUST have health checks
CRITICAL_SERVICES=(
    "openwebui"
    "ollama"
    "postgres"
    "redis"
    "searxng"
)

# Check if yq is available for better YAML parsing
if command -v yq &> /dev/null; then
    USE_YQ=true
else
    USE_YQ=false
    echo "ℹ️  yq not found, using grep-based validation (less accurate)"
fi

MISSING_HEALTHCHECKS=""
SERVICES_CHECKED=0

for service in "${CRITICAL_SERVICES[@]}"; do
    echo -n "   Checking $service... "
    
    # Check if service exists
    if ! grep -q "^  ${service}:" docker-compose.yml; then
        echo "⚠️  not found in docker-compose.yml"
        continue
    fi
    
    SERVICES_CHECKED=$((SERVICES_CHECKED + 1))
    
    # Check for healthcheck
    if $USE_YQ; then
        # Use yq for accurate parsing (Python-based jq wrapper for YAML)
        # Note: This assumes yq from pip (kislyuk/yq), not the Go version (mikefarah/yq)
        if yq -r ".services.${service}.healthcheck // \"null\"" docker-compose.yml 2>/dev/null | grep -q "null"; then
            echo "❌ missing healthcheck"
            MISSING_HEALTHCHECKS="${MISSING_HEALTHCHECKS}${service}\n"
        else
            echo "✅"
        fi
    else
        # Fallback: grep-based check
        # Extract service block and check for healthcheck keyword
        SERVICE_BLOCK=$(awk "/^  ${service}:/,/^  [a-z]/" docker-compose.yml)
        
        if echo "$SERVICE_BLOCK" | grep -q "healthcheck:"; then
            echo "✅"
        else
            echo "❌ missing healthcheck"
            MISSING_HEALTHCHECKS="${MISSING_HEALTHCHECKS}${service}\n"
        fi
    fi
done

# Report results
echo ""
if [ -n "$MISSING_HEALTHCHECKS" ]; then
    echo "❌ Critical services missing health checks:"
    echo -e "$MISSING_HEALTHCHECKS"
    echo ""
    echo "Health checks are required for production readiness and proper orchestration."
    echo "Add healthcheck configuration to these services."
    exit 1
else
    echo "✅ All critical services have health checks configured"
    echo ""
    echo "📊 Statistics:"
    echo "   Critical services checked: $SERVICES_CHECKED"
    echo "   Services with health checks: $SERVICES_CHECKED"
    
    exit 0
fi
