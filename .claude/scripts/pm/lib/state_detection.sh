#!/bin/bash
# State Detection Library for PM System
# Provides comprehensive system state analysis for intelligent workflow suggestions

# Detect epic-level state information
detect_epic_states() {
    local epic_dir="$1"
    
    # Validate input
    [ -d "$epic_dir" ] || {
        echo "error:invalid_epic_dir:$epic_dir"
        return 1
    }
    
    # Get basic epic information
    local epic_name=$(basename "$epic_dir")
    local epic_file="$epic_dir/epic.md"
    
    # Check if epic file exists
    if [ ! -f "$epic_file" ]; then
        echo "error:no_epic_file:$epic_name"
        return 1
    fi
    
    # Get epic status from frontmatter
    local epic_status=$(grep "^status:" "$epic_file" 2>/dev/null | head -1 | sed 's/^status: *//' || echo "unknown")
    
    # Check worktree state
    local has_worktree="no"
    if git worktree list 2>/dev/null | grep -q "epic/$epic_name\|epic-$epic_name"; then
        has_worktree="yes"
    fi
    
    # Calculate progress
    local total_issues=0
    local closed_issues=0
    local in_progress_issues=0
    local open_issues=0
    
    # Count issues in both flat and nested structures
    for issue_file in "$epic_dir"*.md "$epic_dir"issues/*.md; do
        [ -f "$issue_file" ] || continue
        
        # Skip analysis files and epic file
        local basename=$(basename "$issue_file")
        [[ "$basename" =~ -analysis\.md$ ]] && continue
        [[ "$basename" = "epic.md" ]] && continue
        
        ((total_issues++))
        
        # Get issue status
        local status=$(grep "^status:" "$issue_file" 2>/dev/null | head -1 | sed 's/^status: *//' || echo "open")
        
        case "$status" in
            "closed"|"completed"|"done") ((closed_issues++)) ;;
            "in_progress"|"in-progress") ((in_progress_issues++)) ;;
            *) ((open_issues++)) ;;
        esac
    done
    
    # Calculate progress percentage
    local progress=0
    if [ "$total_issues" -gt 0 ]; then
        progress=$((closed_issues * 100 / total_issues))
    fi
    
    # Output structured data
    echo "epic_state:$epic_name:$epic_status:$has_worktree:$progress:$total_issues:$closed_issues:$in_progress_issues:$open_issues"
}

# Classify individual issue state
classify_issue_state() {
    local issue_file="$1"
    
    # Validate input
    [ -f "$issue_file" ] || {
        echo "error:invalid_issue_file:$issue_file"
        return 1
    }
    
    local issue_id=$(basename "$issue_file" .md)
    local issue_dir=$(dirname "$issue_file")
    
    # Get issue status
    local status=$(grep "^status:" "$issue_file" 2>/dev/null | head -1 | sed 's/^status: *//' || echo "open")
    
    # Check for analysis file (co-located)
    local analysis_file="${issue_file%.md}-analysis.md"
    local has_analysis="no"
    [ -f "$analysis_file" ] && has_analysis="yes"
    
    # Check for dependencies
    local has_dependencies="no"
    local dependencies_met="yes"
    
    if grep -q "^depends_on:" "$issue_file" 2>/dev/null; then
        has_dependencies="yes"
        dependencies_met=$(check_issue_dependencies "$issue_file")
    fi
    
    # Check for progress tracking
    local has_progress="no"
    local progress_dir
    
    # Look for updates directory in epic structure
    local epic_dir=$(dirname "$issue_dir" 2>/dev/null)
    if [[ "$issue_dir" =~ /issues$ ]]; then
        epic_dir="$issue_dir/.."
    fi
    
    progress_dir="$epic_dir/updates/$issue_id"
    [ -d "$progress_dir" ] && has_progress="yes"
    
    # Get effort estimate
    local effort=$(grep "^effort:" "$issue_file" 2>/dev/null | head -1 | sed 's/^effort: *//' || echo "unknown")
    
    # Classify state based on multiple factors
    local classification
    case "$status:$has_analysis:$dependencies_met:$has_progress" in
        "open:no:yes:no")       classification="needs_analysis" ;;
        "open:yes:yes:no")      classification="ready_to_start" ;;
        "open:yes:no:no")       classification="blocked_by_deps" ;;
        "open:no:no:no")        classification="blocked_needs_analysis" ;;
        "backlog:no:yes:no")    classification="needs_analysis" ;;
        "backlog:yes:yes:no")   classification="ready_to_start" ;;
        "backlog:yes:no:no")    classification="blocked_by_deps" ;;
        "backlog:no:no:no")     classification="blocked_needs_analysis" ;;
        "in_progress:yes:yes:yes") classification="work_in_progress" ;;
        "in_progress:yes:yes:no")  classification="work_in_progress_no_tracking" ;;
        "in_progress:*:*:*")    classification="work_in_progress" ;;
        "closed:*:*:*"|"completed:*:*:*"|"done:*:*:*") classification="completed" ;;
        *)                      classification="needs_attention" ;;
    esac
    
    # Output structured data
    echo "issue_state:$issue_id:$status:$classification:$has_analysis:$dependencies_met:$has_progress:$effort"
}

