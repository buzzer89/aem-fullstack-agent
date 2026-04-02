#!/usr/bin/env bash
# ============================================================================
# AEM Feature Agent — Universal Bootstrap Script
# ============================================================================
# Scans any AEM project and generates .agent/project.yaml with all
# project-specific values. Works with AEM 6.5, AEM LTS, AEM AMS, AEMaaCS.
#
# Compatible with: macOS (BSD) and Linux (GNU) tools.
#
# Handles non-standard project structures:
#   - Custom module names (e.g. "bundle" instead of "core")
#   - Nested module layouts (e.g. "modules/core/")
#   - Different POM conventions and property chains
#   - Multi-brand / monorepo setups
#
# Usage:
#   cd <your-aem-project-root>
#   bash .agent/universal/setup.sh
#
# Or from anywhere:
#   bash /path/to/.agent/universal/setup.sh /path/to/aem-project
# ============================================================================

set -euo pipefail

# --- Resolve project root ---------------------------------------------------
if [ -n "${1:-}" ] && [ -d "$1" ]; then
    PROJECT_ROOT="$(cd "$1" && pwd)"
else
    PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
fi

AGENT_DIR="$PROJECT_ROOT/.agent"
OUTPUT_FILE="$AGENT_DIR/project.yaml"
POM_FILE="$PROJECT_ROOT/pom.xml"
WARNINGS=""

echo "🔍 AEM Feature Agent — Project Scanner"
echo "   Project root: $PROJECT_ROOT"
echo ""

# --- Validate it's a Maven project ------------------------------------------
if [ ! -f "$POM_FILE" ]; then
    echo "❌ No pom.xml found at $PROJECT_ROOT. Is this an AEM Maven project?"
    exit 1
fi

mkdir -p "$AGENT_DIR"

# =============================================================================
# Helper: extract XML element value (macOS + Linux safe — no grep -P)
# =============================================================================
pom_value() {
    local tag="$1"
    local file="${2:-$POM_FILE}"
    grep -m1 "<${tag}>" "$file" 2>/dev/null | sed "s/.*<${tag}>//;s/<\/${tag}>.*//" | xargs 2>/dev/null || echo ""
}

# Helper: resolve a Maven property ${name} from <properties> in any POM.
# Follows one level of indirection (e.g. ${aem.version} → 6.5.21).
resolve_property() {
    local prop_expr="$1"
    local file="${2:-$POM_FILE}"
    # If it's not a property reference, return as-is
    if ! echo "$prop_expr" | grep -q '^\$'; then
        echo "$prop_expr"
        return
    fi
    local prop_name
    prop_name=$(echo "$prop_expr" | sed 's/\${//;s/}//')
    # Search root POM properties first, then the given file
    local resolved=""
    for pom in "$POM_FILE" "$file"; do
        resolved=$(sed -n "s/.*<${prop_name}>\([^<]*\)<\/${prop_name}>.*/\1/p" "$pom" 2>/dev/null | head -1 || echo "")
        if [ -n "$resolved" ]; then
            # Recurse once in case it's a chained property (e.g. ${foo} → ${bar} → value)
            if echo "$resolved" | grep -q '^\$'; then
                resolved=$(resolve_property "$resolved" "$file")
            fi
            echo "$resolved"
            return
        fi
    done
    # Check parent POM if present
    local parent_rel
    parent_rel=$(sed -n '/<parent>/,/<\/parent>/{ s/.*<relativePath>\([^<]*\)<\/relativePath>.*/\1/p; }' "$file" 2>/dev/null | head -1 || echo "")
    if [ -n "$parent_rel" ] && [ -f "$(dirname "$file")/$parent_rel" ]; then
        local parent_pom
        parent_pom="$(cd "$(dirname "$file")" && cd "$(dirname "$parent_rel")" && pwd)/$(basename "$parent_rel")"
        if [ -f "$parent_pom" ]; then
            resolved=$(sed -n "s/.*<${prop_name}>\([^<]*\)<\/${prop_name}>.*/\1/p" "$parent_pom" 2>/dev/null | head -1 || echo "")
            if [ -n "$resolved" ] && echo "$resolved" | grep -q '^\$'; then
                resolved=$(resolve_property "$resolved" "$parent_pom")
            fi
        fi
    fi
    echo "$resolved"
}

# Helper: extract <version> near an artifactId, tolerant of blank-line-heavy POMs.
# Strips all blank/whitespace-only lines first so grep -A5 always reaches <version>.
# Now resolves ${property} references automatically.
dep_version() {
    local artifact="$1"
    local file="$2"
    local raw_version
    raw_version=$(sed '/^[[:space:]]*$/d' "$file" 2>/dev/null \
        | grep -A10 "<artifactId>[^<]*${artifact}" 2>/dev/null \
        | sed -n 's/.*<version>\([^<]*\)<\/version>.*/\1/p' \
        | head -1 || echo "")
    if [ -z "$raw_version" ]; then
        echo ""
        return
    fi
    # Resolve property references
    resolve_property "$raw_version" "$file"
}

# Helper: add a warning message to be shown at the end
warn() {
    WARNINGS="${WARNINGS}\n   ⚠️  $1"
}

# =============================================================================
# 1. Core Maven coordinates
# =============================================================================
GROUP_ID=$(pom_value "groupId")
ARTIFACT_ID=$(pom_value "artifactId")
VERSION=$(pom_value "version")
if [ -z "$GROUP_ID" ]; then
    GROUP_ID=$(grep -A5 "<parent>" "$POM_FILE" | grep "<groupId>" | sed 's/.*<groupId>//;s/<\/groupId>.*//' | xargs 2>/dev/null || echo "")
