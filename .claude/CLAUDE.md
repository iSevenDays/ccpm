# CLAUDE.md

> Think carefully and implement the most concise solution that changes as little code as possible.

## USE SUB-AGENTS FOR CONTEXT OPTIMIZATION

### 1. Always use the file-analyzer sub-agent when asked to read files.
The file-analyzer agent is an expert in extracting and summarizing critical information from files, particularly log files and verbose outputs. It provides concise, actionable summaries that preserve essential information while dramatically reducing context usage.

### 2. Always use the code-analyzer sub-agent when asked to search code, analyze code, research bugs, or trace logic flow.

The code-analyzer agent is an expert in code analysis, logic tracing, and vulnerability detection. It provides concise, actionable summaries that preserve essential information while dramatically reducing context usage.

### 3. Always use the test-runner sub-agent to run tests and analyze the test results.

Using the test-runner agent ensures:

- Full test output is captured for debugging
- Main conversation stays clean and focused
- Context usage is optimized
- All issues are properly surfaced
- No approval dialogs interrupt the workflow

## Philosophy

### Error Handling

- **Fail fast** for critical configuration (missing text model)
- **Log and continue** for optional features (extraction model)
- **Graceful degradation** when external services unavailable
- **User-friendly messages** through resilience layer

### Testing

- Always use the test-runner agent to execute tests.
- Do not use mock services for anything ever.
- Do not move on to the next test until the current test is complete.
- If the test fails, consider checking if the test is structured correctly before deciding we need to refactor the codebase.
- Tests to be verbose so we can use them for debugging.


## Tone and Behavior

- Criticism is welcome. Please tell me when I am wrong or mistaken, or even when you think I might be wrong or mistaken.
- Please tell me if there is a better approach than the one I am taking.
- Please tell me if there is a relevant standard or convention that I appear to be unaware of.
- Be skeptical.
- Be concise.
- Short summaries are OK, but don't give an extended breakdown unless we are working through the details of a plan.
- Do not flatter, and do not give compliments unless I am specifically asking for your judgement.
- Occasional pleasantries are fine.
- Feel free to ask many questions. If you are in doubt of my intent, don't guess. Ask.

Follow SPARC Framework rules and best practices.

## PM System Architecture

### Core Entities
- **PRDs**: Product Requirements Documents in `.claude/epics/{name}/epic.md`
- **Issues**: Individual work items in flat or nested structure:
  - Flat: `.claude/epics/{epic_name}/{issue_id}.md`
  - Nested: `.claude/epics/{epic_name}/issues/{issue_id}.md`
- **Analysis Files**: Parallel work streams in `{issue_id}-analysis.md`
- **Progress Tracking**: Stream updates in `updates/{issue_id}/stream-{X}.md`

### Directory Structure Validation
- Support both flat and nested issue organization
- Analysis files must be co-located with issue files
- Progress tracking follows: `.claude/epics/{epic_name}/updates/{issue_id}/`

### Status Management Workflows

**Status Transitions:**
- **PRDs**: `backlog` → `in-progress` → `complete`
- **Epics**: `backlog` → `in-progress` → `completed`  
- **Issues**: `open` → `in-progress` → `closed`

**Frontmatter Update Patterns:**
- Always preserve existing frontmatter fields
- Update `status` and `updated` fields atomically
- Calculate epic progress: `(closed_issues / total_issues) * 100`
- Sync timestamps follow ISO format from `/rules/datetime.md`

## Agent Coordination for Parallel Work

### 4. Always use parallel agents for PM system work
When working with issues that have analysis files, launch specialized agents for each work stream:

Template pattern for parallel agent launch:
```yaml
Task:
  description: "Issue #{issue_number} Stream {stream_id}"
  subagent_type: "{parsed_agent_type}"
  prompt: |
    Working in branch: epic/{epic_name}
    Issue: #{issue_number}
    Stream: {parsed_stream_name}
    
    Your scope:
    - Files: {parsed_file_patterns}
    - Work: {parsed_stream_description}
```

