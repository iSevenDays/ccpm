#!/bin/bash
# Output Formatter Library for PM System
# Formats intelligent workflow suggestions in user-friendly displays

# Format complete intelligent output
format_intelligent_output() {
    local suggestions="$1"
    local system_state="$2"
    local show_debug="${3:-no}"
    
    # Show debug info if requested
    if [ "$show_debug" = "yes" ]; then
        echo "🔍 DEBUG: System State Analysis"
        echo "================================"
        echo "$system_state" | head -20
        echo ""
    fi
    
    # Check for empty system
    if echo "$system_state" | grep -q "system_state:no_epics"; then
        format_empty_system_output
        return 0
    fi
    
    # Generate system status overview
    format_system_status "$system_state"
    echo ""
    
    # Process and categorize suggestions
    local categorized_suggestions=$(echo "$suggestions" | categorize_suggestions)
    
    # Format priority actions
    format_priority_actions "$categorized_suggestions" "$system_state"
    
    # Format ready work
    format_ready_work "$categorized_suggestions" "$system_state"
    
    # Format maintenance items
    format_maintenance "$categorized_suggestions" "$system_state"
    
    # Generate contextual tips
    format_contextual_tips "$system_state"
    
    # Show quick reference if helpful
    format_quick_help "$system_state"
}

# Format output for empty system
format_empty_system_output() {
    cat << 'EOF'
🚀 Welcome to PM System
=======================

No epics found. Let's get you started!

🎯 NEXT STEPS:
==============
1️⃣ Create your first epic from requirements:
   /pm:prd-new <epic-name>

2️⃣ Or parse existing requirements document:  
   /pm:prd-parse <epic-name>

3️⃣ Then check available work:
   /pm:next

💡 Quick Start Guide:
==================
• PRDs (Product Requirements) define epics and goals
• Issues break down work into manageable tasks  
• Analysis files plan parallel execution streams
• The PM system tracks progress automatically

🔗 Need help? Run any command for usage details.
EOF
}

# Format system status overview
format_system_status() {
    local system_state="$1"
    
    # Parse summary data
    local summary_line=$(echo "$system_state" | grep "^summary:")
    if [ -z "$summary_line" ]; then
        echo "📊 System Status: Initializing..."
        return 0
    fi
    
    local total_issues=$(echo "$summary_line" | cut -d: -f3)
    local ready_issues=$(echo "$summary_line" | cut -d: -f5)
    local analysis_needed=$(echo "$summary_line" | cut -d: -f7)
    local blocked_issues=$(echo "$summary_line" | cut -d: -f9)
    local in_progress=$(echo "$summary_line" | cut -d: -f11)
    local completed=$(echo "$summary_line" | cut -d: -f13)
    
    # Count active epics
    local active_epics=0
    local total_epics=0
    while IFS= read -r epic_line; do
        [[ "$epic_line" =~ ^epic_state: ]] || continue
        ((total_epics++))
        
        local progress=$(echo "$epic_line" | cut -d: -f5)
        [ "$progress" -lt 100 ] && ((active_epics++))
    done <<< "$system_state"
    
    echo "📊 System Status"
    echo "================"
    printf "Epics: %d active" "$active_epics"
    [ "$total_epics" -gt "$active_epics" ] && printf " (%d completed)" $((total_epics - active_epics))
    echo ""
    
    if [ "$total_issues" -gt 0 ]; then
        printf "Issues: %d total" "$total_issues"
        [ "$completed" -gt 0 ] && printf " • %d completed ✅" "$completed"
        [ "$in_progress" -gt 0 ] && printf " • %d in progress 🔄" "$in_progress"
        [ "$ready_issues" -gt 0 ] && printf " • %d ready ⚡" "$ready_issues"
        echo ""
        
        if [ "$analysis_needed" -gt 0 ] || [ "$blocked_issues" -gt 0 ]; then
            printf "Attention needed:"
            [ "$analysis_needed" -gt 0 ] && printf " %d need analysis 🔍" "$analysis_needed"
            [ "$blocked_issues" -gt 0 ] && printf " %d blocked 🚧" "$blocked_issues"
            echo ""
        fi
    fi
}