fi

echo "   groupId:    $GROUP_ID"
echo "   artifactId: $ARTIFACT_ID"
echo "   version:    $VERSION"

# =============================================================================
# 2. Detect AEM version / type
# =============================================================================
AEM_TYPE="unknown"
AEM_SDK_VERSION=""
UBER_JAR_VERSION=""
JAVA_VERSION=""

# Check for AEMaaCS SDK — search up to 3 levels deep for nested modules
AEM_SDK_POM=$(find "$PROJECT_ROOT" -maxdepth 3 -name "pom.xml" -exec grep -l "aem-sdk-api" {} \; 2>/dev/null | head -1 || echo "")
if [ -n "$AEM_SDK_POM" ]; then
    AEM_SDK_VERSION=$(dep_version "aem-sdk-api" "$AEM_SDK_POM")
    # Fallback: version may be in root pom dependencyManagement
    if [ -z "$AEM_SDK_VERSION" ]; then
        AEM_SDK_VERSION=$(dep_version "aem-sdk-api" "$POM_FILE")
    fi
    if [ -z "$AEM_SDK_VERSION" ]; then
        AEM_SDK_VERSION=$(sed -n 's/.*<aem.sdk.api>\([^<]*\)<\/aem.sdk.api>.*/\1/p' "$POM_FILE" 2>/dev/null | head -1 || echo "")
    fi
fi

if [ -n "$AEM_SDK_VERSION" ]; then
    AEM_TYPE="cloud"
    echo "   AEM type:   AEM as a Cloud Service (SDK $AEM_SDK_VERSION)"
else
    UBER_JAR_POM=$(find "$PROJECT_ROOT" -maxdepth 3 -name "pom.xml" -exec grep -l "uber-jar" {} \; 2>/dev/null | head -1 || echo "")
    if [ -n "$UBER_JAR_POM" ]; then
        UBER_JAR_VERSION=$(dep_version "uber-jar" "$UBER_JAR_POM")
        # Fallback: version may be in root pom dependencyManagement
        if [ -z "$UBER_JAR_VERSION" ]; then
            UBER_JAR_VERSION=$(dep_version "uber-jar" "$POM_FILE")
        fi
    fi

    # Detect dispatcher layout — search multiple patterns
    HAS_AMS_DISPATCHER="no"
    HAS_CLOUD_DISPATCHER="no"
    if find "$PROJECT_ROOT" -maxdepth 3 -type d -name "conf.dispatcher.d" 2>/dev/null | grep -q .; then
        HAS_AMS_DISPATCHER="yes"
    fi
    if [ -d "$PROJECT_ROOT/dispatcher.ams" ]; then
        HAS_AMS_DISPATCHER="yes"
    fi
    if [ -d "$PROJECT_ROOT/dispatcher.cloud" ]; then
        HAS_CLOUD_DISPATCHER="yes"
    fi

    if [ "$HAS_CLOUD_DISPATCHER" = "yes" ]; then
        AEM_TYPE="cloud"
    elif [ "$HAS_AMS_DISPATCHER" = "yes" ]; then
        if echo "$UBER_JAR_VERSION" | grep -q '^6\.[6-9]'; then
            AEM_TYPE="lts"
        else
            AEM_TYPE="ams"
        fi
    else
        AEM_TYPE="on-prem"
    fi

    if [ "$AEM_TYPE" = "unknown" ] || [ "$AEM_TYPE" = "on-prem" ]; then
        if echo "$UBER_JAR_VERSION" | grep -q '^6\.[6-9]'; then
            AEM_TYPE="lts"
        elif echo "$UBER_JAR_VERSION" | grep -q '^6\.5'; then
            AEM_TYPE="on-prem"
        fi
    fi

    echo "   AEM type:   AEM ${AEM_TYPE} (uber-jar $UBER_JAR_VERSION)"
fi

# --- Java version (macOS-safe, resolves ${property} chains) ---
JAVA_SOURCE=$(sed -n 's/.*<maven.compiler.source>\([^<]*\)<\/maven.compiler.source>.*/\1/p' "$POM_FILE" 2>/dev/null | head -1 || echo "")
if [ -z "$JAVA_SOURCE" ]; then
    JAVA_SOURCE=$(sed -n 's/.*<java.version>\([^<]*\)<\/java.version>.*/\1/p' "$POM_FILE" 2>/dev/null | head -1 || echo "")
fi
if [ -z "$JAVA_SOURCE" ]; then
    JAVA_SOURCE=$(sed -n 's/.*<maven.compiler.release>\([^<]*\)<\/maven.compiler.release>.*/\1/p' "$POM_FILE" 2>/dev/null | head -1 || echo "")
fi
if [ -z "$JAVA_SOURCE" ]; then
    JAVA_SOURCE=$(sed -n 's/.*<source>\([^<]*\)<\/source>.*/\1/p' "$POM_FILE" 2>/dev/null | head -1 || echo "")
fi
# Resolve property references (e.g. ${java.version} → 11)
if echo "$JAVA_SOURCE" | grep -q '^\$'; then
    JAVA_SOURCE=$(resolve_property "$JAVA_SOURCE" "$POM_FILE")
fi
JAVA_VERSION="${JAVA_SOURCE:-11}"
echo "   Java:       $JAVA_VERSION"

