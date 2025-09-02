#!/bin/bash
# Suggestion Engine Library for PM System
# Implements intelligent decision tree for workflow suggestions

# Generate prioritized suggestions based on system state
generate_prioritized_suggestions() {
    local system_state="$1"
    
    # Parse system state
    local has_epics="yes"
    echo "$system_state" | grep -q "system_state:no_epics" && has_epics="no"
    
    # Initialize suggestion arrays
    local -a suggestions=()
    local -a priorities=()
    local -a types=()
    
    # Level 1: Critical System Issues
    if [ "$has_epics" = "no" ]; then
        suggestions+=("Create your first epic to get started")
        priorities+=(100)
        types+=("setup_system")
        
        # Return early - nothing else matters without epics
        output_suggestion_data suggestions priorities types
        return 0
    fi
    
    # Level 2: Epic-Level Issues
    while IFS= read -r epic_line; do
        [[ "$epic_line" =~ ^epic_state: ]] || continue
        
        # Parse epic state: epic_state:name:status:has_worktree:progress:total:closed:in_progress:open
        local epic_name=$(echo "$epic_line" | cut -d: -f2)
        local epic_status=$(echo "$epic_line" | cut -d: -f3)
        local has_worktree=$(echo "$epic_line" | cut -d: -f4)
        local progress=$(echo "$epic_line" | cut -d: -f5)
        local total_issues=$(echo "$epic_line" | cut -d: -f6)
        local open_issues=$(echo "$epic_line" | cut -d: -f9)
        
        # Skip completed epics
        [ "$progress" -eq 100 ] && continue
        
        # Suggest epic start if no worktree and has open issues
        if [ "$has_worktree" = "no" ] && [ "$open_issues" -gt 0 ]; then
            suggestions+=("Launch parallel work environment for epic \"$epic_name\"")
            priorities+=(90)
            types+=("start_epic:$epic_name")
        fi
    done <<< "$system_state"
    
    # Level 3: Issue-Level Opportunities
    local ready_count=0
    local analysis_count=0
    local blocked_count=0
    local progress_count=0
    
    while IFS= read -r issue_line; do
        [[ "$issue_line" =~ ^issue_state: ]] || continue
        
        # Parse issue state: issue_state:id:status:classification:has_analysis:deps_met:has_progress:effort
        local issue_id=$(echo "$issue_line" | cut -d: -f2)
        local status=$(echo "$issue_line" | cut -d: -f3)
        local classification=$(echo "$issue_line" | cut -d: -f4)
        local has_analysis=$(echo "$issue_line" | cut -d: -f5)
        local deps_met=$(echo "$issue_line" | cut -d: -f6)
        local effort=$(echo "$issue_line" | cut -d: -f8)
        
        case "$classification" in
            "needs_analysis")
                suggestions+=("Break down issue \"$issue_id\" into actionable work streams")
                priorities+=(80)
                types+=("analyze_issue:$issue_id")
                ((analysis_count++))
                ;;
            "ready_to_start")
                local priority=70
                # Boost priority for quick wins
                [[ "$effort" =~ ^[0-2]h?$ ]] && priority=75
                
                suggestions+=("Start parallel work on issue \"$issue_id\" ($effort)")
                priorities+=($priority)
                types+=("start_issue:$issue_id")
                ((ready_count++))
                ;;
            "blocked_by_deps")
                ((blocked_count++))
                ;;
            "work_in_progress")
                suggestions+=("Check progress on active work for \"$issue_id\"")
                priorities+=(50)
                types+=("monitor_progress:$issue_id")
                ((progress_count++))
                ;;
            "blocked_needs_analysis")
                suggestions+=("Unblock \"$issue_id\" by analyzing dependencies first")
                priorities+=(75)
                types+=("analyze_deps:$issue_id")
                ;;
        esac
    done <<< "$system_state"
    
    # Level 4: System Maintenance and Overview
    if [ $blocked_count -gt 0 ]; then
        suggestions+=("Review $blocked_count blocked issues to resolve dependencies")
        priorities+=(60)
        types+=("review_blocked")
    fi
    
    if [ $progress_count -gt 2 ]; then
        suggestions+=("Review overall epic progress and consider consolidation")
        priorities+=(45)
        types+=("epic_overview")
    fi
    
    # Level 5: Strategic Suggestions
    if [ $ready_count -eq 0 ] && [ $analysis_count -gt 0 ]; then
        suggestions+=("Focus on analysis to unlock more work opportunities")
        priorities+=(85)
        types+=("focus_analysis")
    fi
    
    if [ $ready_count -gt 3 ]; then
        suggestions+=("Consider epic-level parallel execution for efficiency")
        priorities+=(65)
        types+=("suggest_epic_start")
    fi
    
    # Output structured suggestion data
    output_suggestion_data suggestions priorities types
}

