---
allowed-tools: Bash, Read, Task
---

# Issue Start

Begin work on an issue with intelligent stream detection and agent launching.

## Instructions

1. Run the issue-start script to detect existing work vs new setup:

```bash
bash .claude/scripts/pm/issue-start.sh $ARGUMENTS
```

2. If the script detects existing streams that need to be resumed, launch Task agents for active streams:

Read the updates directory and for each active stream, launch the appropriate agent:

```bash
# Get epic and updates info from script output
epic_name=$(bash .claude/scripts/pm/issue-start.sh $ARGUMENTS | grep "Epic:" | cut -d: -f2 | tr -d ' ')
updates_dir=".claude/epics/$epic_name/updates/$ARGUMENTS"

# Check if resuming existing work
if [ -d "$updates_dir" ] && [ "$(ls -A "$updates_dir" 2>/dev/null)" ]; then
  echo "Launching agents for existing streams..."
  
  for stream_file in "$updates_dir"/stream-*.md; do
    [ -f "$stream_file" ] || continue
    
    stream_status=$(grep "^status:" "$stream_file" | cut -d: -f2 | tr -d ' ')
    # Skip completed streams
    [ "$stream_status" = "completed" ] && continue
    
    stream_id=$(basename "$stream_file" .md | sed 's/stream-//')
    stream_name=$(grep "^stream:" "$stream_file" | cut -d: -f2- | sed 's/^ *//')
    agent_type=$(grep "^agent:" "$stream_file" | cut -d: -f2 | tr -d ' ')
    
    # Launch Task agent for this stream
    Task:
      description: "Resume Issue #$ARGUMENTS Stream $stream_id"
      subagent_type: "$agent_type"
      prompt: |
        Resume work on Issue #$ARGUMENTS Stream $stream_id: $stream_name
        
        Epic: $epic_name
        Previous progress: Read from .claude/epics/$epic_name/updates/$ARGUMENTS/stream-$stream_id.md
        
        Your tasks:
        1. Read your stream file to understand what you were working on
        2. Work in the epic worktree (check 'git worktree list' for location)
        3. Continue from where you left off
        4. Update your progress file as you work
        5. When complete, update your stream status to 'completed'
        
        Start working now.
  done
fi
```

## Instructions

**🚀 AGENT-FIRST APPROACH: Use Task tool to launch specialized agents instead of doing manual searches!**

**Available Agents:**
- `general-purpose` - Analysis, research, multi-step tasks
- `code-analyzer` - Code analysis and logic tracing  
- `file-analyzer` - File reading and summarization

### 1. Check for --analyze Flag

If `--analyze` flag is present, immediately launch analysis agent:

```yaml
Task:
  description: "Analyze issue for parallel streams"  
  subagent_type: "general-purpose"
  prompt: |
    Analyze issue $ARGUMENTS for parallel work streams.
    
    Steps:
    1. Find issue file: search .claude/epics/*/$ARGUMENTS.md or .claude/epics/*/tasks/$ARGUMENTS.md
    2. Read issue content and understand requirements
    3. Identify parallel work streams (backend, frontend, tests, etc.)
    4. Create analysis file: .claude/epics/{epic_name}/$ARGUMENTS-analysis.md
    
    Use Read/Write tools to create proper analysis with streams, files, coordination points.
    Format analysis with Stream A, B, C sections as shown in issue-analyze template.
```

### 2. Ensure Worktree Exists

Check if epic worktree exists:
```bash
# Find epic name from issue file
epic_name={extracted_from_path}

# Check worktree
if ! git worktree list | grep -q "epic-$epic_name"; then
  echo "❌ No worktree for epic. Run: /pm:epic-start $epic_name"
  exit 1
fi
```

### 3. Read Analysis

Read `.claude/epics/{epic_name}/$ARGUMENTS-analysis.md`:
- Parse parallel streams
- Identify which can start immediately
- Note dependencies between streams

### 4. Check Existing Work Streams

Check if work is already in progress:

