---
allowed-tools: Read, Write, LS
---

# Epic Refresh

Update epic progress based on task states.

## Usage
```
/pm:epic-refresh <epic_name>
```

## Instructions

### 1. Count Task Status

Scan all task files in `.claude/epics/$ARGUMENTS/`:
- Count total tasks
- Count tasks with `status: closed`
- Count tasks with `status: open`
- Count tasks with work in progress

### 2. Calculate Progress

```
progress = (closed_tasks / total_tasks) * 100
```

Round to nearest integer.

### 3. Update Local Task Tracking

Refresh local epic summary and task tracking:

```bash
# For each task, get current status and update local tracking
for task_file in .claude/epics/$ARGUMENTS/[0-9]*.md; do
  task_id=$(grep 'local_id:' $task_file | cut -d: -f2 | tr -d ' ')
  task_status=$(grep 'status:' $task_file | cut -d: -f2 | tr -d ' ')
  task_name=$(grep 'name:' $task_file | cut -d: -f2- | sed 's/^ *//')
  
  # Update task tracking files
  if [ "$task_status" = "closed" ]; then
    echo "✅ $task_name ($task_id)" >> /tmp/completed-tasks.txt
  elif [ "$task_status" = "in-progress" ]; then
    echo "🔄 $task_name ($task_id)" >> /tmp/active-tasks.txt
  else
    echo "⏸️ $task_name ($task_id)" >> /tmp/pending-tasks.txt
  fi
done

# Generate updated epic summary
/pm:epic-summary $ARGUMENTS
```

### 4. Determine Epic Status

- If progress = 0% and no work started: `backlog`
- If progress > 0% and < 100%: `in-progress`
- If progress = 100%: `completed`

### 5. Update Epic

Get current datetime: `date -u +"%Y-%m-%dT%H:%M:%SZ"`

Update epic.md frontmatter:
```yaml
status: {calculated_status}
progress: {calculated_progress}%
updated: {current_datetime}
```

### 6. Output

```
🔄 Epic refreshed: $ARGUMENTS

Tasks:
  Closed: {closed_count}
  Open: {open_count}
  Total: {total_count}
  
Progress: {old_progress}% → {new_progress}%
Status: {old_status} → {new_status}
Local tracking updated ✅

{If complete}: Run /pm:epic-close $ARGUMENTS to close epic
{If in progress}: Run /pm:next to see priority tasks
```

## Important Notes

This is useful after manual task edits or status changes.
Don't modify task files, only epic status.
Preserve all other frontmatter fields.