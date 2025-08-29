---
allowed-tools: Bash, Read, Write, LS, Task
---

# Epic Summary

Generate comprehensive local epic and task summary.

## Usage
```
/pm:epic-summary <feature_name>
```

## Quick Check

```bash
# Verify epic exists
test -f .claude/epics/$ARGUMENTS/epic.md || echo "❌ Epic not found. Run: /pm:prd-parse $ARGUMENTS"

# Count task files
ls .claude/epics/$ARGUMENTS/*.md 2>/dev/null | grep -v epic.md | wc -l
```

If no tasks found: "❌ No tasks to summarize. Run: /pm:epic-decompose $ARGUMENTS"

## Instructions

### 1. Create Epic Summary

Generate local epic summary with current statistics:

```bash
# Extract content without frontmatter
sed '1,/^---$/d; 1,/^---$/d' .claude/epics/$ARGUMENTS/epic.md > /tmp/epic-body-raw.md

# Count tasks and gather statistics
task_count=$(ls .claude/epics/$ARGUMENTS/*.md 2>/dev/null | grep -v epic.md | wc -l | tr -d ' ')
parallel_count=$(grep -l "parallel:.*true" .claude/epics/$ARGUMENTS/*.md 2>/dev/null | wc -l | tr -d ' ')
sequential_count=$((task_count - parallel_count))
completed_count=$(grep -l "status: closed" .claude/epics/$ARGUMENTS/*.md 2>/dev/null | wc -l | tr -d ' ')
in_progress_count=$(grep -l "status: in-progress" .claude/epics/$ARGUMENTS/*.md 2>/dev/null | wc -l | tr -d ' ')
blocked_count=$(grep -l "status: blocked" .claude/epics/$ARGUMENTS/*.md 2>/dev/null | wc -l | tr -d ' ')

if [ $task_count -gt 0 ]; then
  completion_percent=$((completed_count * 100 / task_count))
else
  completion_percent=0
fi

# Create timestamp for summary
timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

# Create enhanced epic summary with current stats
cat > /tmp/epic-summary.md << EOF
# Epic Summary: $ARGUMENTS
**Generated:** $timestamp

## Epic Statistics

- **Total tasks:** $task_count
- **Completed tasks:** $completed_count ($completion_percent%)
- **In progress tasks:** $in_progress_count
- **Blocked tasks:** $blocked_count
- **Remaining tasks:** $((task_count - completed_count))
- **Parallel tasks:** $parallel_count (can be worked simultaneously)
- **Sequential tasks:** $sequential_count (have dependencies)

## Epic Progress
$([[ $completion_percent -lt 25 ]] && echo "🔴 Just Starting" || [[ $completion_percent -lt 50 ]] && echo "🟡 In Progress" || [[ $completion_percent -lt 75 ]] && echo "🟠 Well Underway" || [[ $completion_percent -lt 100 ]] && echo "🟢 Nearly Complete" || echo "✅ Complete")

Progress: $completion_percent% [$([[ $completed_count -gt 0 ]] && printf "%0.s█" $(seq 1 $((completion_percent / 10))))$([[ $((completion_percent % 10)) -gt 0 ]] && echo "▌")$([[ $completion_percent -lt 100 ]] && printf "%0.s░" $(seq 1 $((10 - completion_percent / 10))))]

---

EOF

# Append original epic content
cat /tmp/epic-body-raw.md >> /tmp/epic-summary.md
```

### 2. Generate Task Summaries