```bash
# Extract epic name from issue file path
epic_name=$(echo "$issue_file" | sed 's|^.claude/epics/||' | cut -d'/' -f1)

# Check for existing progress tracking
updates_dir=".claude/epics/$epic_name/updates/$ARGUMENTS"

if [ -d "$updates_dir" ] && [ "$(ls -A "$updates_dir" 2>/dev/null)" ]; then
  echo "🔄 RESUMING EXISTING WORK"
  echo "========================"
  echo "Epic: $epic_name"
  echo "Issue: $ARGUMENTS"
  echo ""
  
  # Show current stream status
  for stream_file in "$updates_dir"/stream-*.md; do
    [ -f "$stream_file" ] || continue
    stream_id=$(basename "$stream_file" .md)
    stream_status=$(grep "^status:" "$stream_file" | cut -d: -f2 | tr -d ' ')
    stream_name=$(grep "^stream:" "$stream_file" | cut -d: -f2- | sed 's/^ *//')
    agent_type=$(grep "^agent:" "$stream_file" | cut -d: -f2 | tr -d ' ')
    
    case "$stream_status" in
      "completed")
        echo "  ✅ $stream_id: $stream_name [COMPLETED]"
        ;;
      "in_progress")
        echo "  ▶️  $stream_id: $stream_name [IN PROGRESS]"
        echo "     → Ready to resume with $agent_type agent"
        ;;
      *)
        echo "  🔄 $stream_id: $stream_name [READY TO START]"
        echo "     → Can start with $agent_type agent"
        ;;
    esac
  done
  
  echo ""
  echo "📍 NEXT ACTIONS:"
  echo "Choose a stream to continue working on (see launch commands below)"
  
  # Set flag for resume mode
  RESUME_MODE="yes"
  
else
  echo "📂 SETTING UP NEW WORK"
  echo "======================"
  
  # Get current datetime
  current_datetime=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
  
  # Extract epic name from issue file path
  epic_name=$(echo "$issue_file" | sed 's|^.claude/epics/||' | cut -d'/' -f1)
  
  # Create workspace structure
  mkdir -p "$updates_dir"
  
  # Update issue status to in_progress
  sed -i.bak -e "/^status:/s/.*/status: in_progress/" -e "/^updated:/s/.*/updated: $current_datetime/" "$issue_file"
  echo "✅ Updated issue status to in_progress"
  echo "✅ Created progress tracking directory: $updates_dir"
  
  # Set flag for new work mode
  RESUME_MODE="no"
fi
```

### 5. Launch or Resume Stream Agents

**IMPORTANT: Use Task tool to launch work agents for each stream.**

