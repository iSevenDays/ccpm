#!/bin/bash

echo "Initializing..."
echo ""
echo ""

echo " ██████╗ ██████╗██████╗ ███╗   ███╗"
echo "██╔════╝██╔════╝██╔══██╗████╗ ████║"
echo "██║     ██║     ██████╔╝██╔████╔██║"
echo "╚██████╗╚██████╗██║     ██║ ╚═╝ ██║"
echo " ╚═════╝ ╚═════╝╚═╝     ╚═╝     ╚═╝"

echo "┌─────────────────────────────────┐"
echo "│ Claude Code Project Management  │"
echo "│ by https://x.com/aroussi        │"
echo "└─────────────────────────────────┘"
echo "https://github.com/automazeio/ccpm"
echo ""
echo ""

echo "🚀 Initializing Claude Code PM System"
echo "======================================"
echo ""

# Check for required tools
echo "🔍 Checking dependencies..."

## Check gh CLI
#if command -v gh &> /dev/null; then
#  echo "  ✅ GitHub CLI (gh) installed"
#else
#  echo "  ❌ GitHub CLI (gh) not found"
#  echo ""
#  echo "  Installing gh..."
#  if command -v brew &> /dev/null; then
#    brew install gh
#  elif command -v apt-get &> /dev/null; then
#    sudo apt-get update && sudo apt-get install gh
#  else
#    echo "  Please install GitHub CLI manually: https://cli.github.com/"
#    exit 1
#  fi
#fi

## Check gh auth status
#echo ""
#echo "🔐 Checking GitHub authentication..."
#if gh auth status &> /dev/null; then
#  echo "  ✅ GitHub authenticated"
#else
#  echo "  ⚠️ GitHub not authenticated"
#  echo "  Running: gh auth login"
#  gh auth login
#fi

## Check for gh-sub-issue extension
#echo ""
#echo "📦 Checking gh extensions..."
#if gh extension list | grep -q "yahsan2/gh-sub-issue"; then
#  echo "  ✅ gh-sub-issue extension installed"
#else
#  echo "  📥 Installing gh-sub-issue extension..."
#  gh extension install yahsan2/gh-sub-issue
#fi

# Create directory structure
echo ""
echo "📁 Creating directory structure..."
mkdir -p .claude/prds
mkdir -p .claude/epics
mkdir -p .claude/rules
mkdir -p .claude/agents
mkdir -p .claude/scripts/pm
echo "  ✅ Directories created"

# Copy scripts if in main repo
if [ -d "scripts/pm" ] && [ ! "$(pwd)" = *"/.claude"* ]; then
  echo ""
  echo "📝 Copying PM scripts..."
  cp -r scripts/pm/* .claude/scripts/pm/
  chmod +x .claude/scripts/pm/*.sh
  echo "  ✅ Scripts copied and made executable"
fi

# Check for git
echo ""
echo "🔗 Checking Git configuration..."
if git rev-parse --git-dir > /dev/null 2>&1; then
  echo "  ✅ Git repository detected"

  # Check remote
  if git remote -v | grep -q origin; then
    remote_url=$(git remote get-url origin)
    echo "  ✅ Remote configured: $remote_url"
  else
    echo "  ⚠️ No remote configured"
    echo "  Add with: git remote add origin <url>"
  fi

  # Configure local git exclude for .claude directory
  echo ""
  echo "🔒 Configuring local git ignore..."
  if ! grep -q "^\.claude/" .git/info/exclude 2>/dev/null; then
    mkdir -p .git/info
    echo ".claude/" >> .git/info/exclude
    echo "  ✅ Added .claude/ to local git exclude"
    echo "  📝 PM files will not be committed to repository"
  else
    echo "  ✅ .claude/ already excluded from git"
  fi

  # Optional: Add pre-commit hook for extra protection
  if [ ! -f ".git/hooks/pre-commit" ]; then
    echo ""
    echo "🛡️ Installing commit protection..."
    cat > .git/hooks/pre-commit << 'EOF'
#!/bin/sh
if git diff --cached --name-only | grep -q "^\.claude/"; then
  echo "🚫 ERROR: .claude/ files cannot be committed to repository"
  echo "   This is a local-only project management system"
  exit 1
fi
EOF
    chmod +x .git/hooks/pre-commit
    echo "  ✅ Pre-commit hook installed"
    echo "  🔐 Extra protection against accidental commits"
  else
    echo "  ⚠️ Pre-commit hook already exists - not overwriting"
  fi
else
  echo "  ⚠️ Not a git repository"
  echo "  Initialize with: git init"
fi

# Create CLAUDE.md if it doesn't exist
if [ ! -f "CLAUDE.md" ]; then
  echo ""
  echo "📄 Creating CLAUDE.md..."
  cat > CLAUDE.md << 'EOF'
# CLAUDE.md

> Think carefully and implement the most concise solution that changes as little code as possible.

## Project-Specific Instructions

Add your project-specific instructions here.

## Testing

Always run tests before committing:
- `npm test` or equivalent for your stack

## Code Style

Follow existing patterns in the codebase.
EOF
  echo "  ✅ CLAUDE.md created"
fi

# Summary
echo ""
echo "✅ Initialization Complete!"
echo "=========================="
echo ""
#echo "📊 System Status:"
#gh --version | head -1
#echo "  Extensions: $(gh extension list | wc -l) installed"
#echo "  Auth: $(gh auth status 2>&1 | grep -o 'Logged in to [^ ]*' || echo 'Not authenticated')"
#echo ""
echo "🎯 Next Steps:"
echo "  1. Create your first PRD: /pm:prd-new <feature-name>"
echo "  2. View help: /pm:help"
echo "  3. Check status: /pm:status"
echo ""
echo "📚 Documentation: README.md"

exit 0