# Check if issue dependencies are satisfied
check_issue_dependencies() {
    local issue_file="$1"
    local epic_dir=$(dirname "$(dirname "$issue_file")" 2>/dev/null)
    
    # Handle nested issues directory structure
    if [[ "$(dirname "$issue_file")" =~ /issues$ ]]; then
        epic_dir=$(dirname "$(dirname "$issue_file")")
    else
        epic_dir=$(dirname "$issue_file")
    fi
    
    # Extract dependencies
    local dependencies=$(grep "^depends_on:" "$issue_file" 2>/dev/null | sed 's/^depends_on: *//' | tr ',' '\n' | sed 's/^ *//;s/ *$//')
    
    # If no dependencies found, return met
    [ -z "$dependencies" ] && echo "yes" && return 0
    
    # Check each dependency
    while IFS= read -r dep_id; do
        [ -z "$dep_id" ] && continue
        
        # Look for dependency file in both flat and nested structures
        local dep_file=""
        if [ -f "$epic_dir/$dep_id.md" ]; then
            dep_file="$epic_dir/$dep_id.md"
        elif [ -f "$epic_dir/issues/$dep_id.md" ]; then
            dep_file="$epic_dir/issues/$dep_id.md"
        else
            echo "no" # Dependency file not found
            return 0
        fi
        
        # Check if dependency is completed
        local dep_status=$(grep "^status:" "$dep_file" 2>/dev/null | head -1 | sed 's/^status: *//' || echo "open")
        case "$dep_status" in
            "closed"|"completed"|"done") continue ;;
            *) echo "no" && return 0 ;;
        esac
    done <<< "$dependencies"
    
    echo "yes"
}

# Check if system has any epics
has_any_epics() {
    [ -d ".claude/epics" ] || return 1
    
    local epic_count=0
    for epic_dir in .claude/epics/*/; do
        [ -d "$epic_dir" ] || continue
        [ -f "$epic_dir/epic.md" ] || continue
        ((epic_count++))
    done
    
    [ "$epic_count" -gt 0 ]
}

# Count issues by state across all epics
count_issues_by_state() {
    local state_filter="$1" # optional filter: ready_to_start, needs_analysis, etc.
    local count=0
    
    for epic_dir in .claude/epics/*/; do
        [ -d "$epic_dir" ] || continue
        
        for issue_file in "$epic_dir"*.md "$epic_dir"issues/*.md; do
            [ -f "$issue_file" ] || continue
            
            # Skip analysis files and epic file
            local basename=$(basename "$issue_file")
            [[ "$basename" =~ -analysis\.md$ ]] && continue
            [[ "$basename" = "epic.md" ]] && continue
            
            # Get issue classification
            local issue_state=$(classify_issue_state "$issue_file")
            local classification=$(echo "$issue_state" | cut -d: -f4)
            
            # Count based on filter
            if [ -z "$state_filter" ] || [ "$classification" = "$state_filter" ]; then
                ((count++))
            fi
        done
    done
    
    echo "$count"
}

# Get all issue states for analysis
collect_all_issue_states() {
    for epic_dir in .claude/epics/*/; do
        [ -d "$epic_dir" ] || continue
        
        for issue_file in "$epic_dir"*.md "$epic_dir"issues/*.md; do
            [ -f "$issue_file" ] || continue
            
            # Skip analysis files and epic file
            local basename=$(basename "$issue_file")
            [[ "$basename" =~ -analysis\.md$ ]] && continue
            [[ "$basename" = "epic.md" ]] && continue
            
            # Output issue state
            classify_issue_state "$issue_file"
        done
    done
}

# Get all epic states for analysis
collect_all_epic_states() {
    for epic_dir in .claude/epics/*/; do
        [ -d "$epic_dir" ] || continue
        detect_epic_states "$epic_dir"
    done
}

# Collect comprehensive system state
collect_system_state() {
    echo "=== SYSTEM STATE COLLECTION ==="
    
    # Check for epics directory
    if ! has_any_epics; then
        echo "system_state:no_epics"
        return 0
    fi
    
    echo "=== EPIC STATES ==="
    collect_all_epic_states
    
    echo "=== ISSUE STATES ==="
    collect_all_issue_states
    
    echo "=== STATE SUMMARY ==="
    local total_issues=$(count_issues_by_state)
    local ready_issues=$(count_issues_by_state "ready_to_start")
    local analysis_needed=$(count_issues_by_state "needs_analysis")
    local blocked_issues=$(count_issues_by_state "blocked_by_deps")
    local in_progress=$(count_issues_by_state "work_in_progress")
    local completed=$(count_issues_by_state "completed")
    
    echo "summary:total:$total_issues:ready:$ready_issues:analysis_needed:$analysis_needed:blocked:$blocked_issues:in_progress:$in_progress:completed:$completed"
}