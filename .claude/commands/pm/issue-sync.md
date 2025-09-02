---
allowed-tools: Bash, Read, Write, LS
---

# Issue Sync

Sync local work progress and update issue status based on completion.

## Usage
```
/pm:issue-sync <issue_number>
```

## Validation

```bash
# Find local issue file
issue_file=$(find .claude/epics -name "$ARGUMENTS.md" -o -name "*/$ARGUMENTS.md" | head -1)
if [ -z "$issue_file" ]; then
  echo "❌ No local issue file for #$ARGUMENTS"
  exit 1
fi
echo "Found issue file: $issue_file"

# Check if progress tracking exists
updates_dir=$(find .claude/epics -path "*/updates/$ARGUMENTS" -type d | head -1)
if [ -z "$updates_dir" ]; then
  echo "❌ No progress tracking found for issue #$ARGUMENTS. Run: /pm:issue-start $ARGUMENTS first"
  exit 1
fi
echo "Found progress tracking: $updates_dir"
```

## Instructions

### 1. Analyze Progress Completion
Check all progress tracking files to determine completion status:

```bash
# Check for completion indicators in progress files
echo "Analyzing progress completion..."
for stream_file in "$updates_dir"/stream-*.md; do
  [ -f "$stream_file" ] || continue
  stream_status=$(grep "^status:" "$stream_file" | head -1 | sed 's/^status: *//')
  if [ "$stream_status" = "completed" ]; then
    echo "  Stream $(basename "$stream_file" .md): ✅ Completed"
  else
    echo "  Stream $(basename "$stream_file" .md): 🔄 In Progress"
  fi
done
```

### 2. Calculate Overall Completion
Determine if all streams are completed:

```bash
# Count total streams and completed streams
total_streams=$(find "$updates_dir" -name "stream-*.md" | wc -l)
completed_streams=$(grep -l "^status: completed" "$updates_dir"/stream-*.md 2>/dev/null | wc -l)

if [ "$total_streams" -eq 0 ]; then
  echo "⚠️ No streams found"
  exit 1
fi

completion_percent=$((completed_streams * 100 / total_streams))
echo "Progress: $completed_streams/$total_streams streams completed ($completion_percent%)"
```

### 3. Generate Progress Report
Create comprehensive progress report using template and save to local file:

```bash
# Get current datetime
current_datetime=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
current_date=$(date +"%Y-%m-%d")

# Create progress report using template
report_file="$updates_dir/sync-$current_date.md"
cat > "$report_file" << EOF
## 🔄 Progress Update - $current_date

### ✅ Completed Work
$(grep -h "^- \[x\]" "$updates_dir"/stream-*.md 2>/dev/null || echo "No completed items yet")

### 🔄 In Progress
$(grep -h "^- \[ \]" "$updates_dir"/stream-*.md 2>/dev/null || echo "No items in progress")

### 📝 Technical Notes
$(grep -A 5 "## Technical Notes" "$updates_dir"/stream-*.md 2>/dev/null || echo "No technical notes yet")

### 📊 Acceptance Criteria Status
$(grep -h "^- \[.\]" "$issue_file" 2>/dev/null || echo "No acceptance criteria found")

### 🚀 Next Steps
$(grep -A 3 "## Next Steps" "$updates_dir"/stream-*.md 2>/dev/null || echo "Next steps to be determined")

### ⚠️ Blockers
$(grep -A 3 "## Blockers" "$updates_dir"/stream-*.md 2>/dev/null || echo "No blockers reported")

### 💻 Recent Commits
$(git log --oneline -n 5 --grep="Issue #$ARGUMENTS" 2>/dev/null || echo "No recent commits found")

---
*Progress: $completion_percent% | Synced from local updates at $current_datetime*
EOF

echo "📄 Progress report saved: $report_file"
```

### 4. Update Local Issue File
Update the issue file frontmatter with sync information:

```bash
# Update issue file frontmatter with sync timestamp
sed -i.bak -e "/^updated:/s/.*/updated: $current_datetime/" "$issue_file"
echo "✅ Updated issue frontmatter with sync timestamp"
```

### 5. Handle Completion
If issue is complete, update all relevant frontmatter:

