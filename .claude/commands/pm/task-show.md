---
allowed-tools: Bash, Read, LS
---

# Issue Show

Display issue and sub-issues with detailed information.

## Usage
```
/pm:task-show <issue_number>
```

## Instructions

You are displaying comprehensive information about a local task for: **Task #$ARGUMENTS**

### 1. Fetch Task Data
- Look for local task file: first check `.claude/epics/*/$ARGUMENTS.md` (new naming)
- If not found, search for file with `local_id: $ARGUMENTS` in frontmatter (old naming)
- Check for related tasks and dependencies

### 2. Task Overview
Display task header:
```
📋 Task #$ARGUMENTS: {Task Title}
   Status: {open/in-progress/closed}
   Priority: {priority}
   Epic: {epic_name}
   Created: {creation_date}
   Updated: {last_update}
   
📝 Description:
{issue_description}
```

### 3. Local File Mapping
If local task file exists:
```
📁 Local Files:
   Task file: .claude/epics/{epic_name}/{task_file}
   Updates: .claude/epics/{epic_name}/updates/$ARGUMENTS/
   Last local update: {timestamp}
```

### 4. Sub-Issues and Dependencies
Show related issues:
```
🔗 Related Issues:
   Parent Epic: #{epic_issue_number}
   Dependencies: #{dep1}, #{dep2}
   Blocking: #{blocked1}, #{blocked2}
   Sub-tasks: #{sub1}, #{sub2}
```

### 5. Recent Activity
Display recent progress updates from local files:
```
💬 Recent Updates:
   {timestamp} - Progress: {update_summary}
   {timestamp} - Note: {technical_note}
   
   View details: cat .claude/epics/{epic}/updates/$ARGUMENTS/progress.md
```

### 6. Progress Tracking
If task file exists, show progress:
```
✅ Acceptance Criteria:
   ✅ Criterion 1 (completed)
   🔄 Criterion 2 (in progress)
   ⏸️ Criterion 3 (blocked)
   □ Criterion 4 (not started)
```

### 7. Quick Actions
```
🚀 Quick Actions:
   Start work: /pm:task-start $ARGUMENTS
   Update progress: /pm:task-sync $ARGUMENTS
   Edit task: Read .claude/epics/{epic}/$ARGUMENTS.md, then Edit as needed
   View epic: /pm:epic-show {epic}
```

### 8. Error Handling
- Handle invalid task numbers gracefully
- Check for missing files or directories
- Provide helpful error messages and alternatives

Provide comprehensive issue information to help developers understand context and current status for Issue #$ARGUMENTS.
