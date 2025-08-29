---
allowed-tools: Bash, Read, Write, LS
---

# Issue Progress Update

Update local progress tracking and create comprehensive progress summary.

## Usage
```
/pm:issue-sync <issue_number>
```

## Required Rules

**IMPORTANT:** Before executing this command, read and follow:
- `.claude/rules/datetime.md` - For getting real current date/time

## Preflight Checklist

Before proceeding, complete these validation steps.
Do not bother the user with preflight checks progress ("I'm not going to ..."). Just do them and move on.

1. **Local Updates Check:**
   - Check if `.claude/epics/*/updates/$ARGUMENTS/` directory exists
   - If not found, tell user: "❌ No local updates found for issue #$ARGUMENTS. Run: /pm:issue-start $ARGUMENTS"
   - Check if progress.md exists
   - If not, tell user: "❌ No progress tracking found. Initialize with: /pm:issue-start $ARGUMENTS"

2. **Check Last Update:**
   - Read `last_update` from progress.md frontmatter
   - If updated recently (< 5 minutes), ask: "⚠️ Recently updated. Force update anyway? (yes/no)"
   - Calculate what's new since last update

3. **Verify Changes:**
   - Check if there are actual updates to record
   - If no changes, tell user: "ℹ️ No new updates to record since {last_update}"
   - Exit gracefully if nothing to update

## Instructions

You are updating local development progress tracking for: **Issue #$ARGUMENTS**

### 1. Gather Local Updates
Collect all local updates for the issue:
- Read from `.claude/epics/{epic_name}/updates/$ARGUMENTS/`
- Check for new content in:
  - `progress.md` - Development progress
  - `notes.md` - Technical notes and decisions
  - `commits.md` - Recent commits and changes
  - Any other update files

### 2. Update Progress Tracking Frontmatter
Get current datetime: `date -u +"%Y-%m-%dT%H:%M:%SZ"`

Update the progress.md file frontmatter:
```yaml
---
issue: $ARGUMENTS
started: [preserve existing date]
last_update: [Use REAL datetime from command above]
completion: [calculated percentage 0-100%]
---
```

### 3. Determine What's New
Compare against previous update to identify new content:
- Look for update timestamp markers
- Identify new sections or updates
- Gather only incremental changes since last update

### 4. Create Progress Summary
Create comprehensive progress summary in local file:

```markdown
## 🔄 Progress Update - {current_date}

### ✅ Completed Work
{list_completed_items}

### 🔄 In Progress
{current_work_items}

### 📝 Technical Notes
{key_technical_decisions}

### 📊 Acceptance Criteria Status
- ✅ {completed_criterion}
- 🔄 {in_progress_criterion}
- ⏸️ {blocked_criterion}
- □ {pending_criterion}

### 🚀 Next Steps
{planned_next_actions}

### ⚠️ Blockers
{any_current_blockers}

### 💻 Recent Commits
{commit_summaries}

---
*Progress: {completion}% | Updated locally at {timestamp}*
```

### 5. Save Progress Summary
Write progress summary to local file:
```
.claude/epics/{epic_name}/updates/$ARGUMENTS/summary_{timestamp}.md
```

### 6. Update Local Task File
Get current datetime: `date -u +"%Y-%m-%dT%H:%M:%SZ"`

Update the task file frontmatter:
```yaml
---
name: [Task Title]
status: open
created: [preserve existing date]
updated: [Use REAL datetime from command above]
local_id: $ARGUMENTS
---
```

### 7. Handle Completion
If task is complete, update all relevant frontmatter:

**Task file frontmatter**:
```yaml
---
name: [Task Title]
status: closed
created: [existing date]
updated: [current date/time]
local_id: $ARGUMENTS
---
```

**Progress file frontmatter**:
```yaml
---
issue: $ARGUMENTS
started: [existing date]
last_update: [current date/time]
completion: 100%
---
```

**Epic progress update**: Recalculate epic progress based on completed tasks and update epic frontmatter:
```yaml
---
name: [Epic Name]
status: in-progress
created: [existing date]
progress: [calculated percentage based on completed tasks]%
prd: [existing path]
---
```

### 8. Completion Summary
If task is complete, create completion summary:
```markdown
## ✅ Task Completed - {current_date}

### 🎯 All Acceptance Criteria Met
- ✅ {criterion_1}
- ✅ {criterion_2}
- ✅ {criterion_3}

### 📦 Deliverables
- {deliverable_1}
- {deliverable_2}

### 🧪 Testing
- Unit tests: ✅ Passing
- Integration tests: ✅ Passing
- Manual testing: ✅ Complete

### 📚 Documentation
- Code documentation: ✅ Updated
- README updates: ✅ Complete

This task is ready for review and can be closed.

---
*Task completed: 100% | Updated locally at {timestamp}*
```

### 9. Output Summary
```
📝 Updated local progress for Issue #$ARGUMENTS

📝 Update summary:
   Progress items: {progress_count}
   Technical notes: {notes_count}
   Commits referenced: {commit_count}

📊 Current status:
   Task completion: {task_completion}%
   Epic progress: {epic_progress}%
   Completed criteria: {completed}/{total}

💾 Summary saved to: .claude/epics/{epic_name}/updates/$ARGUMENTS/summary_{timestamp}.md
```

### 10. Frontmatter Maintenance
- Always update task file frontmatter with current timestamp
- Track completion percentages in progress files
- Update epic progress when tasks complete
- Maintain update timestamps for audit trail

### 11. Incremental Update Detection

**Prevent Duplicate Updates:**
1. Add update markers to local files after each update:
   ```markdown
   <!-- UPDATED: 2024-01-15T10:30:00Z -->
   ```
2. Only record content added after the last marker
3. If no new content, skip update with message: "No updates since last update"

### 12. Summary File Management

**Local Summary Organization:**
- Create timestamped summary files for each update
- Keep summary files organized by issue/task
- Maintain chronological order for tracking progress over time
- Clean up old summaries periodically (keep last 10 updates)

### 13. Error Handling

**Common Issues and Recovery:**

1. **File System Error:**
   - Message: "❌ Failed to write summary file: permission error"
   - Solution: "Check file system permissions"
   - Keep progress in memory for retry

2. **Disk Space:**
   - Message: "❌ Insufficient disk space for summary"
   - Solution: "Free up disk space or clean old summaries"
   - Warn about storage limits

3. **File Locked:**
   - Message: "❌ Cannot write to file (file locked)"
   - Solution: "Close other applications using the file"

### 14. Epic Progress Calculation

When updating epic progress:
1. Count total tasks in epic directory
2. Count tasks with `status: closed` in frontmatter
3. Calculate: `progress = (closed_tasks / total_tasks) * 100`
4. Round to nearest integer
5. Update epic frontmatter only if percentage changed

### 15. Post-Update Validation

After successful update:
- [ ] Verify summary file created successfully
- [ ] Confirm frontmatter updated with update timestamp
- [ ] Check epic progress updated if task completed
- [ ] Validate no data corruption in local files

This creates a comprehensive local audit trail of development progress for Issue #$ARGUMENTS, maintaining accurate tracking across all project files without external dependencies.