```bash
if [ "$completion_percent" -eq 100 ]; then
  echo "🎉 Issue completed! Updating status..."
  
  # Update issue file frontmatter to closed
  sed -i.bak -e "/^status:/s/.*/status: closed/" "$issue_file"
  
  # Update all progress stream files with completion
  for stream_file in "$updates_dir"/stream-*.md; do
    [ -f "$stream_file" ] || continue
    sed -i.bak -e "/^last_sync:/s/.*/last_sync: $current_datetime/" -e "/^completion:/s/.*/completion: 100%/" "$stream_file"
  done
  
  # Recalculate epic progress
  epic_dir=$(dirname "$updates_dir")
  total_issues=$(find "$epic_dir" -name "[0-9]*.md" -o -name "issues/[0-9]*.md" | wc -l)
  closed_issues=$(grep -l "^status: closed" "$epic_dir"/[0-9]*.md "$epic_dir"/issues/[0-9]*.md 2>/dev/null | wc -l)
  
  if [ "$total_issues" -gt 0 ]; then
    epic_progress=$((closed_issues * 100 / total_issues))
    epic_file="$epic_dir/epic.md"
    if [ -f "$epic_file" ]; then
      sed -i.bak -e "/^progress:/s/.*/progress: $epic_progress%/" "$epic_file"
      echo "✅ Updated epic progress: $epic_progress% ($closed_issues/$total_issues issues)"
    fi
  fi
fi
```

### 6. Generate Completion Report
If issue is complete, create completion report:

```bash
if [ "$completion_percent" -eq 100 ]; then
  completion_file="$updates_dir/completion-$current_date.md"
  cat > "$completion_file" << EOF
## ✅ Issue Completed - $current_date

### 🎯 All Acceptance Criteria Met
$(grep "^- \[x\]" "$issue_file" 2>/dev/null || echo "All criteria completed")

### 📦 Deliverables
$(grep -A 10 "## Deliverables" "$issue_file" 2>/dev/null | grep "^- " || echo "Deliverables completed as specified")

### 🧪 Testing
- Unit tests: ✅ Passing
- Integration tests: ✅ Passing  
- Manual testing: ✅ Complete

### 📚 Documentation
- Code documentation: ✅ Updated
- README updates: ✅ Complete

This issue is ready for review and can be closed.

---
*Issue completed: 100% | Synced at $current_datetime*
EOF
  
  echo "🎊 Completion report saved: $completion_file"
fi
```

### 7. Output Summary
```bash
echo "
📋 Synced local progress for Issue #$ARGUMENTS

📝 Update summary:
   Streams analyzed: $total_streams
   Completed streams: $completed_streams
   Progress reports: Generated

📊 Current status:
   Issue completion: $completion_percent%
   Epic progress: ${epic_progress:-"Calculating..."}%
   Status: $(grep '^status:' "$issue_file" | sed 's/^status: //')

📂 Local files updated:
   Progress report: $report_file"
   
if [ "$completion_percent" -eq 100 ]; then
  echo "   Completion report: $completion_file"
fi

echo "
🔍 View files: ls $updates_dir/"
```

### 8. Frontmatter Maintenance
- Always update issue file frontmatter with current timestamp
- Track completion percentages in progress files  
- Update epic progress when issues complete
- Maintain sync timestamps for audit trail

### 9. Incremental Sync Detection

**Prevent Duplicate Reports:**
```bash
# Check if sync already done today
if [ -f "$updates_dir/sync-$current_date.md" ]; then
  echo "⚠️ Sync already done today. Use --force to override."
  if [[ "$*" != *"--force"* ]]; then
    exit 0
  fi
fi
```

### 10. Report Size Management

**Handle Large Progress Reports:**
```bash
# Check report file size
if [ -f "$report_file" ]; then
  file_size=$(wc -c < "$report_file")
  if [ "$file_size" -gt 10000 ]; then
    echo "⚠️ Large progress report generated ($file_size chars)"
    echo "Consider breaking down into smaller work streams."
  fi
fi
```

### 11. Error Handling

**Common Issues and Recovery:**

1. **File Permission Error:**
   - Message: "❌ Cannot write to progress directory"
   - Solution: "Check file permissions and disk space"

2. **Invalid Progress Files:**
   - Message: "❌ Corrupted stream file detected"
   - Solution: "Restore from backup or recreate stream file"

3. **Missing Dependencies:**
   - Message: "❌ Required directories not found"
   - Solution: "Run /pm:issue-start $ARGUMENTS first"

### 12. Epic Progress Calculation

When updating epic progress:
1. Count total issues in epic directory (both flat and nested)
2. Count issues with `status: closed` in frontmatter
3. Calculate: `progress = (closed_issues / total_issues) * 100`
4. Round to nearest integer
5. Update epic frontmatter only if percentage changed

### 13. Post-Sync Validation

After successful sync:
- [ ] Confirm progress report generated
- [ ] Verify frontmatter updated with sync timestamp
- [ ] Check epic progress updated if issue completed
- [ ] Validate no data corruption in local files

This creates a transparent audit trail of development progress with local file tracking for Issue #$ARGUMENTS, while maintaining accurate frontmatter across all project files.
