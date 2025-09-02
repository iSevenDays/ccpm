---
allowed-tools: Bash, Read, Write, LS
---

# Issue Analyze

Analyze an issue to identify parallel work streams for maximum efficiency.

## Usage
```
/pm:issue-analyze <issue_number>
```

## Quick Check

1. **Find local issue file:**
   - First check if `.claude/epics/*/$ARGUMENTS.md` exists (new naming convention)
   - If not found, search for file containing `local_id: $ARGUMENTS` in frontmatter (old naming)
   - If not found: "❌ No local issue for issue #$ARGUMENTS. Run: /pm:import first"

2. **Check for existing analysis:**
   ```bash
   test -f .claude/epics/*/$ARGUMENTS-analysis.md && echo "⚠️ Analysis already exists. Overwrite? (yes/no)"
   ```

## Instructions

**🎯 FOCUS: Use available tools efficiently - avoid excessive searching!**

**Available Tools:**
- `Read` - Read issue files directly
- `Write` - Create analysis file
- `Bash` - Get timestamps and paths
- `LS` - List directories when needed

### 1. Find and Read Issue File

**Direct approach - no extensive searching:**

```bash  
# Find issue file efficiently
find .claude/epics -name "$ARGUMENTS.md" -o -name "tasks/$ARGUMENTS.md" | head -1
```

Then read the issue file to understand:
- Technical requirements
- Acceptance criteria
- Dependencies
- Effort estimate

### 2. Identify Parallel Work Streams

Analyze the issue to identify independent work that can run in parallel:

**Common Patterns:**
- **Database Layer**: Schema, migrations, models
- **Service Layer**: Business logic, data access
- **API Layer**: Endpoints, validation, middleware
- **UI Layer**: Components, pages, styles
- **Test Layer**: Unit tests, integration tests
- **Documentation**: API docs, README updates

**Key Questions:**
- What files will be created/modified?
- Which changes can happen independently?
- What are the dependencies between changes?
- Where might conflicts occur?

### 3. Create Analysis File

**Use Write tool to create analysis file directly:**

```bash
# Get timestamp  
CURRENT_DATETIME=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
# Determine epic directory from issue file location
EPIC_DIR=$(dirname "$(find .claude/epics -name "$ARGUMENTS.md" | head -1)")
```

**Write analysis file with concrete streams (not templates):**

```markdown
---
issue: $ARGUMENTS
title: {issue_title}
analyzed: {current_datetime}
estimated_hours: {total_hours}
parallelization_factor: {1.0-5.0}
---

# Parallel Work Analysis: Issue #$ARGUMENTS

## Overview
{Brief description of what needs to be done}

## Parallel Streams

### Stream A: {Stream Name}
**Scope**: {What this stream handles}
**Files**:
- {file_pattern_1}
- {file_pattern_2}
**Agent Type**: {code-analyzer|file-analyzer|test-runner|parallel-worker}
**Can Start**: immediately
**Estimated Hours**: {hours}
**Dependencies**: none

### Stream B: {Stream Name}
**Scope**: {What this stream handles}
**Files**:
- {file_pattern_1}
- {file_pattern_2}
**Agent Type**: {agent_type}
**Can Start**: immediately
**Estimated Hours**: {hours}
**Dependencies**: none

### Stream C: {Stream Name}
**Scope**: {What this stream handles}
**Files**:
- {file_pattern_1}
**Agent Type**: {agent_type}
**Can Start**: after Stream A completes
**Estimated Hours**: {hours}
**Dependencies**: Stream A

## Coordination Points

### Shared Files
{List any files multiple streams need to modify}:
- `src/types/index.ts` - Streams A & B (coordinate type updates)
- `package.json` - Stream B (add dependencies)

### Sequential Requirements
{List what must happen in order}:
1. Database schema before API endpoints
2. API types before UI components
3. Core logic before tests

## Conflict Risk Assessment
- **Low Risk**: Streams work on different directories
- **Medium Risk**: Some shared type files, manageable with coordination
- **High Risk**: Multiple streams modifying same core files

## Parallelization Strategy

**Recommended Approach**: {sequential|parallel|hybrid}

{If parallel}: Launch Streams A, B simultaneously. Start C when A completes.
{If sequential}: Complete Stream A, then B, then C.
{If hybrid}: Start A & B together, C depends on A, D depends on B & C.

## Expected Timeline

With parallel execution:
- Wall time: {max_stream_hours} hours
- Total work: {sum_all_hours} hours
- Efficiency gain: {percentage}%

Without parallel execution:
- Wall time: {sum_all_hours} hours

## Notes
{Any special considerations, warnings, or recommendations}
```

### 4. Validate Analysis

Ensure:
- All major work is covered by streams
- File patterns don't unnecessarily overlap
- Dependencies are logical
- Agent types match the work type
- Time estimates are reasonable

### 5. Output

```
✅ Analysis complete for issue #$ARGUMENTS

Identified {count} parallel work streams:
  Stream A: {name} ({hours}h)
  Stream B: {name} ({hours}h)
  Stream C: {name} ({hours}h)
  
Parallelization potential: {factor}x speedup
  Sequential time: {total}h
  Parallel time: {reduced}h

Files at risk of conflict:
  {list shared files if any}

Next: Start work with /pm:issue-start $ARGUMENTS
```

## Important Notes

- Analysis is local only
- Focus on practical parallelization, not theoretical maximum
- Consider agent expertise when assigning streams
- Account for coordination overhead in estimates
- Prefer clear separation over maximum parallelization