---
allowed-tools: Bash, Read, Write, LS, Task
---

# Epic Start

Launch parallel agents to work on epic tasks in a shared branch.

## Usage
```
/pm:epic-start <epic_name>
```

## Validation

```bash
# Verify epic exists
if [ ! -f ".claude/epics/$ARGUMENTS/epic.md" ]; then
  echo "❌ Epic not found. Run: /pm:prd-parse $ARGUMENTS"
  exit 1
fi
echo "Found epic: .claude/epics/$ARGUMENTS/epic.md"

# Check for uncommitted changes in work repository
work_root=$(git rev-parse --show-toplevel)
cd "$work_root"
if [ -n "$(git status --porcelain)" ]; then
  echo "❌ You have uncommitted changes. Commit them or stash them before starting the epic."
  exit 1
fi
echo "Work repository is clean"
```

## Instructions

### 1. Create or Enter Branch

Follow `/rules/branch-operations.md`:

```bash
# Check for uncommitted changes in work repository (not .claude repo)
work_root=$(git rev-parse --show-toplevel)
cd "$work_root"
if [ -n "$(git status --porcelain)" ]; then
  echo "❌ You have uncommitted changes. Commit them (git add . && git commit -m \"msg\") or stash them (git stash push -m \"work in progress\") before starting the epic."
  exit 1
fi

# If branch doesn't exist, create it
if ! git branch -a | grep -q "epic/$ARGUMENTS"; then
  git checkout main
  git pull origin main
  git checkout -b epic/$ARGUMENTS
  # IMPORTANT: git push is prohibited
  echo "✅ Created branch: epic/$ARGUMENTS"
else
  git checkout epic/$ARGUMENTS
  git pull origin epic/$ARGUMENTS
  echo "✅ Using existing branch: epic/$ARGUMENTS"
fi
```

### 2. Identify Ready Tasks

Read all task files in `.claude/epics/$ARGUMENTS/`:
- Parse frontmatter for `status`, `depends_on`, `parallel` fields
- Build dependency graph

Categorize tasks:
- **Ready**: No unmet dependencies, not started
- **Blocked**: Has unmet dependencies
- **In Progress**: Already being worked on
- **Complete**: Finished

### 3. Analyze Ready Issues

For each ready issue without analysis, launch analysis agent:

Template pattern:
```yaml
Task:
  description: "Analyze issue for parallel streams"
  subagent_type: "general-purpose"  
  prompt: |
    Run analysis for issue {issue_number} in epic $ARGUMENTS.
    Create analysis file: .claude/epics/$ARGUMENTS/{issue_number}-analysis.md
    Follow issue-analyze.md template with concrete streams and agent types.
```

### 4. Parse Analysis and Launch Agents

**Add parsing functions to extract template variables:**