### Template Variable Parsing
- Always validate analysis file exists and is readable
- Extract stream sections using sed patterns
- Provide fallback values for missing template variables
- Export parsed values as environment variables for Task calls

Common parsing patterns:
```bash
# Extract stream section with boundary handling
stream_section=$(sed -n "/### Stream $stream_id:/,/### Stream [A-Z]:/p" "$analysis_file" | head -n -1)

# Validate agent type is not template placeholder
if [ "$agent_type" = "{agent_type}" ]; then
  agent_type="general-purpose"
fi
```

### Template Operations

When parsing analysis files for agent coordination:

1. **Validate File Access**: Check file exists and is readable
2. **Extract Stream Sections**: Use sed to isolate `### Stream {ID}:` sections
3. **Parse Required Fields**:
   - Agent Type: `**Agent Type**: {type}` 
   - Stream Name: From section header
   - File Patterns: Multi-line under `**Files**:`
   - Description: From `**Scope**:` field
4. **Provide Fallbacks**: Never launch agents with template placeholders
5. **Export Variables**: Make parsed values available for Task calls

## Common PM System Issues

### File Location Patterns
- Issues may be in flat or nested structure - always check both locations
- Analysis files are co-located with issue files
- Progress files follow standard: `updates/{issue_id}/stream-{X}.md`

### Template Validation
- Never launch agents with unresolved template variables
- Always validate analysis file parsing before agent launch
- Provide meaningful error messages with suggested fix commands

### Status Synchronization
- Epic progress recalculation triggers on issue completion
- Frontmatter updates should be atomic (status + updated timestamp)
- Progress percentage calculations must handle zero-division cases

## Claude Code Command Architecture

### Dual-Layer System Understanding

Claude Code uses a **two-tier command architecture** that must be understood before implementing:

**Command Layer** (`.claude/commands/pm/*.md`):
- Template files that define **what** to execute
- Contains frontmatter with allowed tools
- Simple instruction: `Run bash .claude/scripts/pm/{command}.sh`
- **NOT executable code** - these are execution instructions

**Script Layer** (`.claude/scripts/pm/*.sh`):
- Actual executable bash scripts
- Contains the real implementation logic
- Called by Claude Code when command is invoked
- **This is where functionality is implemented**

### Critical Implementation Pattern

**✅ Correct Approach:**
1. Create/update `.claude/scripts/pm/command.sh` with actual logic
2. Create/update `.claude/commands/pm/command.md` to call the script
3. Test through Claude Code interface (not direct bash execution)

**❌ Common Mistake:**
- Implementing complex logic in `.md` template files
- Assuming templates are directly executable
- Testing logic in isolation without integration testing

### Example Architecture:
```
/pm:next command flow:
├── .claude/commands/pm/next.md → "Run bash .claude/scripts/pm/next.sh"
└── .claude/scripts/pm/next.sh → Actual intelligent workflow logic
```

**Lesson Learned:** Always examine existing working commands to understand the architecture before implementing new functionality.

## Command Design Guidelines

### Cross-Referencing Between Commands

Based on CLI design best practices and software architecture principles:

**❌ NEVER Reference Other Commands for Implementation Details:**
- Don't say "see epic-start.md for implementation"
- Don't say "follow the pattern in other-command.md"
- Each command should be self-contained with complete documentation

**✅ ACCEPTABLE Cross-References:**
- **Error messages with suggestions**: "❌ Epic not found. Run: /pm:prd-parse $ARGUMENTS"
- **Workflow guidance in output**: "Next: Start work with /pm:issue-start $ARGUMENTS" 
- **Monitoring suggestions**: "Monitor with: /pm:epic-status $ARGUMENTS"

**Architecture Principles:**
- Commands should be **self-contained** - users shouldn't need to understand multiple commands
- **Template documentation** should show complete patterns within each command
- **High coupling between commands** makes the system complex to maintain
- Follow **human-first design** - commands should be intuitive and guessable

**Template Documentation Standards:**
- Keep complete template patterns in each command file
- Remove duplicate/inconsistent template sections
- Use consistent placeholder naming across commands
- Reference original tmp/ implementation for established patterns