# =============================================================================
# 3. Discover module paths (POM-aware, handles non-standard names)
# =============================================================================
# Strategy:
#   1. Parse <modules> from root POM to get declared module paths
#   2. Classify each module by inspecting its contents (not just its name)
#   3. Fall back to directory name heuristics only when classification fails
# =============================================================================

# --- 3a. Parse declared modules from root POM ---
DECLARED_MODULES=""
if grep -q "<modules>" "$POM_FILE" 2>/dev/null; then
    DECLARED_MODULES=$(sed -n '/<modules>/,/<\/modules>/p' "$POM_FILE" \
        | grep '<module>' \
        | sed 's/.*<module>//;s/<\/module>.*//' \
        | xargs 2>/dev/null || echo "")
fi
# If no <modules> found, fall back to directory scan
if [ -z "$DECLARED_MODULES" ]; then
    DECLARED_MODULES=$(find "$PROJECT_ROOT" -maxdepth 2 -name "pom.xml" -not -path "$POM_FILE" 2>/dev/null \
        | while read -r mpom; do
            dirname "$mpom" | sed "s|$PROJECT_ROOT/||"
        done | sort || echo "")
fi

echo "   Declared modules: $DECLARED_MODULES"

# --- 3b. Classify each module by content inspection ---
MODULE_CORE=""
MODULE_UI_APPS=""
MODULE_UI_CONTENT=""
MODULE_UI_CONFIG=""
MODULE_UI_FRONTEND=""
MODULE_ALL=""
MODULE_IT_TESTS=""
MODULE_UI_TESTS=""
MODULE_DISPATCHER=""

classify_module() {
    local mod_path="$1"
    local mod_dir="$PROJECT_ROOT/$mod_path"
    local mod_pom="$mod_dir/pom.xml"
    local mod_name
    mod_name=$(basename "$mod_path")

    # Skip if directory doesn't exist
    [ -d "$mod_dir" ] || return

    # Read POM packaging type
    local packaging=""
    if [ -f "$mod_pom" ]; then
        packaging=$(pom_value "packaging" "$mod_pom")
    fi

    # --- Classify by content inspection (most reliable) ---

    # CORE / BUNDLE: Has src/main/java AND (packaging=bundle OR has bundle plugin)
    if [ -d "$mod_dir/src/main/java" ]; then
        if [ "$packaging" = "bundle" ] || [ "$packaging" = "jar" ] || [ -z "$packaging" ]; then
            if [ -z "$MODULE_CORE" ]; then
                MODULE_CORE="$mod_path"
                return
            fi
        fi
        # Also check for maven-bundle-plugin or bnd-maven-plugin
        if [ -f "$mod_pom" ]; then
            if grep -q 'maven-bundle-plugin\|bnd-maven-plugin\|sling-maven-plugin' "$mod_pom" 2>/dev/null; then
                if [ -z "$MODULE_CORE" ]; then
                    MODULE_CORE="$mod_path"
                    return
                fi
            fi
        fi
    fi

    # UI.APPS: Has jcr_root/apps
    if [ -d "$mod_dir/src/main/content/jcr_root/apps" ]; then
        # Distinguish ui.apps from ui.apps.structure (structure has no components)
        if echo "$mod_name" | grep -qi "structure"; then
            return  # skip structure modules
        fi
        if [ -z "$MODULE_UI_APPS" ]; then
            MODULE_UI_APPS="$mod_path"
            return
        fi
    fi

    # UI.CONFIG: Has osgiconfig directory OR config/ under jcr_root/apps
    if find "$mod_dir/src/main/content/jcr_root" -maxdepth 4 -type d \( -name "osgiconfig" -o -name "config" -o -name "config.author" -o -name "config.publish" \) 2>/dev/null | grep -q .; then
        # Only if NOT already classified as ui.apps (some projects combine them)
        if [ "$mod_path" != "$MODULE_UI_APPS" ]; then
            if [ -z "$MODULE_UI_CONFIG" ]; then
                MODULE_UI_CONFIG="$mod_path"
                return
            fi
        fi
    fi

    # UI.CONTENT: Has jcr_root/content OR filter.xml referencing /content/
    if [ -d "$mod_dir/src/main/content/jcr_root/content" ]; then
        if [ -z "$MODULE_UI_CONTENT" ]; then
            MODULE_UI_CONTENT="$mod_path"
            return
        fi
    fi
    if [ -f "$mod_dir/src/main/content/META-INF/vault/filter.xml" ]; then
        if grep -q '/content/' "$mod_dir/src/main/content/META-INF/vault/filter.xml" 2>/dev/null; then
            if [ -z "$MODULE_UI_CONTENT" ]; then
                MODULE_UI_CONTENT="$mod_path"
                return
            fi
        fi
    fi

    # UI.FRONTEND: Has package.json or webpack/vite config
    if [ -f "$mod_dir/package.json" ] || [ -f "$mod_dir/webpack.common.js" ] || [ -f "$mod_dir/webpack.config.js" ] || [ -f "$mod_dir/vite.config.js" ] || [ -f "$mod_dir/vite.config.ts" ]; then
        if [ -z "$MODULE_UI_FRONTEND" ]; then
            MODULE_UI_FRONTEND="$mod_path"
            return
        fi
    fi

    # ALL: content-package with <embeddeds> (container package)
    if [ "$packaging" = "content-package" ] && [ -f "$mod_pom" ]; then
        if grep -q '<embeddeds>\|<embedded>' "$mod_pom" 2>/dev/null; then
            if [ -z "$MODULE_ALL" ]; then
                MODULE_ALL="$mod_path"
                return
            fi
        fi
    fi

    # DISPATCHER: Has dispatcher config files
    if [ -d "$mod_dir/src/conf.dispatcher.d" ] || [ -d "$mod_dir/src/conf" ] || [ -d "$mod_dir/conf.dispatcher.d" ]; then
        if [ -z "$MODULE_DISPATCHER" ]; then
            MODULE_DISPATCHER="$mod_path"
            return
        fi
    fi

    # IT.TESTS / UI.TESTS: Name-based + content check
    if echo "$mod_name" | grep -qi 'it[._-]*test\|integration[._-]*test'; then
        if [ -z "$MODULE_IT_TESTS" ]; then
            MODULE_IT_TESTS="$mod_path"
            return
        fi
    fi
    if echo "$mod_name" | grep -qi 'ui[._-]*test\|e2e\|cypress\|playwright'; then
        if [ -z "$MODULE_UI_TESTS" ]; then
            MODULE_UI_TESTS="$mod_path"
            return
        fi
    fi
    # Check for Cypress/Playwright content even if name doesn't match
    if [ -f "$mod_dir/test-module/cypress.config.js" ] || [ -f "$mod_dir/cypress.config.js" ] || [ -f "$mod_dir/playwright.config.ts" ]; then
        if [ -z "$MODULE_UI_TESTS" ]; then
            MODULE_UI_TESTS="$mod_path"
            return
        fi
    fi
}