# Format priority actions section
format_priority_actions() {
    local categorized_suggestions="$1"
    local system_state="$2"
    
    local priority_section=$(echo "$categorized_suggestions" | sed -n '/=== PRIORITY ACTIONS ===/,/=== READY TO WORK ===/p' | sed '$d')
    local priority_items=$(echo "$priority_section" | grep "^suggestion:" | head -3)
    
    if [ -n "$priority_items" ]; then
        echo "🎯 CRITICAL NEXT STEPS (Do these first)"
        echo "======================================"
        
        local count=0
        while IFS= read -r suggestion; do
            [ -z "$suggestion" ] && continue
            ((count++))
            
            local type=$(echo "$suggestion" | cut -d: -f3)
            local target=$(echo "$suggestion" | cut -d: -f5)  # Target is in field 5
            local message=$(echo "$suggestion" | cut -d: -f6-)
            local commands=$(generate_command_for_suggestion "$suggestion" "$system_state")
            
            # Show cleaner display for different action types
            if [[ "$type" = "start_epic" ]] && [ -n "$target" ]; then
                printf "▶️  Launch work environment for epic: %s\n" "$target"
            else
                printf "▶️  %s\n" "$message"
            fi
            echo "$commands" | sed 's/^/    /'
            echo ""
            
            [ "$count" -ge 2 ] && break
        done <<< "$priority_items"
    fi
}

# Format ready work section
format_ready_work() {
    local categorized_suggestions="$1"
    local system_state="$2"
    
    local work_section=$(echo "$categorized_suggestions" | sed -n '/=== READY TO WORK ===/,/=== MAINTENANCE ===/p' | sed '$d')
    local work_items=$(echo "$work_section" | grep "^suggestion:" | head -5)
    
    if [ -n "$work_items" ]; then
        echo "📝 AVAILABLE WORK (Choose any to start)"
        echo "======================================"
        
        local count=0
        while IFS= read -r suggestion; do
            [ -z "$suggestion" ] && continue
            ((count++))
            
            local type=$(echo "$suggestion" | cut -d: -f3)
            local target=$(echo "$suggestion" | cut -d: -f5)  # Target is in field 5
            local message=$(echo "$suggestion" | cut -d: -f6-)
            local commands=$(generate_command_for_suggestion "$suggestion" "$system_state")
            
            # Show clean action with actual issue name
            if [[ "$type" = "analyze_issue" ]] && [ -n "$target" ]; then
                printf "🔍 Analyze: %s\n" "$target"
                echo "    /pm:issue-analyze $target"
            elif [[ "$type" = "start_issue" ]] && [ -n "$target" ]; then
                printf "🚀 Start work: %s\n" "$target"  
                echo "    /pm:issue-start $target"
            else
                printf "📝 %s\n" "$message"
                echo "$commands" | sed 's/^/    /'
            fi
            echo ""
            
            [ "$count" -ge 4 ] && break
        done <<< "$work_items"
    fi
}

# Format maintenance section
format_maintenance() {
    local categorized_suggestions="$1"
    local system_state="$2"
    
    local maintenance_section=$(echo "$categorized_suggestions" | sed -n '/=== MAINTENANCE ===/,/=== STRATEGIC ===/p' | sed '$d')
    local maintenance_items=$(echo "$maintenance_section" | grep "^suggestion:")
    
    if [ -n "$maintenance_items" ]; then
        echo "🔧 MAINTENANCE & REVIEW"
        echo "======================"
        
        while IFS= read -r suggestion; do
            [ -z "$suggestion" ] && continue
            
            local message=$(echo "$suggestion" | cut -d: -f4-)
            local commands=$(generate_command_for_suggestion "$suggestion" "$system_state")
            
            printf "• %s\n" "$message"
            echo "$commands" | sed 's/^/  /'
            echo ""
        done <<< "$maintenance_items"
    fi
}

# Format contextual tips
format_contextual_tips() {
    local system_state="$1"
    
    local tips=$(generate_contextual_tips "$system_state")
    local tip_lines=$(echo "$tips" | grep "^tip:" | head -3)
    
    if [ -n "$tip_lines" ]; then
        echo "💡 WORKFLOW INSIGHTS"
        echo "==================="
        
        while IFS= read -r tip_line; do
            [ -z "$tip_line" ] && continue
            local tip_text=$(echo "$tip_line" | cut -d: -f2-)
            printf "• %s\n" "$tip_text"
        done <<< "$tip_lines"
        echo ""
    fi
}

