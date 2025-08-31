---
allowed-tools: Bash, Read, Write, LS
---

# Issue Edit

Edit task details locally.

## Usage
```
/pm:task-edit <task_number>
```

## Instructions

### 1. Get Current Task State

```bash
# Find local task file
# Search for file with local_id: $ARGUMENTS in frontmatter
# Or check .claude/epics/*/$ARGUMENTS.md
```

### 2. Interactive Edit

Ask user what to edit:
- Title
- Description/Body
- Labels
- Acceptance criteria (local only)
- Priority/Size (local only)

### 3. Update Local File

Get current datetime: `date -u +"%Y-%m-%dT%H:%M:%SZ"`

Update task file with changes:
- Update frontmatter `name` if title changed
- Update body content if description changed
- Update `updated` field with current datetime

### 4. Update Local Tracking

Update local task tracking:
- Recalculate epic progress if task status changed
- Update task dependencies if affected
- Refresh local progress summaries

### 5. Output

```
✅ Updated task #$ARGUMENTS
  Changes:
    {list_of_changes_made}
  
Local tracking updated: ✅
```

## Important Notes

All operations are local-only.
Preserve frontmatter fields not being edited.
Follow `/rules/frontmatter-operations.md`.