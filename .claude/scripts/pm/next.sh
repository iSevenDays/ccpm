#!/bin/bash
# Intelligent Workflow Assistant for PM System
# Transforms passive task listing into active workflow guidance

# Get script directory for library imports
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source required libraries
source "$SCRIPT_DIR/lib/state_detection.sh"
source "$SCRIPT_DIR/lib/suggestion_engine.sh" 
source "$SCRIPT_DIR/lib/command_generator.sh"
source "$SCRIPT_DIR/lib/output_formatter.sh"

# Show help information
show_help() {
    cat << 'EOF'
🤖 Intelligent PM Workflow Assistant

USAGE:
  /pm:next [OPTIONS]

OPTIONS:
  --simple     Use simple task list format (legacy mode)
  --debug      Show detailed system state analysis
  --max=N      Limit suggestions to N items (default: 10)
  --help, -h   Show this help message

EXAMPLES:
  /pm:next              # Show intelligent workflow suggestions
  /pm:next --simple     # Show basic task list only
  /pm:next --debug      # Debug system state detection
  /pm:next --max=5      # Show top 5 suggestions only

The workflow assistant analyzes your PM system state and provides
intelligent, prioritized suggestions with copy-pasteable commands
to guide your next actions.
EOF
}

# Parse command line arguments
SIMPLE_MODE="no"
DEBUG_MODE="no"
MAX_SUGGESTIONS=10

while [[ $# -gt 0 ]]; do
    case $1 in
        --simple)
            SIMPLE_MODE="yes"
            shift
            ;;
        --debug)
            DEBUG_MODE="yes"
            shift
            ;;
        --max=*)
            MAX_SUGGESTIONS="${1#*=}"
            shift
            ;;
        --help|-h)
            show_help
            exit 0
            ;;
        *)
            echo "Unknown option: $1" >&2
            echo "Use --help for usage information" >&2
            exit 1
            ;;
    esac
done

# Main workflow assistant logic
main() {
    echo "🔄 Analyzing workflow state..."
    
    # Validate environment
    if ! validate_environment; then
        exit 1
    fi
    
    # Collect comprehensive system state
    local system_state
    if ! system_state=$(collect_system_state 2>/dev/null); then
        format_error_output "analysis_error" "Failed to collect system state"
        exit 1
    fi
    
    # Simple mode fallback
    if [ "$SIMPLE_MODE" = "yes" ]; then
        echo ""
        format_simple_status "$system_state"
        exit 0
    fi
    
    # Generate intelligent suggestions
    local suggestions
    if ! suggestions=$(generate_prioritized_suggestions "$system_state"); then
        format_error_output "suggestion_error" "Failed to generate suggestions"
        exit 1
    fi
    
    # Filter suggestions based on limits
    suggestions=$(echo "$suggestions" | filter_suggestions "$MAX_SUGGESTIONS")
    
    # Clear analysis message and display results
    echo -ne "\r\033[K"  # Clear current line
    echo ""
    
    # Debug mode output
    if [ "$DEBUG_MODE" = "yes" ]; then
        format_debug_output "$system_state" "$suggestions"
        echo ""
        echo "=== FORMATTED OUTPUT ==="
    fi
    
    # Format and display intelligent output
    format_intelligent_output "$suggestions" "$system_state" "$DEBUG_MODE"
}

# Validate PM system environment
validate_environment() {
    # Check for .claude directory
    if [ ! -d ".claude" ]; then
        format_error_output "no_claude_dir" "No .claude directory found"
        echo ""
        echo "💡 Quick Fix:"
        echo "mkdir -p .claude/epics"
        echo "/pm:prd-new my-first-epic"
        return 1
    fi
    
    # Check for epics directory
    if [ ! -d ".claude/epics" ]; then
        mkdir -p .claude/epics 2>/dev/null || {
            format_error_output "permission_error" "Cannot create .claude/epics directory"
            return 1
        }
    fi
    
    # Check git repository (optional, but helpful)
    if ! git rev-parse --git-dir >/dev/null 2>&1; then
        echo "⚠️  Not in a git repository - some features may be limited"
        echo ""
    fi
    
    return 0
}

# Error handling for library loading
handle_library_error() {
    local library="$1"
    cat << EOF
❌ Failed to load PM library: $library

This suggests the PM system installation is incomplete.

🔧 Troubleshooting:
1. Verify library exists: ls -la $SCRIPT_DIR/lib/
2. Check permissions: chmod +x $SCRIPT_DIR/lib/*.sh
3. Reinstall PM system if needed

Run with --debug for more information.
EOF
    exit 1
}

# Verify libraries are available
if [ ! -f "$SCRIPT_DIR/lib/state_detection.sh" ]; then
    handle_library_error "state_detection.sh"
fi

if [ ! -f "$SCRIPT_DIR/lib/suggestion_engine.sh" ]; then
    handle_library_error "suggestion_engine.sh"
fi

if [ ! -f "$SCRIPT_DIR/lib/command_generator.sh" ]; then
    handle_library_error "command_generator.sh"
fi

if [ ! -f "$SCRIPT_DIR/lib/output_formatter.sh" ]; then
    handle_library_error "output_formatter.sh"
fi

# Handle script execution errors gracefully 
# set -eE
# trap 'handle_execution_error $? $LINENO' ERR

handle_execution_error() {
    local exit_code="$1"
    local line_number="$2"
    
    echo ""
    echo "❌ Workflow Assistant Error (Line $line_number)"
    echo "=============================================="
    
    case $exit_code in
        1)
            echo "General error occurred during execution"
            ;;
        2)
            echo "Invalid command line arguments"
            ;;
        126)
            echo "Permission denied - check script permissions"
            ;;
        127)
            echo "Command not found - check library dependencies"
            ;;
        *)
            echo "Unexpected error (exit code: $exit_code)"
            ;;
    esac
    
    echo ""
    echo "🔧 Recovery Options:"
    echo "• Try: /pm:next --simple (fallback mode)"
    echo "• Debug: /pm:next --debug (detailed analysis)"
    echo "• Reset: rm -rf .claude/epics/.cache (clear cache)"
    
    exit $exit_code
}

# Execute main logic
main "$@"