# Run classification on each declared module
for mod in $DECLARED_MODULES; do
    classify_module "$mod"
done

# --- 3c. Name-based fallbacks for anything not classified ---
# (Catches modules the content inspection missed, e.g. empty/new modules)
if [ -z "$MODULE_CORE" ] || [ -z "$MODULE_UI_APPS" ] || [ -z "$MODULE_UI_CONTENT" ]; then
    for mod in $DECLARED_MODULES; do
        mod_name=$(basename "$mod")
        if [ -z "$MODULE_CORE" ]; then
            case "$mod_name" in core|bundle|bundles|backend|java) MODULE_CORE="$mod" ;; esac
        fi
        if [ -z "$MODULE_UI_APPS" ]; then
            case "$mod_name" in ui.apps|uiapps|apps|applications) MODULE_UI_APPS="$mod" ;; esac
        fi
        if [ -z "$MODULE_UI_CONTENT" ]; then
            case "$mod_name" in ui.content|uicontent|content|sample-content) MODULE_UI_CONTENT="$mod" ;; esac
        fi
        if [ -z "$MODULE_UI_CONFIG" ]; then
            case "$mod_name" in ui.config|uiconfig|config|osgi-config|osgiconfig) MODULE_UI_CONFIG="$mod" ;; esac
        fi
        if [ -z "$MODULE_UI_FRONTEND" ]; then
            case "$mod_name" in ui.frontend|uifrontend|frontend|ui) MODULE_UI_FRONTEND="$mod" ;; esac
        fi
        if [ -z "$MODULE_ALL" ]; then
            case "$mod_name" in all|complete|full|assembly) MODULE_ALL="$mod" ;; esac
        fi
        if [ -z "$MODULE_DISPATCHER" ]; then
            case "$mod_name" in dispatcher|dispatcher.ams|dispatcher.cloud) MODULE_DISPATCHER="$mod" ;; esac
        fi
    done
fi

# --- 3d. Final defaults if still unresolved ---
[ -z "$MODULE_CORE" ] && MODULE_CORE="core" && warn "Could not detect Java/bundle module — defaulting to 'core'"
[ -z "$MODULE_UI_APPS" ] && MODULE_UI_APPS="ui.apps" && warn "Could not detect ui.apps module — defaulting to 'ui.apps'"
[ -z "$MODULE_UI_CONTENT" ] && MODULE_UI_CONTENT="ui.content" && warn "Could not detect ui.content module — defaulting to 'ui.content'"
[ -z "$MODULE_UI_CONFIG" ] && MODULE_UI_CONFIG="ui.config"
[ -z "$MODULE_UI_FRONTEND" ] && MODULE_UI_FRONTEND="ui.frontend"
[ -z "$MODULE_ALL" ] && MODULE_ALL="all"
[ -z "$MODULE_IT_TESTS" ] && MODULE_IT_TESTS="it.tests"
[ -z "$MODULE_UI_TESTS" ] && MODULE_UI_TESTS="ui.tests"
[ -z "$MODULE_DISPATCHER" ] && MODULE_DISPATCHER="dispatcher"

echo "   Modules:"
echo "     core:        $MODULE_CORE"
echo "     ui.apps:     $MODULE_UI_APPS"
echo "     ui.content:  $MODULE_UI_CONTENT"
echo "     ui.config:   $MODULE_UI_CONFIG"
echo "     ui.frontend: $MODULE_UI_FRONTEND"
echo "     all:         $MODULE_ALL"
echo "     dispatcher:  $MODULE_DISPATCHER"

# =============================================================================
# 4. Discover Java package structure
# =============================================================================
JAVA_SRC_ROOT=""
JAVA_PACKAGE=""
JAVA_PACKAGE_PATH=""
JAVA_TEST_ROOT=""
TEST_CONTEXT_CLASS=""

