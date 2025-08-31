---
allowed-tools: Bash, Read, Write, LS, Task
---

# Epic Start

Launch parallel agents to work on epic tasks in a shared branch.

## Usage
```
/pm:epic-start <epic_name>
```

## Quick Check

1. **Verify epic exists:**
   ```bash
   test -f .claude/epics/$ARGUMENTS/epic.md || echo "❌ Epic not found. Run: /pm:prd-parse $ARGUMENTS"
   ```

2. **Check for branch:**
   ```bash
   git branch -a | grep "epic/$ARGUMENTS"
   ```

3. **Check for uncommitted changes in work repo:**
   ```bash
   # Run from project root, not .claude directory
   cd "$(git rev-parse --show-toplevel)"
   git status --porcelain
   ```
   If output is not empty: "❌ You have uncommitted changes. Commit them (git add . && git commit -m \"msg\") or stash them (git stash push -m \"work in progress\") before starting the epic."

## Instructions

### 1. Create or Enter Branch

Follow `/rules/branch-operations.md`:

```bash
# Check for uncommitted changes in work repository (not .claude repo)
work_root=$(git rev-parse --show-toplevel)
cd "$work_root"
if [ -n "$(git status --porcelain)" ]; then
  echo "❌ You have uncommitted changes. Commit them (git add . && git commit -m \"msg\") or stash them (git stash push -m \"work in progress\") before starting the epic."
  exit 1
fi

# If branch doesn't exist, create it
if ! git branch -a | grep -q "epic/$ARGUMENTS"; then
  git checkout main
  git pull origin main
  git checkout -b epic/$ARGUMENTS
  # IMPORTANT: git push is prohibited
  echo "✅ Created branch: epic/$ARGUMENTS"
else
  git checkout epic/$ARGUMENTS
  git pull origin epic/$ARGUMENTS
  echo "✅ Using existing branch: epic/$ARGUMENTS"
fi
```

### 2. Identify Ready Tasks

Read all task files in `.claude/epics/$ARGUMENTS/`:
- Parse frontmatter for `status`, `depends_on`, `parallel` fields
- Build dependency graph

Categorize tasks:
- **Ready**: No unmet dependencies, not started
- **Blocked**: Has unmet dependencies
- **In Progress**: Already being worked on
- **Complete**: Finished

### 3. Analyze Ready Tasks

For each ready task without analysis:
```bash
# Check for analysis
if ! test -f .claude/epics/$ARGUMENTS/{task}-analysis.md; then
  echo "Analyzing task #{task}..."
  # Run analysis (inline or via Task tool)
fi
```

### 4. Launch Parallel Agents

For each ready task with analysis:

```markdown
## Starting Task #{task}: {title}

Reading analysis...
Found {count} parallel streams:
  - Stream A: {description} (Agent-{id})
  - Stream B: {description} (Agent-{id})

Launching agents in branch: epic/$ARGUMENTS
```

Use Task tool to launch each stream:
```yaml
Task:
  description: "Task #{task} Stream {X}"
  subagent_type: "{agent_type}"
  prompt: |
    Working in branch: epic/$ARGUMENTS
    Issue: #{task} - {title}
    Stream: {stream_name}

    Your scope:
    - Files: {file_patterns}
    - Work: {stream_description}

    Read full requirements from:
    - .claude/epics/$ARGUMENTS/{task_file}
    - .claude/epics/$ARGUMENTS/{task}-analysis.md

    Follow coordination rules in /rules/agent-coordination.md
    Commit frequently with message format:
    "Task #{task}: {specific change}"

    Update progress in:
    .claude/epics/$ARGUMENTS/updates/{task}/stream-{X}.md
```

### 5. Track Active Agents

Create/update `.claude/epics/$ARGUMENTS/execution-status.md`:

```markdown
---
started: {datetime}
branch: epic/$ARGUMENTS
---

# Execution Status

## Active Agents
- Agent-1: Task #1234 Stream A (Database) - Started {time}
- Agent-2: Task #1234 Stream B (API) - Started {time}
- Agent-3: Task #1235 Stream A (UI) - Started {time}

## Queued Tasks
- Task #1236 - Waiting for #1234
- Task #1237 - Waiting for #1235

## Completed
- {None yet}
```

### 6. Monitor and Coordinate

Set up monitoring:
```bash
echo "
Agents launched successfully!

Monitor progress:
  /pm:epic-status $ARGUMENTS

View branch changes:
  git status

Stop all agents:
  /pm:epic-stop $ARGUMENTS

Merge when complete:
  /pm:epic-merge $ARGUMENTS
"
```

### 7. Handle Dependencies

As agents complete streams:
- Check if any blocked tasks are now ready
- Launch new agents for newly-ready work
- Update execution-status.md

## Output Format

```
🚀 Epic Execution Started: $ARGUMENTS

Branch: epic/$ARGUMENTS

Launching {total} agents across {task_count} issues:

Task #1234: Database Schema
  ├─ Stream A: Schema creation (Agent-1) ✓ Started
  └─ Stream B: Migrations (Agent-2) ✓ Started

Task #1235: API Endpoints
  ├─ Stream A: User endpoints (Agent-3) ✓ Started
  ├─ Stream B: Post endpoints (Agent-4) ✓ Started
  └─ Stream C: Tests (Agent-5) ⏸ Waiting for A & B

Blocked Tasks (2):
  - #1236: UI Components (depends on #1234)
  - #1237: Integration (depends on #1235, #1236)

Monitor with: /pm:epic-status $ARGUMENTS
```

## Error Handling

If agent launch fails:
```
❌ Failed to start Agent-{id}
  Issue: #{task}
  Stream: {stream}
  Error: {reason}

Continue with other agents? (yes/no)
```

If uncommitted changes are found:
```
❌ You have uncommitted changes. Please commit or stash them before starting an epic.

To commit changes:
  git add .
  git commit -m "Your commit message"

To stash changes:
  git stash push -m "Work in progress"
  # (Later restore with: git stash pop)
```

If branch creation fails:
```
❌ Cannot create branch
  {git error message}

Try: git branch -d epic/$ARGUMENTS
Or: Check existing branches with: git branch -a
```

## Important Notes

- Follow `/rules/branch-operations.md` for git operations
- Follow `/rules/agent-coordination.md` for parallel work
- Agents work in the SAME branch (not separate branches)
- Maximum parallel agents should be reasonable (e.g., 5-10)
- Monitor system resources if launching many agents