# Calculate dynamic priority score based on context
calculate_priority_score() {
    local action_type="$1"
    local context="$2"
    local system_state="$3"
    
    local base_score=50
    local urgency_modifier=0
    local effort_modifier=0
    local dependency_modifier=0
    
    # Base scores by action type
    case "$action_type" in
        "setup_system")     base_score=100 ;;
        "start_epic")       base_score=90 ;;
        "analyze_issue")    base_score=80 ;;
        "start_issue")      base_score=70 ;;
        "analyze_deps")     base_score=75 ;;
        "review_blocked")   base_score=60 ;;
        "monitor_progress") base_score=50 ;;
        "epic_overview")    base_score=45 ;;
        "focus_analysis")   base_score=85 ;;
        "suggest_epic_start") base_score=65 ;;
    esac
    
    # Parse system summary for context
    local summary_line=$(echo "$system_state" | grep "^summary:")
    if [ -n "$summary_line" ]; then
        local total_issues=$(echo "$summary_line" | cut -d: -f3)
        local blocked_issues=$(echo "$summary_line" | cut -d: -f7)
        local ready_issues=$(echo "$summary_line" | cut -d: -f5)
        
        # Urgency modifiers
        if [ "$blocked_issues" -gt 0 ]; then
            local blocked_ratio=$((blocked_issues * 100 / total_issues))
            if [ $blocked_ratio -gt 50 ]; then
                urgency_modifier=20
            elif [ $blocked_ratio -gt 25 ]; then
                urgency_modifier=10
            fi
        fi
        
        # Scarcity modifier (boost analysis when few tasks ready)
        if [ "$ready_issues" -eq 0 ] && [[ "$action_type" = "analyze_issue" ]]; then
            urgency_modifier=$((urgency_modifier + 15))
        fi
    fi
    
    # Effort consideration from context
    if [[ "$context" =~ 1h|30m ]]; then
        effort_modifier=5  # Quick wins
    elif [[ "$context" =~ [4-9]h|1[0-9]h ]]; then
        effort_modifier=-5 # Large tasks
    fi
    
    echo $((base_score + urgency_modifier + effort_modifier + dependency_modifier))
}

# Output suggestion data in structured format
output_suggestion_data() {
    local suggs_ref="$1[@]"
    local prios_ref="$2[@]"  
    local typ_ref="$3[@]"
    local suggs=("${!suggs_ref}")
    local prios=("${!prios_ref}")
    local typ=("${!typ_ref}")
    
    # Create combined array for sorting
    local -a combined=()
    for i in "${!suggs[@]}"; do
        combined+=("${prios[$i]}:${typ[$i]}:${suggs[$i]}")
    done
    
    # Sort by priority (descending)
    IFS=$'\n' combined=($(sort -rn -t: -k1 <<< "${combined[*]}"))
    
    # Output sorted suggestions
    for item in "${combined[@]}"; do
        local priority=$(echo "$item" | cut -d: -f1)
        local type_and_target=$(echo "$item" | cut -d: -f2)
        local message=$(echo "$item" | cut -d: -f3-)
        
        # Split type and target if present
        if [[ "$type_and_target" =~ : ]]; then
            local type=$(echo "$type_and_target" | cut -d: -f1)
            local target=$(echo "$type_and_target" | cut -d: -f2)
            echo "suggestion:$priority:$type:$target:$message"
        else
            echo "suggestion:$priority:$type_and_target::$message"
        fi
    done
}