# Try the detected core module first, then search broadly
CORE_JAVA_DIR="$PROJECT_ROOT/$MODULE_CORE/src/main/java"
if [ ! -d "$CORE_JAVA_DIR" ]; then
    # Broader search: find the first module with src/main/java containing .java files
    CORE_JAVA_DIR=$(find "$PROJECT_ROOT" -maxdepth 4 -path "*/src/main/java" -type d 2>/dev/null \
        | while read -r jdir; do
            # Skip test directories, skip .agent
            echo "$jdir" | grep -q '\.agent\|target\|node_modules' && continue
            if find "$jdir" -name "*.java" 2>/dev/null | head -1 | grep -q .; then
                echo "$jdir"
                break
            fi
        done || echo "")
    if [ -n "$CORE_JAVA_DIR" ]; then
        # Update MODULE_CORE to match what we actually found
        local_mod=$(echo "$CORE_JAVA_DIR" | sed "s|$PROJECT_ROOT/||;s|/src/main/java||")
        if [ "$local_mod" != "$MODULE_CORE" ]; then
            echo "   (Auto-corrected core module: $MODULE_CORE → $local_mod)"
            MODULE_CORE="$local_mod"
        fi
    fi
fi

if [ -d "$CORE_JAVA_DIR" ]; then
    JAVA_SRC_ROOT="$MODULE_CORE/src/main/java"
    FIRST_JAVA=$(find "$CORE_JAVA_DIR" -name "*.java" -not -name "package-info.java" 2>/dev/null | head -1 || echo "")
    if [ -n "$FIRST_JAVA" ]; then
        JAVA_PACKAGE_PATH=$(dirname "$FIRST_JAVA" | sed "s|$PROJECT_ROOT/$JAVA_SRC_ROOT/||")
        # Strip sub-package segments to get base package
        JAVA_PACKAGE_PATH=$(echo "$JAVA_PACKAGE_PATH" | sed 's|/models.*||;s|/services.*||;s|/servlets.*||;s|/filters.*||;s|/schedulers.*||;s|/listeners.*||;s|/workflows.*||;s|/jobs.*||;s|/impl.*||;s|/utils.*||;s|/helpers.*||;s|/config.*||;s|/beans.*||;s|/dto.*||;s|/pojo.*||')
        JAVA_PACKAGE=$(echo "$JAVA_PACKAGE_PATH" | tr '/' '.')
    fi
else
    warn "No Java source directory found — check MODULE_CORE in project.yaml"
fi

# Find test directory — try detected core module first, then broader search
CORE_TEST_DIR="$PROJECT_ROOT/$MODULE_CORE/src/test/java"
if [ ! -d "$CORE_TEST_DIR" ]; then
    CORE_TEST_DIR=$(find "$PROJECT_ROOT" -maxdepth 4 -path "$PROJECT_ROOT/$MODULE_CORE/*/src/test/java" -type d 2>/dev/null | head -1 || echo "")
fi

if [ -d "$CORE_TEST_DIR" ]; then
    JAVA_TEST_ROOT="$MODULE_CORE/src/test/java"
    TEST_CONTEXT_FILE=$(find "$CORE_TEST_DIR" \( -name "*AemContext*.java" -o -name "*TestContext*.java" -o -name "*TestSetup*.java" \) 2>/dev/null | head -1 || echo "")
    if [ -n "$TEST_CONTEXT_FILE" ]; then
        TEST_CONTEXT_CLASS=$(basename "$TEST_CONTEXT_FILE" | sed 's/.java$//')
    fi
fi

echo "   Package:    $JAVA_PACKAGE"
echo "   Test ctx:   ${TEST_CONTEXT_CLASS:-none found}"

# =============================================================================
# 5. Discover JCR paths
# =============================================================================
APPS_ROOT=""
CONTENT_ROOT=""
CONF_ROOT=""

# Try the detected ui.apps module first
UI_APPS_JCR="$PROJECT_ROOT/$MODULE_UI_APPS/src/main/content/jcr_root/apps"
if [ ! -d "$UI_APPS_JCR" ]; then
    # Broader search: find any module with jcr_root/apps
    UI_APPS_JCR=$(find "$PROJECT_ROOT" -maxdepth 5 -path "*/src/main/content/jcr_root/apps" -type d 2>/dev/null \
        | grep -v 'target\|\.agent' | head -1 || echo "")
    if [ -n "$UI_APPS_JCR" ]; then
        local_mod=$(echo "$UI_APPS_JCR" | sed "s|$PROJECT_ROOT/||;s|/src/main/content/jcr_root/apps||")
        if [ "$local_mod" != "$MODULE_UI_APPS" ]; then
            echo "   (Auto-corrected ui.apps module: $MODULE_UI_APPS → $local_mod)"
            MODULE_UI_APPS="$local_mod"
        fi
    fi
fi

if [ -d "$UI_APPS_JCR" ]; then
    # Find the app root — skip structure-only dirs, prefer dirs with components/
    FIRST_APP_DIR=""
    for app_dir in "$UI_APPS_JCR"/*/; do
        [ -d "$app_dir" ] || continue
        app_name=$(basename "$app_dir")
        # Skip common non-app directories
        case "$app_name" in
            cq|dam|wcm|sling|granite|core) continue ;;
        esac
        # Prefer directories that have components/ underneath
        if [ -d "$app_dir/components" ]; then
            FIRST_APP_DIR="$app_dir"
            break
        fi
        # Fallback to first non-system directory found
        if [ -z "$FIRST_APP_DIR" ]; then
            FIRST_APP_DIR="$app_dir"
        fi
    done
    if [ -n "$FIRST_APP_DIR" ]; then
        APPS_ROOT="/apps/$(basename "$FIRST_APP_DIR")"
    fi
fi

# Try multiple locations for content filter
CONTENT_FILTER=""
for filter_candidate in \
    "$PROJECT_ROOT/$MODULE_UI_CONTENT/src/main/content/META-INF/vault/filter.xml" \
    "$PROJECT_ROOT/$MODULE_UI_APPS/src/main/content/META-INF/vault/filter.xml"; do
    if [ -f "$filter_candidate" ]; then
        CONTENT_FILTER="$filter_candidate"
        break
    fi
done

if [ -n "$CONTENT_FILTER" ] && [ -f "$CONTENT_FILTER" ]; then
    CONTENT_ROOT=$(sed -n 's/.*root="\(\/content\/[^"]*\)".*/\1/p' "$CONTENT_FILTER" 2>/dev/null | head -1 || echo "")
    CONF_ROOT=$(sed -n 's/.*root="\(\/conf\/[^"]*\)".*/\1/p' "$CONTENT_FILTER" 2>/dev/null | head -1 || echo "")