```bash
# Create task summary directory
mkdir -p ".claude/epics/$ARGUMENTS/summaries"
summary_file=".claude/epics/$ARGUMENTS/summaries/epic-summary-$timestamp.md"

# Copy epic summary to file
cp /tmp/epic-summary.md "$summary_file"

# Add task details section
echo "" >> "$summary_file"
echo "## Task Breakdown" >> "$summary_file"
echo "" >> "$summary_file"

# Process each task file
for task_file in .claude/epics/$ARGUMENTS/[0-9][0-9][0-9].md; do
  [ -f "$task_file" ] || continue
  
  # Extract task metadata
  task_name=$(grep '^name:' "$task_file" | sed 's/^name: *//')
  task_status=$(grep '^status:' "$task_file" | sed 's/^status: *//' || echo "open")
  task_priority=$(grep '^priority:' "$task_file" | sed 's/^priority: *//' || echo "medium")
  task_effort=$(grep '^effort:' "$task_file" | sed 's/^effort: *//' || echo "unknown")
  
  # Get task number from filename
  task_num=$(basename "$task_file" .md)
  
  # Add task to summary with status emoji
  status_emoji=""
  case "$task_status" in
    "completed"|"closed") status_emoji="✅" ;;
    "in-progress"|"active") status_emoji="🔄" ;;
    "blocked") status_emoji="🔴" ;;
    "pending"|"open") status_emoji="⏸️" ;;
    *) status_emoji="🔘" ;;
  esac
  
  priority_emoji=""
  case "$task_priority" in
    "high"|"critical") priority_emoji="🔴" ;;
    "medium") priority_emoji="🟡" ;;
    "low") priority_emoji="🟢" ;;
    *) priority_emoji="⚪" ;;
  esac
  
  echo "### $status_emoji Task $task_num: $task_name" >> "$summary_file"
  echo "" >> "$summary_file"
  echo "| Property | Value |" >> "$summary_file"
  echo "|----------|-------|" >> "$summary_file"
  echo "| **Status** | $task_status |" >> "$summary_file"
  echo "| **Priority** | $priority_emoji $task_priority |" >> "$summary_file"
  echo "| **Effort** | $task_effort |" >> "$summary_file"
  echo "| **File** | \`$task_file\` |" >> "$summary_file"
  echo "" >> "$summary_file"
  
  # Add task description (first paragraph after frontmatter)
  task_desc=$(sed '1,/^---$/d; 1,/^---$/d; /^$/d; q' "$task_file")
  if [ -n "$task_desc" ]; then
    echo "**Description:** $task_desc" >> "$summary_file"
    echo "" >> "$summary_file"
  fi
  
  # Add dependencies if any
  depends_on=$(grep '^depends_on:' "$task_file" | sed 's/^depends_on: *//')
  if [ -n "$depends_on" ]; then
    echo "**Dependencies:** $depends_on" >> "$summary_file"
    echo "" >> "$summary_file"
  fi
  
  echo "---" >> "$summary_file"
  echo "" >> "$summary_file"
done
```

### 3. Generate Progress Report

