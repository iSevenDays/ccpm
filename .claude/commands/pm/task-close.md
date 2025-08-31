---
allowed-tools: Bash, Read, Write, LS
---

# Task Close

Mark a task as complete and close it.

## Usage
```
/pm:task-close <task_number> [completion_notes]
```

## Instructions

### 1. Find Local Task File

First check if `.claude/epics/*/$ARGUMENTS.md` exists (new naming).
If not found, search for task file with `local_id: $ARGUMENTS` in frontmatter (old naming).
If not found: "❌ No local task for task #$ARGUMENTS"

### 2. Update Local Status

Get current datetime: `date -u +"%Y-%m-%dT%H:%M:%SZ"`

Update task file frontmatter:
```yaml
status: closed
updated: {current_datetime}
```

### 3. Update Progress File

If progress file exists at `.claude/epics/{epic}/updates/$ARGUMENTS/progress.md`:
- Set completion: 100%
- Add completion note with timestamp
- Update last_sync with current datetime

### 4. Close on local task file

Add completion comment and close:
```bash
# Add final comment
echo "✅ Task completed

$ARGUMENTS

---
Closed at: {timestamp}"
```

### 5. Update Epic Progress

- Count total tasks in epic
- Count closed tasks
- Calculate new progress percentage
- Update epic.md frontmatter progress field

### 6. Output

```
✅ Closed task #$ARGUMENTS
  Local: Task marked complete
  Epic progress: {new_progress}% ({closed}/{total} tasks complete)
  
Next: Run /pm:next for next priority task
```

## Important Notes

Follow `/rules/frontmatter-operations.md` for updates.
All operations are local-only.
Update local task and epic progress tracking.