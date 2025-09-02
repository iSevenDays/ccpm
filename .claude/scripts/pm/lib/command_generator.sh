#!/bin/bash
# Command Generator Library for PM System
# Generates context-aware, copy-pasteable commands for workflow suggestions

# Generate specific command for a suggestion
generate_command_for_suggestion() {
    local suggestion_line="$1"
    local system_state="$2"
    
    # Parse suggestion: suggestion:priority:type:target:message  
    # But debug shows format: suggestion:90:start_epic::installation-outcome-idea-b:message
    local priority=$(echo "$suggestion_line" | cut -d: -f2)
    local action_type=$(echo "$suggestion_line" | cut -d: -f3)
    local empty_field=$(echo "$suggestion_line" | cut -d: -f4)
    local target=$(echo "$suggestion_line" | cut -d: -f5)
    local message=$(echo "$suggestion_line" | cut -d: -f6-)
    
    # Handle case where target is in different position
    if [ -z "$target" ] || [ -z "$message" ]; then
        # Fallback - try alternative parsing
        target=$(echo "$suggestion_line" | cut -d: -f4)
        message=$(echo "$suggestion_line" | cut -d: -f5-)
        
        if [ -z "$target" ]; then
            target=""
            message=$(echo "$suggestion_line" | cut -d: -f4-)
        fi
    fi
    
    # Generate command based on action type
    case "$action_type" in
        "setup_system")
            generate_setup_commands
            ;;
        "start_epic")
            if [ -n "$target" ]; then
                generate_epic_start_command "$target" "$system_state"
            else
                echo "# Epic name not found - check system state"
                echo "/pm:epic-start <epic-name>"
            fi
            ;;
        "analyze_issue")
            generate_issue_analyze_command "$target"
            ;;
        "start_issue")
            generate_issue_start_command "$target" "$system_state"
            ;;
        "monitor_progress")
            generate_progress_monitor_command "$target"
            ;;
        "review_blocked")
            generate_blocked_review_commands
            ;;
        "epic_overview")
            generate_epic_overview_commands "$system_state"
            ;;
        "analyze_deps")
            generate_dependency_analysis_command "$target"
            ;;
        "focus_analysis"|"suggest_epic_start")
            generate_strategic_commands "$action_type" "$system_state"
            ;;
        *)
            echo "# No specific command available for: $message"
            ;;
    esac
}

# Generate system setup commands
generate_setup_commands() {
    cat << 'EOF'
# Create your first epic:
/pm:prd-new <epic-name>

# Or parse existing requirements:
/pm:prd-parse <epic-name>

# Then view available work:
/pm:next
EOF
}

# Generate epic start command with prerequisites check
generate_epic_start_command() {
    local epic_name="$1"
    local system_state="$2"
    
    # Check if epic has analyzed issues
    local has_analyzed_issues="no"
    local sample_unanalyzed=""
    
    while IFS= read -r issue_line; do
        [[ "$issue_line" =~ ^issue_state: ]] || continue
        
        local issue_id=$(echo "$issue_line" | cut -d: -f2)
        local has_analysis=$(echo "$issue_line" | cut -d: -f5)
        local classification=$(echo "$issue_line" | cut -d: -f4)
        
        if [ "$has_analysis" = "yes" ]; then
            has_analyzed_issues="yes"
        elif [ "$classification" = "needs_analysis" ] && [ -z "$sample_unanalyzed" ]; then
            sample_unanalyzed="$issue_id"
        fi
    done <<< "$system_state"
    
    if [ "$has_analyzed_issues" = "no" ] && [ -n "$sample_unanalyzed" ]; then
        cat << EOF
# First analyze issues for parallel execution:
/pm:issue-analyze $sample_unanalyzed

# Then start the epic worktree:
/pm:epic-start $epic_name
EOF
    else
        echo "/pm:epic-start $epic_name"
    fi
}

# Generate issue analysis command
generate_issue_analyze_command() {
    local issue_id="$1"
    echo "/pm:issue-analyze $issue_id"
}

# Generate issue start command with epic context
generate_issue_start_command() {
    local issue_id="$1"
    local system_state="$2"
    
    # Find which epic this issue belongs to and check worktree status
    local epic_name=""
    local has_worktree="unknown"
    
    # Look for epic context in file paths or state
    while IFS= read -r epic_line; do
        [[ "$epic_line" =~ ^epic_state: ]] || continue
        
        local candidate_epic=$(echo "$epic_line" | cut -d: -f2)
        local worktree_status=$(echo "$epic_line" | cut -d: -f4)
        
        # Check if this epic contains our issue (simplified check)
        # In practice, we'd need to trace back from issue file path
        if [ -z "$epic_name" ]; then
            epic_name="$candidate_epic"
            has_worktree="$worktree_status"
        fi
    done <<< "$system_state"
    
    if [ "$has_worktree" = "no" ] && [ -n "$epic_name" ]; then
        cat << EOF
# Epic worktree needed for parallel execution:
/pm:epic-start $epic_name

# Or start single-issue work:
/pm:issue-start $issue_id
EOF
    else
        echo "/pm:issue-start $issue_id"
    fi
}

# Generate progress monitoring command
generate_progress_monitor_command() {
    local issue_id="$1"
    cat << EOF
# Check current progress:
/pm:issue-sync $issue_id

# Or view epic-level status:
/pm:epic-status <epic-name>
EOF
}