```bash
# Parse analysis file to extract stream details with error handling
parse_analysis_stream() {
  local analysis_file="$1"
  local stream_id="$2"
  
  # Validate analysis file exists and is readable
  if [ ! -f "$analysis_file" ]; then
    echo "❌ Analysis file not found: $analysis_file"
    return 1
  fi
  
  if [ ! -r "$analysis_file" ]; then
    echo "❌ Cannot read analysis file: $analysis_file"
    return 1
  fi
  
  # Extract stream section  
  stream_section=$(sed -n "/### Stream $stream_id:/,/### Stream [A-Z]:/p" "$analysis_file" | head -n -1)
  if [ -z "$stream_section" ]; then
    # Try end of file if last stream
    stream_section=$(sed -n "/### Stream $stream_id:/,\$p" "$analysis_file")
  fi
  
  # Validate stream section was found
  if [ -z "$stream_section" ]; then
    echo "❌ Stream $stream_id not found in analysis file: $analysis_file"
    return 1
  fi
  
  # Parse agent type with validation
  agent_type=$(echo "$stream_section" | grep "\*\*Agent Type\*\*:" | sed 's/.*: //' | head -1)
  agent_type=${agent_type:-"general-purpose"}
  
  # Validate agent type is not empty after cleanup
  if [ -z "$agent_type" ] || [ "$agent_type" = "{agent_type}" ]; then
    echo "⚠️ Warning: Invalid agent type for Stream $stream_id, using general-purpose"
    agent_type="general-purpose"
  fi
  
  # Parse stream name
  stream_name=$(grep "### Stream $stream_id:" "$analysis_file" | sed "s/### Stream $stream_id: //" | head -1)
  stream_name=${stream_name:-"Stream $stream_id"}
  
  # Parse file patterns (multi-line) with validation
  file_patterns=$(echo "$stream_section" | sed -n '/\*\*Files\*\*:/,/\*\*[^*]/p' | grep '^- ' | sed 's/^- //' | tr '\n' ',' | sed 's/,$//')
  
  # Validate file patterns found
  if [ -z "$file_patterns" ]; then
    echo "⚠️ Warning: No file patterns found for Stream $stream_id"
    file_patterns="**/*"  # Fallback pattern
  fi
  
  # Parse stream description with validation
  stream_description=$(echo "$stream_section" | grep "\*\*Scope\*\*:" | sed 's/.*: //')
  stream_description=${stream_description:-"Work on Stream $stream_id"}
  
  # Validate description is not template placeholder
  if [ "$stream_description" = "{What this stream handles}" ]; then
    stream_description="Work on Stream $stream_id"
  fi
  
  # Export variables for use in Task calls
  export STREAM_AGENT_TYPE="$agent_type"
  export STREAM_NAME="$stream_name" 
  export STREAM_FILES="$file_patterns"
  export STREAM_DESCRIPTION="$stream_description"
  
  # Debug output
  echo "  📋 Parsed Stream $stream_id: $agent_type agent, files: $file_patterns"
  
  return 0
}

# Check if stream can start (dependencies met)
check_stream_dependencies() {
  local analysis_file="$1"
  local stream_id="$2"
  
  # Extract dependencies
  deps=$(sed -n "/### Stream $stream_id:/,/### Stream [A-Z]:/p" "$analysis_file" | grep "\*\*Dependencies\*\*:" | sed 's/.*: //')
  
  # If no dependencies or "none", can start
  if [[ -z "$deps" || "$deps" == "none" ]]; then
    return 0
  fi
  
  # Check if dependent streams are complete (simplified check)
  # In real implementation, check progress files
  return 1
}
```

**For each ready issue with analysis:**

```bash
# Process each issue file with error handling
for issue_file in .claude/epics/$ARGUMENTS/issues/*.md .claude/epics/$ARGUMENTS/*.md; do
  # Skip if no files match pattern
  [ ! -f "$issue_file" ] && continue
  
  issue_num=$(basename "$issue_file" .md)
  # Check for analysis file in both locations
  analysis_file=".claude/epics/$ARGUMENTS/$issue_num-analysis.md"
  if [ ! -f "$analysis_file" ]; then
    analysis_file=".claude/epics/$ARGUMENTS/issues/$issue_num-analysis.md"
  fi
  
  # Skip epic.md and other non-issue files
  if [[ "$issue_num" == "epic" ]] || [[ ! "$issue_num" =~ ^[0-9a-z-]+$ ]]; then
    continue
  fi
  
  if [ -f "$analysis_file" ]; then
    echo "## Starting Issue #$issue_num"
    
    # Find streams in analysis file with validation
    streams=$(grep "### Stream [A-Z]:" "$analysis_file" | sed 's/### Stream \([A-Z]\):.*/\1/')
    
    if [ -z "$streams" ]; then
      echo "⚠️ Warning: No streams found in analysis file: $analysis_file"
      continue
    fi
    
    stream_count=$(echo "$streams" | wc -w)
    echo "  Found $stream_count streams: $streams"
    
    for stream_id in $streams; do
      if check_stream_dependencies "$analysis_file" "$stream_id"; then
        # Parse stream details with error handling
        if parse_analysis_stream "$analysis_file" "$stream_id"; then
          echo "  ├─ Stream $stream_id: $STREAM_NAME ($STREAM_AGENT_TYPE)"
          
          # Launch agent with parsed values (not templates)
```

        # Launch Task tool with parsed values (NO MORE TEMPLATES)
        Task:
          description: "Issue #$issue_num Stream $stream_id"
          subagent_type: "$STREAM_AGENT_TYPE"
          prompt: |
            Working in branch: epic/$ARGUMENTS
            Issue: #$issue_num
            Stream: $STREAM_NAME
            
            Your scope:
            - Files: $STREAM_FILES
            - Work: $STREAM_DESCRIPTION
            
            Read full requirements from:
            - .claude/epics/$ARGUMENTS/$issue_num.md
            - .claude/epics/$ARGUMENTS/$issue_num-analysis.md
            
            Follow coordination rules in /rules/agent-coordination.md
            Commit frequently with message format:
            "Issue #$issue_num: {specific change}"
            
            Create progress tracking:
            .claude/epics/$ARGUMENTS/updates/$issue_num/stream-$stream_id.md
            
            Update progress as you work and coordinate with other streams.
            
        else
          echo "  ❌ Failed to parse Stream $stream_id from $analysis_file"
        fi
      else
        echo "  ⏸ Stream $stream_id: Waiting for dependencies"
      fi
    done
  else
    echo "  ❌ No analysis file found: $analysis_file"
    echo "    Run: /pm:issue-analyze $issue_num"
  fi
