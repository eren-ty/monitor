#!/usr/bin/env sh
set -eu

PROJECT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
cd "$PROJECT_DIR"

if [ ! -d .git ]; then
  echo "This directory is not a Git repository: $PROJECT_DIR" >&2
  exit 1
fi

HOOK_FILE=".git/hooks/post-merge"

cat > "$HOOK_FILE" <<'EOF'
#!/usr/bin/env sh
set -eu
./scripts/deploy.sh
EOF

chmod +x "$HOOK_FILE"
echo "Installed $HOOK_FILE"

