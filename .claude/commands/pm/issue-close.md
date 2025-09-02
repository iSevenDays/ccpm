---
allowed-tools: Bash, Read, Write, LS
---

# Issue Close

Mark an issue as complete in the local PM system.

## Usage
```
/pm:issue-close <issue_number> [completion_notes]
```

## Instructions

### 1. Find Local Issue File

```bash
# Find issue file
issue_file=$(find .claude/epics -name "$ARGUMENTS.md" -o -name "*/$ARGUMENTS.md" | head -1)
if [ -z "$issue_file" ]; then
  echo "❌ No local issue file for #$ARGUMENTS"
  exit 1
fi
echo "Found issue file: $issue_file"
```

### 2. Update Local Status

```bash
# Get current datetime
current_datetime=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

# Update issue file status to closed
# Use Read/Write tools to update frontmatter with:
# status: closed
# updated: $current_datetime
echo "✅ Updated status to closed at: $current_datetime"
```

### 3. Update Progress File

```bash
# Extract epic directory
epic_dir=$(dirname "$issue_file")

# Check if progress file exists
progress_file="$epic_dir/updates/$ARGUMENTS/progress.md"
if [ -f "$progress_file" ]; then
  echo "✅ Updated progress file: $progress_file"
  # Set completion: 100%, add completion note with timestamp
else
  echo "ℹ️ No progress file found at: $progress_file"
fi
```

### 4. Update Epic Progress

```bash
# Extract epic name from file path
epic_name=$(basename "$epic_dir")

# Count total and closed tasks in epic (excluding epic.md and analysis files)
total_tasks=$(find "$epic_dir" -name "*.md" ! -name "epic.md" ! -name "*-analysis.md" | wc -l)
closed_tasks=$(find "$epic_dir" -name "*.md" -exec grep -l "status: closed" {} \; 2>/dev/null | wc -l)

# Calculate progress percentage
if [ $total_tasks -gt 0 ]; then
  progress=$((closed_tasks * 100 / total_tasks))
  echo "✅ Epic $epic_name progress: $progress% ($closed_tasks/$total_tasks tasks complete)"
else
  echo "ℹ️ No tasks found in epic: $epic_name"
fi
```

### 5. Output

```
✅ Closed issue #$ARGUMENTS
  File: $issue_file
  Status: closed
  Epic progress: $progress% ($closed_tasks/$total_tasks tasks complete)
  
Local update complete ✅
```

## Important Notes

Follow `/rules/frontmatter-operations.md` for updates.
Local-only operation - no GitHub sync required.