```bash
# Parse analysis file to get stream definitions
if [ "$RESUME_MODE" = "yes" ]; then
  echo ""
  echo "🚀 STREAM LAUNCH COMMANDS"
  echo "========================"
  echo "Copy and run any of these commands to work on specific streams:"
  echo ""
  
  # For resume mode, show launch commands for existing streams
  for stream_file in "$updates_dir"/stream-*.md; do
    [ -f "$stream_file" ] || continue
    
    stream_id=$(basename "$stream_file" .md | sed 's/stream-//')
    stream_status=$(grep "^status:" "$stream_file" | cut -d: -f2 | tr -d ' ')
    stream_name=$(grep "^stream:" "$stream_file" | cut -d: -f2- | sed 's/^ *//')
    agent_type=$(grep "^agent:" "$stream_file" | cut -d: -f2 | tr -d ' ')
    
    # Skip completed streams
    if [ "$stream_status" = "completed" ]; then
      continue
    fi
    
    echo "# Stream $stream_id: $stream_name"
    echo "Task:"
    echo "  description: \"Resume Issue #$ARGUMENTS Stream $stream_id\""
    echo "  subagent_type: \"$agent_type\""
    echo "  prompt: |"
    echo "    Resume work on Issue #$ARGUMENTS Stream $stream_id: $stream_name"
    echo "    "
    echo "    Epic: $epic_name"
    echo "    Worktree: Check 'git worktree list' for epic/$epic_name location"
    echo "    Previous progress: Read from .claude/epics/$epic_name/updates/$ARGUMENTS/stream-$stream_id.md"
    echo "    "
    echo "    Your tasks:"
    echo "    1. Read your stream file to understand what you were working on"
    echo "    2. Continue from where you left off"
    echo "    3. Work in the epic worktree (not main directory)"
    echo "    4. Update your progress file as you work"
    echo "    5. Commit changes with: \"Issue #$ARGUMENTS Stream $stream_id: [specific change]\""
    echo "    "
    echo "    When complete, update your stream status to 'completed'."
    echo ""
  done
  
else
  echo ""
  echo "🚀 CREATING NEW WORK STREAMS"
  echo "==========================="
  
  # Parse streams from analysis file using a simple approach
  echo "# Read analysis file and extract stream information"
  echo "analysis_content=\$(cat \"$analysis_file\")"
  echo ""
  echo "# Look for Stream sections and extract details"
  echo "# This is a template - actual implementation needs to parse analysis file"
  echo "# and create stream files + launch Task agents for each stream"
  echo ""
  echo "# For each stream found in analysis:"
  echo "# 1. Create stream-X.md file with frontmatter"
  echo "# 2. Launch Task agent for that stream"
  echo "# 3. Show launch command to user"
  echo ""
  echo "Example stream creation:"
  
  cat << 'EOF'
# Create stream file template
cat > "$updates_dir/stream-A.md" << STREAM_EOF
---
issue: $ARGUMENTS
stream: {stream_name_from_analysis}
agent: {agent_type_from_analysis}
started: $current_datetime
status: ready
---

# Stream A: {stream_name_from_analysis}

## Scope
{scope_from_analysis}

## Files  
{files_from_analysis}

## Progress
- Ready to start implementation

STREAM_EOF

# Launch agent for Stream A
Task:
  description: "Issue #$ARGUMENTS Stream A"
  subagent_type: "{agent_type_from_analysis}"
  prompt: |
    Start work on Issue #$ARGUMENTS Stream A: {stream_name_from_analysis}
    
    Epic: $epic_name
    Worktree: Check 'git worktree list' for epic/$epic_name location  
    
    Your scope:
    - Files: {files_from_analysis}
    - Work: {scope_from_analysis}
    
    Tasks:
    1. Work in the epic worktree (not main directory)
    2. Focus only on your assigned files and scope
    3. Update progress in: .claude/epics/$epic_name/updates/$ARGUMENTS/stream-A.md
    4. Commit changes with: "Issue #$ARGUMENTS Stream A: [specific change]"
    5. Mark stream as 'completed' when done
    
    Start implementation now.
EOF

fi
```

### 6. Output

```bash
# For resume mode
if [ "$RESUME_MODE" = "yes" ]; then
  echo ""
  echo "🎯 READY TO CONTINUE WORK"
  echo "========================="
  echo "Issue #$ARGUMENTS is ready for continued development"
  echo ""
  echo "📂 Progress tracking: $updates_dir"
  echo "🌳 Epic worktree: Use 'git worktree list' to find location"
  echo ""
  echo "📋 NEXT STEPS:"
  echo "1. Copy and run one of the Task commands above"
  echo "2. The agent will resume from previous progress"
  echo "3. Monitor progress: /pm:issue-sync $ARGUMENTS"
  echo "4. Check epic status: /pm:epic-status $epic_name"
  
# For new work mode
else
  echo ""
  echo "✅ WORK STREAMS READY TO START"
  echo "=============================="
  echo "Issue #$ARGUMENTS has been set up for parallel development"
  echo ""
  echo "📂 Progress tracking: $updates_dir"
  echo "🌳 Epic worktree: Use 'git worktree list' to find location"
  echo ""
  echo "📋 NEXT STEPS:"
  echo "1. Parse analysis file to extract stream definitions"
  echo "2. Create stream files with proper frontmatter"
  echo "3. Launch Task agents for each stream"
  echo "4. Monitor progress: /pm:issue-sync $ARGUMENTS"
  echo "5. Check epic status: /pm:epic-status $epic_name"
  
  echo ""
  echo "⚠️  NOTE: Stream creation logic needs full implementation"
  echo "   Current version shows templates - needs analysis parsing"
fi
```

## Error Handling

If any step fails, report clearly:
- "❌ {What failed}: {How to fix}"
- Continue with what's possible
- Never leave partial state

## Important Notes

Follow `/rules/datetime.md` for timestamps.
Keep it simple - trust that git and file system work.