fi

if [ -z "$CONTENT_ROOT" ]; then
    # Try to find content from jcr_root
    CONTENT_JCR="$PROJECT_ROOT/$MODULE_UI_CONTENT/src/main/content/jcr_root/content"
    if [ ! -d "$CONTENT_JCR" ]; then
        CONTENT_JCR=$(find "$PROJECT_ROOT" -maxdepth 5 -path "*/src/main/content/jcr_root/content" -type d 2>/dev/null \
            | grep -v 'target\|\.agent' | head -1 || echo "")
    fi
    if [ -d "$CONTENT_JCR" ]; then
        CONTENT_DIR=$(find "$CONTENT_JCR" -maxdepth 1 -type d 2>/dev/null | tail -1 || echo "")
        if [ -n "$CONTENT_DIR" ]; then
            CONTENT_ROOT=$(echo "$CONTENT_DIR" | sed "s|.*jcr_root||")
        fi
    fi
fi
if [ -z "$CONTENT_ROOT" ]; then
    CONTENT_ROOT="/content/$ARTIFACT_ID"
    warn "Could not detect content root — defaulting to /content/$ARTIFACT_ID"
fi
if [ -z "$CONF_ROOT" ]; then
    CONF_ROOT=$(echo "$CONTENT_ROOT" | sed 's|/content/|/conf/|')
fi

APP_NAME=$(basename "$APPS_ROOT")
COMPONENT_PATH="$APPS_ROOT/components"
CLIENTLIB_PATH="$APPS_ROOT/clientlibs"

echo "   Apps:       $APPS_ROOT"
echo "   Content:    $CONTENT_ROOT"
echo "   Conf:       $CONF_ROOT"

# =============================================================================
# 6. Discover component group
# =============================================================================
COMPONENT_GROUP=""
COMP_FS_ROOT="$PROJECT_ROOT/$MODULE_UI_APPS/src/main/content/jcr_root${COMPONENT_PATH}"
if [ -d "$COMP_FS_ROOT" ]; then
    COMPONENT_GROUP=$(grep -rh 'componentGroup=' "$COMP_FS_ROOT" 2>/dev/null \
        | sed -n 's/.*componentGroup="\([^"]*\)".*/\1/p' \
        | sort | uniq -c | sort -rn | head -1 | sed 's/^[[:space:]]*[0-9]*[[:space:]]*//' || echo "")
fi
if [ -z "$COMPONENT_GROUP" ]; then
    COMPONENT_GROUP="$ARTIFACT_ID - Content"
fi
echo "   Comp group: $COMPONENT_GROUP"

# =============================================================================
# 7. Discover template and page resource type
# =============================================================================
PAGE_TEMPLATE=""
PAGE_RESOURCE_TYPE=""
CONTAINER_RESOURCE_TYPE=""

