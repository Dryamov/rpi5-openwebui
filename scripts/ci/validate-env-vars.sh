#!/bin/bash
# Validate that all environment variables used in docker-compose.yml
# are defined in .env.example

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

cd "${PROJECT_ROOT}"

echo "🔍 Validating environment variables..."

# Check if required files exist
if [ ! -f "docker-compose.yml" ]; then
    echo "❌ docker-compose.yml not found"
    exit 1
fi

if [ ! -f ".env.example" ]; then
    echo "❌ .env.example not found"
    exit 1
fi

# Extract all ${VAR} and $VAR patterns from docker-compose.yml
echo "📋 Extracting variables from docker-compose.yml..."
COMPOSE_VARS=$(grep -oE '\$\{?[A-Z_][A-Z0-9_]*\}?' docker-compose.yml | \
    sed 's/\${\?\([A-Z_][A-Z0-9_]*\)}\?/\1/' | \
    sort -u)

# Extract variables defined in .env.example
echo "📋 Extracting variables from .env.example..."
EXAMPLE_VARS=$(grep -E '^[A-Z_][A-Z0-9_]*=' .env.example | \
    cut -d= -f1 | \
    sort -u)

# Find missing variables
MISSING_VARS=""
for var in $COMPOSE_VARS; do
    # Skip some system/docker built-in variables
    case "$var" in
        HOME|USER|PATH|PWD|HOSTNAME|DOCKER_*)
            continue
            ;;
    esac
    
    if ! echo "$EXAMPLE_VARS" | grep -q "^${var}$"; then
        MISSING_VARS="${MISSING_VARS}${var}\n"
    fi
done

# Report results
if [ -n "$MISSING_VARS" ]; then
    echo ""
    echo "❌ Missing variables in .env.example:"
    echo -e "$MISSING_VARS" | sort -u
    echo ""
    echo "These variables are used in docker-compose.yml but not defined in .env.example"
    exit 1
else
    echo "✅ All required environment variables are defined in .env.example"
    
    # Count variables
    COMPOSE_COUNT=$(echo "$COMPOSE_VARS" | wc -l)
    EXAMPLE_COUNT=$(echo "$EXAMPLE_VARS" | wc -l)
    
    echo ""
    echo "📊 Statistics:"
    echo "   Variables in docker-compose.yml: $COMPOSE_COUNT"
    echo "   Variables in .env.example: $EXAMPLE_COUNT"
    
    exit 0
fi
