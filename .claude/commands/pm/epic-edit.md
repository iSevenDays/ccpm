---
allowed-tools: Read, Write, LS
---

# Epic Edit

Edit epic details after creation.

## Usage
```
/pm:epic-edit <epic_name>
```

## Instructions

### 1. Read Current Epic

Read `.claude/epics/$ARGUMENTS/epic.md`:
- Parse frontmatter
- Read content sections

### 2. Interactive Edit

Ask user what to edit:
- Name/Title
- Description/Overview
- Architecture decisions
- Technical approach
- Dependencies
- Success criteria

### 3. Update Epic File

Get current datetime: `date -u +"%Y-%m-%dT%H:%M:%SZ"`

Update epic.md:
- Preserve all frontmatter except `updated`
- Apply user's edits to content
- Update `updated` field with current datetime

### 4. Update Local Tracking

Update epic progress and status:
- Recalculate completion percentage based on tasks
- Update epic summary if needed
- Refresh local tracking files

### 5. Output

```
✅ Updated epic: $ARGUMENTS
  Changes made to: {sections_edited}
  
Local tracking updated ✅

View epic: /pm:epic-show $ARGUMENTS
```

## Important Notes

Preserve frontmatter history (created, github URL, etc.).
Don't change task files when editing epic.
Follow `/rules/frontmatter-operations.md`.