# Filter suggestions based on user preferences or limits
filter_suggestions() {
    local max_suggestions="${1:-10}"
    local priority_threshold="${2:-40}"
    
    local count=0
    while IFS= read -r line; do
        [[ "$line" =~ ^suggestion: ]] || continue
        
        local priority=$(echo "$line" | cut -d: -f2)
        [ "$priority" -lt "$priority_threshold" ] && continue
        
        echo "$line"
        ((count++))
        [ "$count" -ge "$max_suggestions" ] && break
    done
}

# Group suggestions by category for better organization
categorize_suggestions() {
    local -a priority_actions=()
    local -a ready_work=()
    local -a maintenance=()
    local -a strategic=()
    
    while IFS= read -r line; do
        [[ "$line" =~ ^suggestion: ]] || continue
        
        local priority=$(echo "$line" | cut -d: -f2)
        local type=$(echo "$line" | cut -d: -f3)
        local message=$(echo "$line" | cut -d: -f4-)
        
        # Categorize by priority and type
        if [ "$priority" -ge 90 ]; then
            priority_actions+=("$line")
        elif [ "$priority" -ge 70 ] && [[ "$type" =~ ^(start_issue|analyze_issue) ]]; then
            ready_work+=("$line")
        elif [ "$priority" -ge 45 ] && [ "$priority" -lt 70 ]; then
            maintenance+=("$line")
        else
            strategic+=("$line")
        fi
    done
    
    # Output categorized suggestions
    echo "=== PRIORITY ACTIONS ==="
    printf '%s\n' "${priority_actions[@]}"
    
    echo "=== READY TO WORK ==="
    printf '%s\n' "${ready_work[@]}"
    
    echo "=== MAINTENANCE ==="
    printf '%s\n' "${maintenance[@]}"
    
    echo "=== STRATEGIC ==="
    printf '%s\n' "${strategic[@]}"
}

# Generate contextual tips based on system state
generate_contextual_tips() {
    local system_state="$1"
    
    # Parse summary data
    local summary_line=$(echo "$system_state" | grep "^summary:")
    [ -z "$summary_line" ] && return 0
    
    local total_issues=$(echo "$summary_line" | cut -d: -f3)
    local ready_issues=$(echo "$summary_line" | cut -d: -f5)
    local analysis_needed=$(echo "$summary_line" | cut -d: -f7)
    local blocked_issues=$(echo "$summary_line" | cut -d: -f9)
    local in_progress=$(echo "$summary_line" | cut -d: -f11)
    
    echo "=== CONTEXTUAL TIPS ==="
    
    # No work available
    if [ "$ready_issues" -eq 0 ] && [ "$analysis_needed" -eq 0 ]; then
        echo "tip:No work currently available. Consider creating new issues or reviewing blocked items."
        return 0
    fi
    
    # Analysis bottleneck
    if [ "$analysis_needed" -gt "$ready_issues" ] && [ "$analysis_needed" -gt 2 ]; then
        echo "tip:Analysis bottleneck detected. Focus on breaking down issues to unlock more work."
    fi
    
    # Dependency issues
    if [ "$blocked_issues" -gt 0 ]; then
        local blocked_ratio=$((blocked_issues * 100 / total_issues))
        if [ $blocked_ratio -gt 30 ]; then
            echo "tip:High dependency blocking ($blocked_ratio%). Consider reviewing task dependencies."
        fi
    fi
    
    # Work in progress management
    if [ "$in_progress" -gt 3 ]; then
        echo "tip:Multiple work streams active. Consider consolidating or completing current work first."
    fi
    
    # Parallel execution opportunity
    if [ "$ready_issues" -gt 2 ] && [ "$in_progress" -eq 0 ]; then
        echo "tip:Multiple issues ready. Consider epic-level parallel execution for efficiency."
    fi
    
    # Quick wins available
    local quick_wins=$(echo "$system_state" | grep "issue_state:" | grep -c "1h\|30m\|2h")
    if [ "$quick_wins" -gt 0 ]; then
        echo "tip:$quick_wins quick win(s) available. Consider tackling these first for momentum."
    fi
}