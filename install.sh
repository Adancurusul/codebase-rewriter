#!/usr/bin/env bash
set -euo pipefail

# Codebase Rewriter - Installation Script
# Installs the skill into a target project's .claude/skills/ directory

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_NAME="codebase-rewriter"

usage() {
    echo "Usage: $0 <target-project-path> [--symlink]"
    echo ""
    echo "Install codebase-rewriter skill into a project."
    echo ""
    echo "Arguments:"
    echo "  target-project-path   Path to the project where the skill will be installed"
    echo ""
    echo "Options:"
    echo "  --symlink             Create a symlink instead of copying (for development)"
    echo "  --uninstall           Remove the skill from the target project"
    echo "  --gitignore           Only add .migration-plan/ to .gitignore"
    echo "  -h, --help            Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0 ~/projects/my-app"
    echo "  $0 ~/projects/my-app --symlink"
    echo "  $0 ~/projects/my-app --uninstall"
}

# Parse arguments
SYMLINK=false
UNINSTALL=false
GITIGNORE_ONLY=false
TARGET=""

while [[ $# -gt 0 ]]; do
    case $1 in
        --symlink)
            SYMLINK=true
            shift
            ;;
        --uninstall)
            UNINSTALL=true
            shift
            ;;
        --gitignore)
            GITIGNORE_ONLY=true
            shift
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        -*)
            echo "Error: Unknown option $1"
            usage
            exit 1
            ;;
        *)
            TARGET="$1"
            shift
            ;;
    esac
done

if [[ -z "$TARGET" ]]; then
    echo "Error: target-project-path is required"
    echo ""
    usage
    exit 1
fi

# Resolve to absolute path
TARGET="$(cd "$TARGET" 2>/dev/null && pwd)" || {
    echo "Error: Directory does not exist: $TARGET"
    exit 1
}

SKILL_DIR="$TARGET/.claude/skills/$SKILL_NAME"

# Add .migration-plan/ to .gitignore
add_gitignore() {
    local gitignore="$TARGET/.gitignore"
    local entry=".migration-plan/"

    if [[ -f "$gitignore" ]]; then
        if grep -qF "$entry" "$gitignore" 2>/dev/null; then
            echo "  .gitignore already contains $entry"
            return
        fi
    fi

    echo "$entry" >> "$gitignore"
    echo "  Added $entry to .gitignore"
}

# Uninstall
if [[ "$UNINSTALL" == true ]]; then
    if [[ -e "$SKILL_DIR" ]]; then
        rm -rf "$SKILL_DIR"
        echo "Removed: $SKILL_DIR"
    else
        echo "Not installed: $SKILL_DIR does not exist"
    fi
    exit 0
fi

# Gitignore only
if [[ "$GITIGNORE_ONLY" == true ]]; then
    add_gitignore
    exit 0
fi

# Check if already installed
if [[ -e "$SKILL_DIR" ]]; then
    if [[ -L "$SKILL_DIR" ]]; then
        CURRENT_LINK="$(readlink "$SKILL_DIR")"
        echo "Already installed as symlink -> $CURRENT_LINK"
    else
        echo "Already installed at $SKILL_DIR"
    fi
    echo ""
    read -p "Overwrite? [y/N] " -n 1 -r
    echo ""
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Aborted."
        exit 0
    fi
    rm -rf "$SKILL_DIR"
fi

# Create parent directory
mkdir -p "$TARGET/.claude/skills"

# Install
if [[ "$SYMLINK" == true ]]; then
    ln -sfn "$SCRIPT_DIR" "$SKILL_DIR"
    echo "Installed (symlink): $SKILL_DIR -> $SCRIPT_DIR"
else
    cp -r "$SCRIPT_DIR" "$SKILL_DIR"
    rm -f "$SKILL_DIR/install.sh"
    echo "Installed (copy): $SKILL_DIR"
fi

# Add to .gitignore
add_gitignore

echo ""
echo "Done. Use '/codebase-rewriter' or ask Claude to plan a Rust migration."
