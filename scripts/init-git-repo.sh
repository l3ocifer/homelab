#!/bin/bash
# Initialize homelab as a git repo with submodules
# This script converts existing nested repos to submodules
#
# NOTE: This script has been run. The homelab repo is now initialized.
# Keeping for documentation purposes.

set -e

HOMELAB_DIR="/home/l3o/git/homelab"
cd "$HOMELAB_DIR"

echo "=== Homelab Git Repository Initialization ==="
echo ""

# Check if already a git repo
if [ -d ".git" ]; then
    echo "homelab is already a git repo - nothing to do"
    echo "Use 'git submodule update --init --recursive' to update submodules"
    exit 0
fi

# Define submodules (path -> remote URL)
declare -A SUBMODULES=(
    ["alef"]="git@github.com:l3ocifer/alef.git"
    ["claude-configs"]="git@github.com:l3ocifer/claude-configs.git"
    ["cursor-configs"]="git@github.com:l3ocifer/cursor-configs.git"
    ["mcp-modules-rust"]="git@github.com:l3ocifer/mcp-modules-rust.git"
    ["services"]="git@github.com:l3ocifer/services.git"
    ["thebeast"]="git@github.com:l3ocifer/thebeast.git"
)

echo "Step 1: Backing up existing .git directories..."
BACKUP_DIR="$HOMELAB_DIR/.git-backup-$(date +%Y%m%d-%H%M%S)"
mkdir -p "$BACKUP_DIR"

for submod in "${!SUBMODULES[@]}"; do
    if [ -d "$submod/.git" ]; then
        echo "  Backing up $submod/.git"
        cp -r "$submod/.git" "$BACKUP_DIR/$submod-git"
    fi
done

# Backup nested submodule
if [ -d "services/ollama_proxy_server/.git" ]; then
    echo "  Backing up services/ollama_proxy_server/.git"
    cp -r "services/ollama_proxy_server/.git" "$BACKUP_DIR/ollama_proxy_server-git"
fi

echo ""
echo "Step 2: Removing .git directories from subdirectories..."
for submod in "${!SUBMODULES[@]}"; do
    if [ -d "$submod/.git" ]; then
        echo "  Removing $submod/.git"
        rm -rf "$submod/.git"
    fi
done

# Handle nested submodule
if [ -d "services/ollama_proxy_server/.git" ]; then
    echo "  Removing services/ollama_proxy_server/.git"
    rm -rf "services/ollama_proxy_server/.git"
fi

echo ""
echo "Step 3: Initializing homelab as git repository..."
git init

echo ""
echo "Step 4: Adding submodules..."
for submod in "${!SUBMODULES[@]}"; do
    echo "  Adding submodule: $submod -> ${SUBMODULES[$submod]}"
    # Remove the directory temporarily
    mv "$submod" "$submod.bak"
    # Add as submodule
    git submodule add "${SUBMODULES[$submod]}" "$submod"
    # Remove the cloned directory
    rm -rf "$submod"
    # Restore original directory
    mv "$submod.bak" "$submod"
done

echo ""
echo "Step 5: Creating docs directory structure..."
mkdir -p docs

echo ""
echo "Step 6: Moving and renaming documentation files..."

# Move root-level docs to docs/ with lowercase-dashes naming
declare -A DOC_RENAMES=(
    ["CAPACITY_AND_HEALTH_REPORT.md"]="docs/capacity-and-health-report.md"
    ["OLLAMA_INTEGRATION_SUMMARY.md"]="docs/ollama-integration-summary.md"
    ["OLLAMA_PROXY_COMPLETE_SETUP.md"]="docs/ollama-proxy-complete-setup.md"
    ["REORGANIZATION_PLAN.md"]="docs/reorganization-plan.md"
)

for old_name in "${!DOC_RENAMES[@]}"; do
    new_name="${DOC_RENAMES[$old_name]}"
    if [ -f "$old_name" ]; then
        echo "  Moving $old_name -> $new_name"
        mv "$old_name" "$new_name"
    fi
done

# Move existing docs if they exist with old naming
if [ -f "docs/OLLAMA_CURSOR_INTEGRATION.md" ]; then
    mv "docs/OLLAMA_CURSOR_INTEGRATION.md" "docs/ollama-cursor-integration.md"
fi
if [ -f "docs/OLLAMA_SETUP_COMPLETE.md" ]; then
    mv "docs/OLLAMA_SETUP_COMPLETE.md" "docs/ollama-setup-complete.md"
fi

echo ""
echo "Step 7: Initial commit..."
git add .gitignore
git add .gitmodules
git add README.md
git add docs/
git add scripts/

git commit -m "$(cat <<'EOF'
feat: initialize homelab as monorepo with submodules

- Add submodules for alef, claude-configs, cursor-configs,
  mcp-modules-rust, services, and thebeast
- Consolidate documentation in docs/ with lowercase-dashes naming
- Add comprehensive .gitignore
EOF
)"

echo ""
echo "=== Done! ==="
echo ""
echo "Backup of original .git directories: $BACKUP_DIR"
echo ""
echo "Next steps:"
echo "  1. Create GitHub repo: gh repo create l3ocifer/homelab --public"
echo "  2. Add remote: git remote add origin git@github.com:l3ocifer/homelab.git"
echo "  3. Push: git push -u origin main"
echo ""
echo "To restore submodules on clone:"
echo "  git clone --recurse-submodules git@github.com:l3ocifer/homelab.git"