# Format quick help section
format_quick_help() {
    local system_state="$1"
    
    # Only show for new users or when stuck
    local summary_line=$(echo "$system_state" | grep "^summary:")
    if [ -n "$summary_line" ]; then
        local ready_issues=$(echo "$summary_line" | cut -d: -f5)
        local analysis_needed=$(echo "$summary_line" | cut -d: -f7)
        local total_activity=$((ready_issues + analysis_needed))
        
        # Skip help if there's plenty to do
        [ "$total_activity" -gt 5 ] && return 0
    fi
    
    echo "📚 QUICK REFERENCE"
    echo "=================="
    cat << 'EOF'
/pm:next              Show this workflow guide
/pm:epic-start <name> Launch parallel work environment  
/pm:issue-start <id>  Start work on specific issue
/pm:issue-analyze <id> Break down complex issues
/pm:issue-sync <id>   Update progress and sync status
/pm:blocked          Review blocked/dependent items

Run any command without arguments for detailed help.
EOF
}

# Format simple status for compatibility mode
format_simple_status() {
    local system_state="$1"
    
    echo "📋 Next Available Tasks"
    echo "======================="
    
    # Parse and show ready issues
    local ready_count=0
    while IFS= read -r issue_line; do
        [[ "$issue_line" =~ ^issue_state: ]] || continue
        
        local issue_id=$(echo "$issue_line" | cut -d: -f2)
        local classification=$(echo "$issue_line" | cut -d: -f4)
        local effort=$(echo "$issue_line" | cut -d: -f8)
        
        case "$classification" in
            "ready_to_start"|"needs_analysis")
                local epic_name=$(get_epic_for_issue "$issue_id")
                printf "✅ Ready: #%s - %s" "$issue_id" "$issue_id"
                [ "$effort" != "unknown" ] && printf " (%s)" "$effort"
                echo ""
                printf "   Epic: %s\n" "$epic_name"
                echo ""
                ((ready_count++))
                ;;
        esac
    done <<< "$system_state"
    
    if [ "$ready_count" -eq 0 ]; then
        echo "No tasks currently ready to start."
        echo ""
        echo "Try:"
        echo "• /pm:issue-analyze <id> to break down issues"
        echo "• /pm:blocked to review dependencies"
        echo "• /pm:prd-new <name> to create new work"
    else
        printf "📊 Summary: %d tasks ready to start\n" "$ready_count"
    fi
}

# Format error output
format_error_output() {
    local error_type="$1"
    local error_details="$2"
    
    echo "❌ Workflow Assistant Error"
    echo "=========================="
    
    case "$error_type" in
        "no_epics_dir")
            cat << 'EOF'
The PM system directory structure is not initialized.

🚀 Quick Fix:
mkdir -p .claude/epics
/pm:prd-new my-first-epic

Then run /pm:next again.
EOF
            ;;
        "permission_error")
            echo "Permission denied accessing PM system files."
            echo "Check directory permissions: ls -la .claude/"
            ;;
        "analysis_error")
            echo "Error analyzing system state: $error_details"
            echo "Try running /pm:next --debug for more information."
            ;;
        *)
            echo "Unknown error: $error_type"
            echo "Details: $error_details"
            ;;
    esac
}

# Format debug output
format_debug_output() {
    local system_state="$1"
    local suggestions="$2"
    
    echo "🐛 DEBUG: Workflow Assistant State"
    echo "================================="
    
    echo "--- EPIC STATES ---"
    echo "$system_state" | grep "^epic_state:" | head -10
    
    echo ""
    echo "--- ISSUE STATES ---" 
    echo "$system_state" | grep "^issue_state:" | head -10
    
    echo ""
    echo "--- SYSTEM SUMMARY ---"
    echo "$system_state" | grep "^summary:"
    
    echo ""
    echo "--- GENERATED SUGGESTIONS ---"
    echo "$suggestions" | head -15
    
    echo ""
    echo "--- CATEGORIZED OUTPUT ---"
    echo "$suggestions" | categorize_suggestions | head -20
}

# Utility function to truncate long text
truncate_text() {
    local text="$1"
    local max_length="${2:-80}"
    
    if [ ${#text} -gt $max_length ]; then
        echo "${text:0:$((max_length-3))}..."
    else
        echo "$text"
    fi
}