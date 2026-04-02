#!/usr/bin/env bash
# ============================================================================
# AEM Feature Agent — One-Step Installer
# ============================================================================
# Copies the universal agent files into any AEM project and runs setup.
#
# Usage (from the source project that already has the agent):
#   bash /path/to/.agent/universal/install.sh /path/to/target-aem-project
#
# Or if this script was given to you standalone:
#   bash install.sh /path/to/target-aem-project
#
# What it does:
#   1. Copies .agent/universal/ (setup.sh, AGENT.md, REPO_CONTEXT.md,
#      QUICKSTART.md) into the target project
#   2. Runs setup.sh to scan the project and generate project.yaml
#   3. Installs AGENT.md and REPO_CONTEXT.md at .agent/ level
# ============================================================================

set -euo pipefail

# --- Resolve source directory (where this script lives) ---
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# --- Resolve target project ---
TARGET_PROJECT="${1:-}"
if [ -z "$TARGET_PROJECT" ]; then
    echo "❌ Usage: bash install.sh /path/to/your-aem-project"
    echo ""
    echo "   This installs the AEM Feature Agent into any AEM Maven project."
    echo "   The target directory must have a pom.xml."
    exit 1
fi

if [ ! -d "$TARGET_PROJECT" ]; then
    echo "❌ Directory not found: $TARGET_PROJECT"
    exit 1
fi

TARGET_PROJECT="$(cd "$TARGET_PROJECT" && pwd)"

if [ ! -f "$TARGET_PROJECT/pom.xml" ]; then
    echo "❌ No pom.xml found at $TARGET_PROJECT"
    echo "   Is this an AEM Maven project?"
    exit 1
fi

echo "🚀 AEM Feature Agent — Installer"
echo "   Source:  $SCRIPT_DIR"
echo "   Target:  $TARGET_PROJECT"
echo ""

# --- Copy universal agent files ---
TARGET_AGENT_DIR="$TARGET_PROJECT/.agent/universal"
mkdir -p "$TARGET_AGENT_DIR"

COPIED=0
for f in setup.sh AGENT.md REPO_CONTEXT.md QUICKSTART.md install.sh; do
    if [ -f "$SCRIPT_DIR/$f" ]; then
        cp "$SCRIPT_DIR/$f" "$TARGET_AGENT_DIR/$f"
        echo "   ✅ Copied: .agent/universal/$f"
        COPIED=$((COPIED + 1))
    fi
done

if [ "$COPIED" -eq 0 ]; then
    echo "❌ No agent files found in $SCRIPT_DIR"
    exit 1
fi

# Make setup.sh and install.sh executable
chmod +x "$TARGET_AGENT_DIR/setup.sh" 2>/dev/null || true
chmod +x "$TARGET_AGENT_DIR/install.sh" 2>/dev/null || true

# --- Copy VS Code agent files to .github/agents/ ---
TARGET_AGENTS_DIR="$TARGET_PROJECT/.github/agents"
mkdir -p "$TARGET_AGENTS_DIR"

for agent_file in aem-feature.agent.md aem-qa.agent.md aem-fullstack.agent.md jira-planner.agent.md; do
    if [ -f "$SCRIPT_DIR/$agent_file" ]; then
        cp "$SCRIPT_DIR/$agent_file" "$TARGET_AGENTS_DIR/$agent_file"
        echo "   ✅ Copied: .github/agents/$agent_file"
    fi
done

echo ""
echo "📡 Running project scanner..."
echo ""

# --- Run setup.sh on the target project ---
bash "$TARGET_AGENT_DIR/setup.sh" "$TARGET_PROJECT"

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "✅ Agent installed successfully!"
echo ""
echo "Installed agents:"
echo "  🔨 aem-feature   — Build AEM components/features end-to-end"
echo "  🧪 aem-qa        — Visual QA validation of AEM components"
echo "  🚀 aem-fullstack — Plan → Build → QA → PR in one pipeline"
echo "  📋 jira-planner  — Parse Jira exports → dev plans → orchestrate implementation → PRs"
echo ""
echo "Next steps:"
echo "  1. cd $TARGET_PROJECT"
echo "  2. Review .agent/project.yaml (fix any ⚠️  warnings)"
echo "  3. git add .agent/ .github/agents/ && git commit -m 'Add AEM agents'"
echo "  4. Open VS Code Copilot Chat → click agent picker → select an agent:"
echo ""
echo "     AEM Feature:    Describe a feature to build"
echo "     AEM QA:         Provide a component name or authoring URL to test"
echo "     AEM Full-Stack: Provide a Jira export or feature list for end-to-end delivery"
echo "     Jira Planner:   Provide a Jira export file path"
echo ""
echo "To install in another project later:"
echo "  bash $TARGET_PROJECT/.agent/universal/install.sh /path/to/other-project"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