TEMPLATE_DIR="$PROJECT_ROOT/$MODULE_UI_CONTENT/src/main/content/jcr_root${CONF_ROOT}/settings/wcm/templates"
if [ -d "$TEMPLATE_DIR" ]; then
    FIRST_TEMPLATE=$(ls -d "$TEMPLATE_DIR"/*/ 2>/dev/null | head -1 || echo "")
    if [ -n "$FIRST_TEMPLATE" ]; then
        TEMPLATE_NAME=$(basename "$FIRST_TEMPLATE")
    else
        TEMPLATE_NAME="page-content"
    fi
    PAGE_TEMPLATE="${CONF_ROOT}/settings/wcm/templates/${TEMPLATE_NAME}"

    TEMPLATE_CONTENT="$TEMPLATE_DIR/$TEMPLATE_NAME/.content.xml"
    if [ -f "$TEMPLATE_CONTENT" ]; then
        PAGE_RESOURCE_TYPE=$(sed -n 's/.*sling:resourceType="\([^"]*\)".*/\1/p' "$TEMPLATE_CONTENT" 2>/dev/null | head -1 || echo "")
    fi
fi

if [ -z "$PAGE_RESOURCE_TYPE" ]; then
    PAGE_RESOURCE_TYPE="${APP_NAME}/components/page"
fi

CONTAINER_RESOURCE_TYPE="${APP_NAME}/components/container"
if [ ! -d "$PROJECT_ROOT/$MODULE_UI_APPS/src/main/content/jcr_root${APPS_ROOT}/components/container" ]; then
    CONTAINER_RESOURCE_TYPE="wcm/foundation/components/responsivegrid"
fi

echo "   Template:   $PAGE_TEMPLATE"
echo "   Page RT:    $PAGE_RESOURCE_TYPE"

# =============================================================================
# 8. Discover content language root
# =============================================================================
CONTENT_LANG_ROOT=""
CONTENT_FS_ROOT="$PROJECT_ROOT/$MODULE_UI_CONTENT/src/main/content/jcr_root${CONTENT_ROOT}"
if [ -d "$CONTENT_FS_ROOT" ]; then
    for lang_path in "us/en" "en" "language-masters/en" "us" ""; do
        if [ -f "$CONTENT_FS_ROOT/$lang_path/.content.xml" ]; then
            CONTENT_LANG_ROOT="${CONTENT_ROOT}/${lang_path}"
            break
        fi
    done
fi
if [ -z "$CONTENT_LANG_ROOT" ]; then
    CONTENT_LANG_ROOT="$CONTENT_ROOT"
fi
echo "   Lang root:  $CONTENT_LANG_ROOT"

# =============================================================================
# 9. Existing components inventory
# =============================================================================
COMPONENTS_LIST=""
if [ -d "$COMP_FS_ROOT" ]; then
    COMPONENTS_LIST=$(ls -d "$COMP_FS_ROOT"/*/ 2>/dev/null | while read -r dir; do
        name=$(basename "$dir")
        has_dialog="no"
        has_model="no"
        is_proxy="no"
        [ -d "$dir/_cq_dialog" ] && has_dialog="yes"
        grep -q "sling:resourceSuperType" "$dir/.content.xml" 2>/dev/null && is_proxy="yes"
        if [ -n "$JAVA_SRC_ROOT" ]; then
            if find "$PROJECT_ROOT/$JAVA_SRC_ROOT" -iname "*${name}*model*.java" 2>/dev/null | grep -q .; then
                has_model="yes"
            fi
        fi
        echo "    - name: \"$name\""
        echo "      hasDialog: $has_dialog"
        echo "      hasModel: $has_model"
        echo "      isProxy: $is_proxy"
    done || echo "")
fi

# =============================================================================
# 10. Testing framework
# =============================================================================
TEST_FRAMEWORK="junit5"
MOCKING_FRAMEWORK="mockito"
AEM_MOCKS_VERSION=""

CORE_POM="$PROJECT_ROOT/$MODULE_CORE/pom.xml"
if [ -f "$CORE_POM" ]; then
    if grep -q "junit-jupiter" "$CORE_POM" 2>/dev/null; then
        TEST_FRAMEWORK="junit5"
    elif grep -q "junit" "$CORE_POM" 2>/dev/null; then
        TEST_FRAMEWORK="junit4"
    fi
    AEM_MOCKS_VERSION=$(dep_version "io.wcm.testing.aem-mock" "$CORE_POM")
    # Fallback: version may be in root pom dependencyManagement
    if [ -z "$AEM_MOCKS_VERSION" ]; then
        AEM_MOCKS_VERSION=$(dep_version "io.wcm.testing.aem-mock" "$POM_FILE")
    fi
fi

echo "   Tests:      $TEST_FRAMEWORK + $MOCKING_FRAMEWORK"

# =============================================================================
# 11. AEM instance URLs & deploy profiles
# =============================================================================
AUTHOR_URL="http://localhost:4502"
PUBLISH_URL="http://localhost:4503"

DEPLOY_PROFILE="autoInstallPackage"
DEPLOY_BUNDLE_PROFILE="autoInstallBundle"
if grep -q "autoInstallSinglePackage" "$POM_FILE" 2>/dev/null; then
    DEPLOY_PROFILE="autoInstallSinglePackage"
fi

CONTENT_FILTER_MODE="replace"
if [ -f "$CONTENT_FILTER" ]; then
    if grep -q 'mode="merge"' "$CONTENT_FILTER" 2>/dev/null; then
        CONTENT_FILTER_MODE="merge"
    fi
fi

CLIENTLIB_CATEGORIES=""
CLIENTLIB_FS_ROOT="$PROJECT_ROOT/$MODULE_UI_APPS/src/main/content/jcr_root${CLIENTLIB_PATH}"
if [ -d "$CLIENTLIB_FS_ROOT" ]; then
    CLIENTLIB_CATEGORIES=$(find "$CLIENTLIB_FS_ROOT" -name ".content.xml" -exec sed -n 's/.*categories="\[\([^]]*\)\]".*/\1/p' {} \; 2>/dev/null \
        | tr ',' '\n' | xargs | tr ' ' ',' || echo "")
fi

# =============================================================================
# GENERATE project.yaml
# =============================================================================
echo ""
echo "📝 Generating $OUTPUT_FILE ..."

cat > "$OUTPUT_FILE" << YAML
# ============================================================================
# AEM Feature Agent — Project Configuration
# ============================================================================
# Auto-generated by setup.sh on $(date +%Y-%m-%d)
# Review and adjust any values as needed, then commit to your repo.
# ============================================================================

project:
  groupId: "${GROUP_ID}"
  artifactId: "${ARTIFACT_ID}"
  version: "${VERSION}"
  displayName: "${ARTIFACT_ID}"

aem:
  type: "${AEM_TYPE}"
  sdkVersion: "${AEM_SDK_VERSION}"
  uberJarVersion: "${UBER_JAR_VERSION}"
  javaVersion: "${JAVA_VERSION}"
  authorUrl: "${AUTHOR_URL}"
  publishUrl: "${PUBLISH_URL}"
  credentials: "admin:admin"

modules:
  core: "${MODULE_CORE}"
  uiApps: "${MODULE_UI_APPS}"
  uiContent: "${MODULE_UI_CONTENT}"
  uiConfig: "${MODULE_UI_CONFIG}"
  uiFrontend: "${MODULE_UI_FRONTEND}"
  all: "${MODULE_ALL}"
  itTests: "${MODULE_IT_TESTS}"
  uiTests: "${MODULE_UI_TESTS}"
  dispatcher: "${MODULE_DISPATCHER}"

java:
  basePackage: "${JAVA_PACKAGE}"
  basePackagePath: "${JAVA_PACKAGE_PATH}"
  srcRoot: "${JAVA_SRC_ROOT}"
  testRoot: "${JAVA_TEST_ROOT}"
  testContextClass: "${TEST_CONTEXT_CLASS}"

jcr:
  appsRoot: "${APPS_ROOT}"
  contentRoot: "${CONTENT_ROOT}"
  confRoot: "${CONF_ROOT}"
  componentPath: "${COMPONENT_PATH}"
  clientlibPath: "${CLIENTLIB_PATH}"
  contentLangRoot: "${CONTENT_LANG_ROOT}"

components:
  group: "${COMPONENT_GROUP}"
  pageResourceType: "${PAGE_RESOURCE_TYPE}"
  containerResourceType: "${CONTAINER_RESOURCE_TYPE}"
  pageTemplate: "${PAGE_TEMPLATE}"
  clientlibPrefix: "${APP_NAME}"
  clientlibCategories: "${CLIENTLIB_CATEGORIES}"

build:
  deployProfile: "${DEPLOY_PROFILE}"
  deployBundleProfile: "${DEPLOY_BUNDLE_PROFILE}"
  contentFilterMode: "${CONTENT_FILTER_MODE}"

testing:
  framework: "${TEST_FRAMEWORK}"
  mockingFramework: "${MOCKING_FRAMEWORK}"
  aemMocksVersion: "${AEM_MOCKS_VERSION}"

existingComponents:
${COMPONENTS_LIST}

versionNotes:
$(if [ "$AEM_TYPE" = "cloud" ]; then
cat << 'CLOUD'
  - "Use aem-sdk-api instead of uber-jar"
  - "OSGi configs: config.author/, config.publish/, config.dev/, config.stage/, config.prod/"
  - "Dispatcher uses Cloud Dispatcher SDK"
  - "Replication API replaced with Sling Content Distribution"
CLOUD
elif [ "$AEM_TYPE" = "lts" ]; then
cat << 'LTS'
  - "Uses uber-jar (6.6.x+), compatible with Java 11 or 17"
  - "OSGi configs: config/, config.author/, config.publish/"
  - "AMS-style dispatcher with conf.dispatcher.d/"
  - "Standard replication API available"
LTS
elif [ "$AEM_TYPE" = "ams" ]; then
cat << 'AMS'
  - "Uses uber-jar (6.5.x), typically Java 8 or 11"
  - "OSGi configs: config/, config.author/, config.publish/"
  - "AMS dispatcher layout with conf.dispatcher.d/"
  - "Standard replication API available"
AMS
else
cat << 'ONPREM'
  - "Uses uber-jar (6.5.x), typically Java 8 or 11"
  - "OSGi configs in config/ folder"
  - "Classic dispatcher or no dispatcher module"
  - "Standard replication API available"
ONPREM
fi)
YAML

echo "✅ Generated: $OUTPUT_FILE"
echo ""

# =============================================================================
# Install universal agent files into .agent/
# =============================================================================
UNIVERSAL_DIR="$AGENT_DIR/universal"

if [ -f "$AGENT_DIR/AGENT.md" ] && [ ! -f "$AGENT_DIR/AGENT.md.bak" ]; then
    echo "📋 Backing up existing agent files..."
    cp "$AGENT_DIR/AGENT.md" "$AGENT_DIR/AGENT.md.bak" 2>/dev/null || true
    cp "$AGENT_DIR/REPO_CONTEXT.md" "$AGENT_DIR/REPO_CONTEXT.md.bak" 2>/dev/null || true
fi

for f in AGENT.md REPO_CONTEXT.md QUICKSTART.md; do
    if [ -f "$UNIVERSAL_DIR/$f" ]; then
        cp "$UNIVERSAL_DIR/$f" "$AGENT_DIR/$f"
        echo "   Installed: $f"
    fi
done

# =============================================================================
# Install custom agent mode into .github/agents/
# =============================================================================
GITHUB_AGENTS_DIR="$PROJECT_ROOT/.github/agents"
if [ -f "$UNIVERSAL_DIR/aem-feature.agent.md" ]; then
    mkdir -p "$GITHUB_AGENTS_DIR"
    cp "$UNIVERSAL_DIR/aem-feature.agent.md" "$GITHUB_AGENTS_DIR/aem-feature.agent.md"
    echo "   Installed: .github/agents/aem-feature.agent.md (Custom Agent Mode)"
fi

echo ""
echo "🎉 Setup complete!"
echo ""
if [ -n "$WARNINGS" ]; then
    echo "⚠️  Warnings (review project.yaml and fix if needed):"
    echo -e "$WARNINGS"
    echo ""
fi
echo "Next steps:"
echo "  1. Review .agent/project.yaml and adjust any values"
echo "  2. Open VS Code Copilot Chat, select the 'AEM Feature' agent from the agent picker, and type:"
echo '     Create a Hero Banner component with background image, title, and CTA button'
echo "  3. Or paste the classic prompt:"
echo '     @workspace Read .agent/AGENT.md, .agent/REPO_CONTEXT.md, and .agent/project.yaml fully.'
echo '     Then execute all 8 steps for: FEATURE: "Your feature here"'
echo ""
