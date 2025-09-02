#!/bin/bash
# Issue Start - Resume/Continue work on issues with intelligent stream detection
# Creates new work streams or resumes existing ones based on current state

ARGUMENTS="$1"

# Validation
if [ -z "$ARGUMENTS" ]; then
  echo "❌ Usage: /pm:issue-start <issue_number>"
  exit 1
fi

echo "🔄 Analyzing issue state..."

# Find local issue file
issue_file=$(find .claude/epics -name "$ARGUMENTS.md" -o -name "*/$ARGUMENTS.md" | head -1)
if [ -z "$issue_file" ]; then
  echo "❌ No local issue file for #$ARGUMENTS. This issue may have been created outside the PM system."
  exit 1
fi
echo "Found issue file: $issue_file"

# Check for analysis file
analysis_file=$(find .claude/epics -name "$ARGUMENTS-analysis.md" | head -1)
if [ -z "$analysis_file" ]; then
  echo "❌ No analysis found for issue #$ARGUMENTS"
  echo "Run: /pm:issue-analyze $ARGUMENTS first"
  exit 1
fi

# Extract epic name from issue file path
epic_name=$(echo "$issue_file" | sed 's|^.claude/epics/||' | cut -d'/' -f1)

# Check for existing progress tracking
updates_dir=".claude/epics/$epic_name/updates/$ARGUMENTS"

if [ -d "$updates_dir" ] && [ "$(ls -A "$updates_dir" 2>/dev/null)" ]; then
  echo ""
  echo "🔄 RESUMING EXISTING WORK"
  echo "========================"
  echo "Epic: $epic_name"
  echo "Issue: $ARGUMENTS"
  echo ""
  
  # Show current stream status
  active_streams=0
  completed_streams=0
  
  for stream_file in "$updates_dir"/stream-*.md; do
    [ -f "$stream_file" ] || continue
    stream_id=$(basename "$stream_file" .md)
    stream_status=$(grep "^status:" "$stream_file" | cut -d: -f2 | tr -d ' ')
    stream_name=$(grep "^stream:" "$stream_file" | cut -d: -f2- | sed 's/^ *//')
    agent_type=$(grep "^agent:" "$stream_file" | cut -d: -f2 | tr -d ' ')
    
    case "$stream_status" in
      "completed")
        echo "  ✅ $stream_id: $stream_name [COMPLETED]"
        ((completed_streams++))
        ;;
      "in_progress")
        echo "  ▶️  $stream_id: $stream_name [IN PROGRESS]"
        echo "     → Ready to resume with $agent_type agent"
        ((active_streams++))
        ;;
      *)
        echo "  🔄 $stream_id: $stream_name [READY TO START]"
        echo "     → Can start with $agent_type agent"
        ((active_streams++))
        ;;
    esac
  done
  
  echo ""
  if [ $active_streams -gt 0 ]; then
    echo "🚀 RESUMING ACTIVE STREAMS"
    echo "========================="
    
    # Actually launch Task agents for active streams (this will be handled by Claude Code)
    echo "Claude Code will now launch agents for active streams..."
    
  else
    echo "🎉 All streams completed! Issue is ready for final review."
  fi
  
  echo ""
  echo "🎯 READY TO CONTINUE WORK"
  echo "========================="
  echo "Issue #$ARGUMENTS is ready for continued development"
  echo ""
  echo "📂 Progress tracking: $updates_dir"
  echo "🌳 Epic worktree: Use 'git worktree list' to find location"
  echo ""
  echo "📋 STATUS:"
  echo "• Active streams: $active_streams"
  echo "• Completed streams: $completed_streams"
  echo "• Monitor progress: /pm:issue-sync $ARGUMENTS"
  echo "• Check epic status: /pm:epic-status $epic_name"

else
  echo ""
  echo "📂 SETTING UP NEW WORK"
  echo "======================"
  
  # Get current datetime
  current_datetime=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
  
  # Create workspace structure
  mkdir -p "$updates_dir"
  
  # Update issue status to in_progress
  sed -i.bak -e "/^status:/s/.*/status: in_progress/" -e "/^updated:/s/.*/updated: $current_datetime/" "$issue_file"
  echo "✅ Updated issue status to in_progress"
  echo "✅ Created progress tracking directory: $updates_dir"
  
  echo ""
  echo "⚠️  NEW STREAM CREATION NEEDED"
  echo "============================="
  echo "This script detects existing work but doesn't yet implement"
  echo "automatic stream creation from analysis files."
  echo ""
  echo "📋 MANUAL NEXT STEPS:"
  echo "1. Parse analysis file: $analysis_file"
  echo "2. Create stream files with proper frontmatter"
  echo "3. Launch Task agents for each stream"
  echo "4. Monitor progress: /pm:issue-sync $ARGUMENTS"
  echo ""
  echo "The resume functionality works perfectly - new stream creation"
  echo "needs to be implemented by parsing the analysis file structure."
fi

exit 0