done

# Summary
echo ""
echo "🚀 Epic execution started: $ARGUMENTS"
echo "Monitor with: /pm:epic-status $ARGUMENTS"
```

### 5. Track Active Agents

Create/update `.claude/epics/$ARGUMENTS/execution-status.md`:

```markdown
---
started: {datetime}
branch: epic/$ARGUMENTS
---

# Execution Status

## Active Agents
- Agent-1: Task #1234 Stream A (Database) - Started {time}
- Agent-2: Task #1234 Stream B (API) - Started {time}
- Agent-3: Task #1235 Stream A (UI) - Started {time}

## Queued Tasks
- Task #1236 - Waiting for #1234
- Task #1237 - Waiting for #1235

## Completed
- {None yet}
```

### 6. Monitor and Coordinate

Set up monitoring:
```bash
echo "
Agents launched successfully!

Monitor progress:
  /pm:epic-status $ARGUMENTS

View branch changes:
  git status

Stop all agents:
  /pm:epic-stop $ARGUMENTS

Merge when complete:
  /pm:epic-merge $ARGUMENTS
"
```

### 7. Handle Dependencies

As agents complete streams:
- Check if any blocked tasks are now ready
- Launch new agents for newly-ready work
- Update execution-status.md

## Output Format

```
🚀 Epic Execution Started: $ARGUMENTS

Branch: epic/$ARGUMENTS

Launching {total} agents across {task_count} tasks:

Task #1234: Database Schema
  ├─ Stream A: Schema creation (Agent-1) ✓ Started
  └─ Stream B: Migrations (Agent-2) ✓ Started

Task #1235: API Endpoints
  ├─ Stream A: User endpoints (Agent-3) ✓ Started
  ├─ Stream B: Post endpoints (Agent-4) ✓ Started
  └─ Stream C: Tests (Agent-5) ⏸ Waiting for A & B

Blocked Tasks (2):
  - #1236: UI Components (depends on #1234)
  - #1237: Integration (depends on #1235, #1236)

Monitor with: /pm:epic-status $ARGUMENTS
```

## Error Handling

If agent launch fails:
```
❌ Failed to start Agent-{id}
  Task: #{task}
  Stream: {stream}
  Error: {reason}

Continue with other agents? (yes/no)
```

If uncommitted changes are found:
```
❌ You have uncommitted changes. Please commit or stash them before starting an epic.

To commit changes:
  git add .
  git commit -m "Your commit message"

To stash changes:
  git stash push -m "Work in progress"
  # (Later restore with: git stash pop)
```

If branch creation fails:
```
❌ Cannot create branch
  {git error message}

Try: git branch -d epic/$ARGUMENTS
Or: Check existing branches with: git branch -a
```

## Important Notes

- Follow `/rules/branch-operations.md` for git operations
- Follow `/rules/agent-coordination.md` for parallel work
- Agents work in the SAME branch (not separate branches)
- Maximum parallel agents should be reasonable (e.g., 5-10)
- Monitor system resources if launching many agents
