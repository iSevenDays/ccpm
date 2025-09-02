---
allowed-tools: Bash, Read, Write, LS, Task
---

# Epic Oneshot

Decompose epic into issues and generate summary in one operation.

## Usage
```
/pm:epic-oneshot <feature_name>
```

## Instructions

### 1. Validate Prerequisites

Check that epic exists and hasn't been processed:
```bash
# Epic must exist
test -f .claude/epics/$ARGUMENTS/epic.md || echo "❌ Epic not found. Run: /pm:prd-parse $ARGUMENTS"

# Check for existing tasks
if ls .claude/epics/$ARGUMENTS/[0-9]*.md 2>/dev/null | grep -q .; then
  echo "⚠️ Tasks already exist. This will create duplicates."
  echo "Delete existing tasks or use /pm:epic-summary instead."
  exit 1
fi

# Check if already synced
if grep -q "local_id:" .claude/epics/$ARGUMENTS/epic.md; then
  echo "⚠️ Epic already processed."
  echo "Use /pm:epic-summary to update."
  exit 1
fi
```

### 2. Execute Decompose

Task:
  description: "Decompose epic into tasks"
  subagent_type: "general-purpose"
  prompt: |
    Execute epic decomposition for: $ARGUMENTS
    
    Follow the complete epic-decompose workflow:
    1. Validate epic exists at .claude/epics/$ARGUMENTS/epic.md
    2. Check for existing tasks
    3. Create task files with proper frontmatter
    4. Update epic with task summary
    
    Use Read/Write/Bash tools as needed.
    Return: Summary of tasks created

### 3. Generate Summary

Task:
  description: "Generate epic summary"
  subagent_type: "general-purpose"
  prompt: |
    Generate comprehensive local summary for: $ARGUMENTS
    
    Follow the complete epic-summary workflow:
    1. Create epic statistics
    2. Generate task breakdowns
    3. Create progress reports
    4. Update epic frontmatter
    
    Use Read/Write/Bash tools as needed.
    Return: Summary file location and statistics

### 4. Output

```
🚀 Epic Oneshot Complete: $ARGUMENTS

Step 1: Decomposition ✓
  - Tasks created: {count}
  
Step 2: Summary Generated ✓
  - Epic progress: {progress}%
  - Tasks analyzed: {count}
  - Worktree: ../epic-$ARGUMENTS
  - Summary saved: .claude/epics/$ARGUMENTS/summaries/

Ready for development!
  Start work: /pm:epic-start $ARGUMENTS
  Or single issue: /pm:issue-start {issue_number}
```

## Important Notes

This is simply a convenience wrapper that runs:
1. `/pm:epic-decompose` 
2. `/pm:epic-summary`

Both commands handle their own error checking, parallel execution, and validation. This command just orchestrates them in sequence.

Use this when you're confident the epic is ready and want to go from epic to task summary in one step.