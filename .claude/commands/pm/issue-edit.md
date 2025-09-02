---
allowed-tools: Bash, Read, Write, LS
---

# Issue Edit

Edit local issue details.

## Usage
```
/pm:issue-edit <issue_number>
```

## Instructions

### 1. Find Local Issue File

```bash
# Find issue file (following issue-start.md pattern)
issue_file=$(find .claude/epics -name "$ARGUMENTS.md" -o -name "*/$ARGUMENTS.md" | head -1)
if [ -z "$issue_file" ]; then
  echo "❌ No local issue file for #$ARGUMENTS"
  exit 1
fi
echo "Found issue file: $issue_file"
```

### 2. Interactive Edit

Ask user what to edit:
- Name/Title (frontmatter `name` field)
- Description (markdown body)
- Status (frontmatter `status` field)
- Priority (frontmatter `priority` field)

### 3. Update Local File

```bash
# Get current datetime
current_datetime=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

# Update frontmatter `updated` field
# Apply user changes to name, body, status, etc.
# Use Read/Write tools to modify the issue file
```

### 4. Save Changes

```bash
# Write updated content back to issue file
# Preserve all frontmatter fields except those being updated
# Update the `updated` timestamp
echo "✅ Updated issue file: $issue_file"
```

### 5. Output

```
✅ Updated issue #$ARGUMENTS
  File: $issue_file
  Changes:
    {list_of_changes_made}
  
Local update complete: ✅
```

## Important Notes

Preserve frontmatter fields not being edited.
Follow `/rules/frontmatter-operations.md`.
Local-only operation - no GitHub sync.