# Generate blocked review commands
generate_blocked_review_commands() {
    cat << 'EOF'
# Review blocked issues:
/pm:blocked

# Or manually check dependencies:
grep -r "depends_on:" .claude/epics/*/
EOF
}

# Generate epic overview commands
generate_epic_overview_commands() {
    local system_state="$1"
    
    # List active epics
    echo "# Check epic status:"
    while IFS= read -r epic_line; do
        [[ "$epic_line" =~ ^epic_state: ]] || continue
        
        local epic_name=$(echo "$epic_line" | cut -d: -f2)
        local progress=$(echo "$epic_line" | cut -d: -f5)
        
        [ "$progress" -eq 100 ] && continue
        echo "/pm:epic-status $epic_name"
    done <<< "$system_state"
}

# Generate dependency analysis command
generate_dependency_analysis_command() {
    local issue_id="$1"
    cat << EOF
# Analyze dependencies for issue:
/pm:issue-analyze $issue_id

# Then check what's blocking:
/pm:blocked
EOF
}

# Generate strategic commands
generate_strategic_commands() {
    local strategy="$1"
    local system_state="$2"
    
    case "$strategy" in
        "focus_analysis")
            cat << 'EOF'
# Focus on analysis to unlock work:
find .claude/epics -name "*.md" ! -name "*-analysis.md" ! -name "epic.md" -exec basename {} .md \; | head -3 | while read issue; do
  echo "/pm:issue-analyze $issue"
done
EOF
            ;;
        "suggest_epic_start")
            echo "# Consider epic-level parallel execution:"
            while IFS= read -r epic_line; do
                [[ "$epic_line" =~ ^epic_state: ]] || continue
                
                local epic_name=$(echo "$epic_line" | cut -d: -f2)
                local has_worktree=$(echo "$epic_line" | cut -d: -f4)
                local open_issues=$(echo "$epic_line" | cut -d: -f9)
                
                [ "$has_worktree" = "yes" ] && continue
                [ "$open_issues" -le 1 ] && continue
                
                echo "/pm:epic-start $epic_name"
            done <<< "$system_state"
            ;;
    esac
}

# Generate command with explanation
generate_command_with_context() {
    local suggestion_line="$1"
    local system_state="$2"
    local show_explanation="${3:-yes}"
    
    local message=$(echo "$suggestion_line" | cut -d: -f4-)
    local commands=$(generate_command_for_suggestion "$suggestion_line" "$system_state")
    
    if [ "$show_explanation" = "yes" ]; then
        echo "# $message"
        echo "$commands"
    else
        echo "$commands"
    fi
}

# Generate quick command reference
generate_quick_reference() {
    cat << 'EOF'
# PM System Quick Reference:
/pm:next              # Show this intelligent workflow guide
/pm:prd-new <name>     # Create new epic from requirements
/pm:prd-parse <name>   # Parse existing epic requirements
/pm:epic-start <name>  # Launch parallel work environment
/pm:issue-analyze <id> # Break down issue into work streams
/pm:issue-start <id>   # Start work on specific issue
/pm:issue-sync <id>    # Update progress and status
/pm:blocked           # Review blocked/dependent issues
/pm:epic-status <name> # Check epic progress and health
EOF
}

# Generate contextual help based on current situation
generate_contextual_help() {
    local system_state="$1"
    
    # Check if system has epics
    if echo "$system_state" | grep -q "system_state:no_epics"; then
        cat << 'EOF'
# Getting Started:
# 1. Create your first epic from requirements:
/pm:prd-new my-first-epic

# 2. Or parse existing requirements document:
/pm:prd-parse existing-requirements

# 3. Check what work is available:
/pm:next
EOF
        return 0
    fi
    
    # Parse system summary for contextual help
    local summary_line=$(echo "$system_state" | grep "^summary:")
    [ -z "$summary_line" ] && return 0
    
    local ready_issues=$(echo "$summary_line" | cut -d: -f5)
    local analysis_needed=$(echo "$summary_line" | cut -d: -f7)
    local blocked_issues=$(echo "$summary_line" | cut -d: -f9)
    local in_progress=$(echo "$summary_line" | cut -d: -f11)
    
    echo "# Current Situation Analysis:"
    
    if [ "$ready_issues" -gt 0 ]; then
        echo "# You have $ready_issues issues ready to start"
        echo "# Use: /pm:issue-start <issue-id> or /pm:epic-start <epic-name>"
    fi
    
    if [ "$analysis_needed" -gt 0 ]; then
        echo "# $analysis_needed issues need analysis before starting"
        echo "# Use: /pm:issue-analyze <issue-id>"
    fi
    
    if [ "$blocked_issues" -gt 0 ]; then
        echo "# $blocked_issues issues are blocked by dependencies"
        echo "# Use: /pm:blocked to review and resolve"
    fi
    
    if [ "$in_progress" -gt 0 ]; then
        echo "# $in_progress work streams are active"
        echo "# Use: /pm:issue-sync <issue-id> to check progress"
    fi
}

# Extract issue ID from file path or name
extract_issue_id() {
    local issue_reference="$1"
    
    # If it's already just an ID, return as-is
    if [[ "$issue_reference" =~ ^[a-z0-9-]+$ ]]; then
        echo "$issue_reference"
        return 0
    fi
    
    # Extract from file path
    local basename=$(basename "$issue_reference" .md 2>/dev/null || echo "$issue_reference")
    
    # Remove -analysis suffix if present
    basename=${basename%-analysis}
    
    echo "$basename"
}

# Get epic name for an issue (simplified version)
get_epic_for_issue() {
    local issue_id="$1"
    
    # Look for issue file in epic directories
    for epic_dir in .claude/epics/*/; do
        [ -d "$epic_dir" ] || continue
        
        # Check both flat and nested structures
        if [ -f "$epic_dir$issue_id.md" ] || [ -f "$epic_dir/issues/$issue_id.md" ]; then
            basename "$epic_dir"
            return 0
        fi
    done
    
    echo "unknown-epic"
}