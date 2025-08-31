---
allowed-tools: Read, LS
---

# Epic Oneshot

Decompose epic into tasks and generate summary in one operation.

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

Simply run the decompose command:
```
Running: /pm:epic-decompose $ARGUMENTS
```

This will:
- Read the epic
- Create task files (using parallel agents if appropriate)
- Update epic with task summary

### 3. Generate Summary

Immediately follow with summary:
```
Running: /pm:epic-summary $ARGUMENTS
```

This will:
- Generate comprehensive epic report
- Analyze task progress and dependencies
- Create local summary files
- Create worktree for epic development

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
  Or single task: /pm:task-start {task_number}
```

## Important Notes

This is simply a convenience wrapper that runs:
1. `/pm:epic-decompose` 
2. `/pm:epic-sync`

Both commands handle their own error checking, parallel execution, and validation. This command just orchestrates them in sequence.

Use this when you're confident the epic is ready and want to go from epic to GitHub issues in one step.