```bash
# Add progress timeline to summary
echo "## Progress Timeline" >> "$summary_file"
echo "" >> "$summary_file"

# Find recently completed tasks (last 7 days)
recent_completed=$(find .claude/epics/$ARGUMENTS -name "*.md" -exec grep -l "status: closed\|status: completed" {} \; | xargs ls -lt 2>/dev/null | head -5)

if [ -n "$recent_completed" ]; then
  echo "### Recent Completions" >> "$summary_file"
  echo "$recent_completed" | while read -r line; do
    file_path=$(echo "$line" | awk '{print $NF}')
    if [[ "$file_path" =~ [0-9][0-9][0-9]\.md$ ]]; then
      task_name=$(grep '^name:' "$file_path" | sed 's/^name: *//')
      echo "- ✅ **$task_name**" >> "$summary_file"
    fi
  done
  echo "" >> "$summary_file"
fi

# Add next up tasks
echo "### Next Up (Open Tasks by Priority)" >> "$summary_file"
echo "" >> "$summary_file"

# Find high priority open tasks
high_priority_tasks=""
for task_file in .claude/epics/$ARGUMENTS/[0-9][0-9][0-9].md; do
  [ -f "$task_file" ] || continue
  if grep -q "status: open\|status: pending" "$task_file" && grep -q "priority: high\|priority: critical" "$task_file"; then
    task_name=$(grep '^name:' "$task_file" | sed 's/^name: *//')
    task_num=$(basename "$task_file" .md)
    echo "- 🔴 **Task $task_num:** $task_name" >> "$summary_file"
  fi
done

# Find medium priority open tasks
for task_file in .claude/epics/$ARGUMENTS/[0-9][0-9][0-9].md; do
  [ -f "$task_file" ] || continue
  if grep -q "status: open\|status: pending" "$task_file" && grep -q "priority: medium" "$task_file"; then
    task_name=$(grep '^name:' "$task_file" | sed 's/^name: *//')
    task_num=$(basename "$task_file" .md)
    echo "- 🟡 **Task $task_num:** $task_name" >> "$summary_file"
  fi
done

echo "" >> "$summary_file"

# Add blockers if any
blocked_tasks=""
for task_file in .claude/epics/$ARGUMENTS/[0-9][0-9][0-9].md; do
  [ -f "$task_file" ] || continue
  if grep -q "status: blocked" "$task_file"; then
    task_name=$(grep '^name:' "$task_file" | sed 's/^name: *//')
    task_num=$(basename "$task_file" .md)
    blocked_tasks="$blocked_tasks- ⛔ **Task $task_num:** $task_name\n"
  fi
done

if [ -n "$blocked_tasks" ]; then
  echo "### ⚠️ Blocked Tasks" >> "$summary_file"
  echo "" >> "$summary_file"
  echo -e "$blocked_tasks" >> "$summary_file"
  echo "" >> "$summary_file"
fi
```

### 4. Update Epic Frontmatter

```bash
# Get current datetime for epic update
current_time=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

# Update epic frontmatter with current progress
# Read current frontmatter
epic_frontmatter=$(sed -n '1,/^---$/p' .claude/epics/$ARGUMENTS/epic.md | head -n -1)

# Update or add progress field
if grep -q "^progress:" .claude/epics/$ARGUMENTS/epic.md; then
  # Replace existing progress
  sed -i.bak "s/^progress:.*/progress: ${completion_percent}%/" .claude/epics/$ARGUMENTS/epic.md
else
  # Add progress after existing fields
  sed -i.bak "/^---$/i\\
progress: ${completion_percent}%" .claude/epics/$ARGUMENTS/epic.md
fi

# Update last_summary field
if grep -q "^last_summary:" .claude/epics/$ARGUMENTS/epic.md; then
  sed -i.bak "s/^last_summary:.*/last_summary: $current_time/" .claude/epics/$ARGUMENTS/epic.md
else
  sed -i.bak "/^---$/i\\
last_summary: $current_time" .claude/epics/$ARGUMENTS/epic.md
fi

# Clean up backup file
rm -f .claude/epics/$ARGUMENTS/epic.md.bak
```

### 5. Output Summary

```bash
echo ""
echo "📊 Epic Summary Generated!"
echo "========================="
echo ""
echo "📝 Summary details:"
echo "   Epic: $ARGUMENTS"
echo "   Total tasks: $task_count"
echo "   Completed: $completed_count ($completion_percent%)"
echo "   In progress: $in_progress_count"
echo "   Blocked: $blocked_count"
echo ""
echo "📊 Current status:"
echo "   Epic progress: $completion_percent%"
echo "   Status: $([[ $completion_percent -lt 25 ]] && echo "Just Starting" || [[ $completion_percent -lt 50 ]] && echo "In Progress" || [[ $completion_percent -lt 75 ]] && echo "Well Underway" || [[ $completion_percent -lt 100 ]] && echo "Nearly Complete" || echo "Complete")"
echo ""
echo "💾 Summary saved to: $summary_file"
echo "📄 View summary: cat \"$summary_file\""
echo ""
```

### 6. Cleanup

```bash
# Clean up temporary files
rm -f /tmp/epic-body-raw.md /tmp/epic-summary.md
```

This creates a comprehensive local epic and task summary without any external dependencies, providing complete visibility into project progress and status.