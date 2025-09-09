# gtree - GitWorkTree Feature Development Command

## Overview

`gtree` is a powerful command-line tool that implements a GitWorkTree-based feature development workflow with Claude sub-agent delegation. It provides isolated feature development environments, automated task delegation, comprehensive change tracking, and streamlined merging with detailed commit logs.

## Architecture

### Workflow Design

```
┌─────────────────────────────────────────────────────────────┐
│                    gtree Workflow                           │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  1. CREATE FEATURE                                          │
│     ├── Create git worktree in .trees/<feature-name>       │
│     ├── Create feature branch (feature/<feature-name>)     │
│     ├── Initialize tracking files                          │
│     └── Set up isolated environment                        │
│                                                             │
│  2. WORK ON FEATURE                                         │
│     ├── Spawn Claude sub-agent in worktree                 │
│     ├── Agent works independently on task                  │
│     ├── Track all changes and modifications                │
│     └── Log progress and decisions                         │
│                                                             │
│  3. COMPLETE & MERGE                                        │
│     ├── Generate comprehensive commit message              │
│     ├── Merge feature branch to main                       │
│     ├── Include detailed change log                        │
│     └── Clean up worktree and branch                       │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

### Directory Structure

```
project-root/
├── .trees/                    # Hidden directory for features
│   ├── .gtree.log            # Global gtree log
│   ├── .gtree.config         # Configuration file
│   ├── feature-name/         # Isolated feature worktree
│   │   ├── .gtree_metadata   # Feature metadata
│   │   ├── .gtree_status     # Current status
│   │   ├── .gtree_changes.md # Change log
│   │   ├── .gtree_agent.log  # Sub-agent logs
│   │   └── ... (source files)
│   └── another-feature/
└── .gitignore                # .trees/ excluded from main repo
```

## Installation & Setup

### Prerequisites

1. **Git** - Required for worktree functionality
2. **Claude CLI** - Install with: `curl -fsSL https://claude.ai/install.sh | sh`

### Installation

1. Copy the `gtree` script to your project root or a directory in your PATH
2. Make it executable: `chmod +x gtree`
3. Initialize in your repository: `./gtree init`

### Initial Setup

```bash
# Initialize gtree in your repository
./gtree init

# This will:
# - Create .trees/ directory
# - Add .trees/ to .gitignore
# - Create configuration file
# - Set up logging
```

## Commands Reference

### Core Commands

#### `gtree init`
Initialize gtree in the current repository.

```bash
gtree init
```

**What it does:**
- Creates `.trees/` directory
- Adds `.trees/` to `.gitignore`
- Creates configuration file with defaults
- Initializes logging system

#### `gtree create <feature-name> [description]`
Create a new feature with isolated worktree.

```bash
gtree create sharing-feature "Add sharing functionality to the app"
gtree create user-auth "Implement user authentication system"
```

**What it does:**
- Creates git branch `feature/<feature-name>`
- Creates worktree in `.trees/<feature-name>`
- Sets up metadata and tracking files
- Returns to main branch

#### `gtree work <feature-name> [task-description]`
Start working on a feature with Claude sub-agent.

```bash
gtree work sharing-feature "Implement share target selection UI"
gtree work user-auth "Create login and registration forms"
```

**What it does:**
- Spawns Claude sub-agent in feature worktree
- Provides context about the feature and codebase
- Agent works independently on the task
- Logs all agent activity

#### `gtree list` / `gtree ls`
List all active features and their status.

```bash
gtree list
```

**Output example:**
```
Active Features:
==================
📁 sharing-feature
   Branch: feature/sharing-feature  
   Status: working
   Path: .trees/sharing-feature
   Agent: running (PID: 12345)

📁 user-auth
   Branch: feature/user-auth
   Status: complete
   Path: .trees/user-auth
   Agent: stopped
```

### Monitoring Commands

#### `gtree status [feature-name]`
Show detailed status of a feature (or all features).

```bash
gtree status sharing-feature
gtree status  # Shows all features
```

**Shows:**
- Feature metadata (description, creation date, author)
- Current status and last update
- Agent status (running/stopped)
- Git status (modified files)
- Recent changes from log

#### `gtree logs <feature-name>`
View real-time agent logs for a feature.

```bash
gtree logs sharing-feature
```

**What it shows:**
- Real-time streaming of agent activity
- Decision-making process
- Code changes and reasoning
- Error messages and debugging

#### `gtree stop <feature-name>`
Stop the running agent for a feature.

```bash
gtree stop sharing-feature
```

### Completion Commands

#### `gtree complete <feature-name>`
Mark a feature as complete and ready for merge.

```bash
gtree complete sharing-feature
```

**What it does:**
- Stops any running agent
- Updates status to "complete"
- Prepares feature for merge
- Timestamps completion

#### `gtree merge <feature-name> [--force]`
Merge completed feature back to main branch.

```bash
gtree merge sharing-feature
gtree merge user-auth --force  # Skip completion check
```

**What it does:**
- Commits any remaining changes
- Generates comprehensive commit message
- Merges feature branch to main
- Includes detailed change log in commit
- Optionally cleans up worktree and branch

#### `gtree cleanup <feature-name>`
Clean up feature branch and worktree.

```bash
gtree cleanup sharing-feature
```

**What it does:**
- Stops any running agent
- Removes git worktree
- Deletes feature branch
- Frees up disk space

## Usage Examples

### Complete Feature Development Flow

```bash
# 1. Initialize gtree (one time setup)
gtree init

# 2. Create a new feature
gtree create sharing-feature "Add share functionality to app"

# 3. Start working with sub-agent
gtree work sharing-feature "Implement share target selection UI with club list"

# 4. Monitor progress
gtree status sharing-feature
gtree logs sharing-feature

# 5. Check work when agent is done
gtree status sharing-feature

# 6. Complete the feature
gtree complete sharing-feature

# 7. Merge to main branch
gtree merge sharing-feature

# Feature is now merged with comprehensive commit log!
```

### Managing Multiple Features

```bash
# Create multiple features
gtree create user-auth "User authentication system"
gtree create push-notifications "Push notification service"
gtree create dark-mode "Dark mode theme support"

# Work on them independently
gtree work user-auth "Implement login form with validation"
gtree work push-notifications "Set up Firebase messaging service"

# Check status of all features
gtree list

# Monitor specific feature
gtree status user-auth

# Complete and merge when ready
gtree complete user-auth
gtree merge user-auth
```

### Advanced Workflows

```bash
# Work with detailed task descriptions
gtree work sharing-feature "
Create a comprehensive sharing system that:
1. Handles incoming share intents from other apps
2. Shows a club selection interface
3. Previews shared content (text, images, URLs)
4. Integrates with existing chat system
5. Supports deep linking
"

# Monitor and manage long-running development
gtree logs sharing-feature  # Watch agent work
gtree stop sharing-feature  # Pause if needed
gtree work sharing-feature "Continue with integration testing"

# Force merge if needed (bypasses completion check)
gtree merge sharing-feature --force
```

## Configuration

### Configuration File: `.trees/.gtree.config`

```bash
# Claude model to use for sub-agents
CLAUDE_MODEL="claude-3-5-sonnet-20241022"

# Default branch to merge back to
DEFAULT_BRANCH="main"

# Automatically cleanup after merge
AUTO_CLEANUP=true

# Maximum number of concurrent features
MAX_FEATURES=10

# Commit message template
COMMIT_TEMPLATE="feat(<feature>): <description>

<detailed_changes>

Generated by gtree
Co-authored-by: Claude <claude@anthropic.com>"
```

### Customization

You can modify the configuration to:
- Change the Claude model used by sub-agents
- Customize commit message templates
- Set different default branches
- Control automatic cleanup behavior
- Limit concurrent features

## Sub-Agent Integration

### How Sub-Agents Work

1. **Spawning**: When `gtree work` is called, a Claude sub-agent is spawned in the feature worktree
2. **Context**: Agent receives full context about the feature, task, and codebase structure
3. **Independence**: Agent works independently, making decisions and implementing changes
4. **Logging**: All agent activity is logged for transparency and debugging
5. **Tools**: Agent has access to all development tools (file operations, git, testing, etc.)

### Agent Capabilities

Sub-agents can:
- ✅ Analyze existing codebase and patterns
- ✅ Write and modify source code
- ✅ Create new files and directories
- ✅ Run tests and validate changes
- ✅ Update documentation
- ✅ Make git commits with descriptive messages
- ✅ Log their decision-making process
- ✅ Handle complex multi-file changes
- ✅ Follow existing code conventions

### Agent Communication

```bash
# The agent receives this context when started:
"""
You are working on a feature called 'sharing-feature' in an isolated git worktree.

Feature Directory: .trees/sharing-feature
Git Branch: feature/sharing-feature

Task: Implement share target selection UI with club list

Please analyze the current codebase, understand the requirements, and implement the feature.
Make sure to:
1. Follow existing code patterns and conventions
2. Write clean, maintainable code
3. Add appropriate tests if needed
4. Update documentation as necessary
5. Log all changes you make to .gtree_changes.md

You have full access to all development tools. When you're done, use 'gtree complete sharing-feature' to mark the feature as ready for merge.
"""
```

## Change Tracking & Commit Messages

### Automated Change Tracking

Every feature automatically tracks:
- **File changes**: What files were modified/added/deleted
- **Change descriptions**: What each change accomplishes
- **Decision rationale**: Why changes were made
- **Progress updates**: Timeline of development

### Generated Commit Messages

When merging, gtree generates comprehensive commit messages:

```
feat(sharing-feature): Add sharing functionality to the app

## Feature Summary
- Feature: sharing-feature
- Files changed: 12
- Lines added: 847
- Lines deleted: 23

## Changes Made
- Created ShareHandlerService for incoming share intents
- Implemented ShareTargetScreen with club selection UI
- Added SharePreview widget for content display
- Integrated with existing ClubChatScreen
- Added platform configurations for Android/iOS
- Created deep linking support with custom URL schemes
- Added comprehensive error handling and validation
- Updated navigation system for share flows

## Development Details
- Branch: feature/sharing-feature
- Developed in isolated worktree: .trees/sharing-feature
- Generated by gtree workflow

Generated by gtree
Co-authored-by: Claude <claude@anthropic.com>
```

### Change Log Format

Each feature maintains a `.gtree_changes.md` file:

```markdown
# Feature: sharing-feature

**Description:** Add sharing functionality to the app

## Changes Log

### 2024-01-15 14:30 - Initial Setup
- Created ShareHandlerService for managing incoming shares
- Added SharedContent model for different content types

### 2024-01-15 15:15 - UI Implementation  
- Implemented ShareTargetScreen with club selection
- Created SharePreview widget with content display
- Added ClubSelector widget with search functionality

### 2024-01-15 16:45 - Integration
- Integrated with existing ClubChatScreen
- Added share handling to main.dart
- Updated navigation helper for deep links

### 2024-01-15 17:30 - Platform Setup
- Added Android manifest configurations
- Updated iOS Info.plist for share handling
- Configured intent filters for text/image sharing
```

## Best Practices

### Feature Organization

1. **Descriptive Names**: Use clear, descriptive feature names
   ```bash
   gtree create user-profile-edit "Allow users to edit their profile information"
   # Better than: gtree create profile-stuff
   ```

2. **Single Responsibility**: Keep features focused on one main functionality
   ```bash
   # Good - focused features
   gtree create push-notifications "Push notification system"
   gtree create user-settings "User settings screen"
   
   # Avoid - too broad
   gtree create user-management "All user-related features"
   ```

3. **Clear Task Descriptions**: Provide detailed context for sub-agents
   ```bash
   gtree work sharing-feature "
   Implement a WhatsApp-like sharing interface that:
   - Receives content from other apps via share intents
   - Shows a searchable list of clubs to share to
   - Previews the content before sending
   - Integrates seamlessly with our existing chat system
   "
   ```

### Development Workflow

1. **Monitor Progress**: Regularly check agent status and logs
   ```bash
   gtree status sharing-feature
   gtree logs sharing-feature
   ```

2. **Iterative Development**: Break complex features into smaller tasks
   ```bash
   gtree work sharing-feature "Phase 1: Set up share intent handling"
   # Later...
   gtree work sharing-feature "Phase 2: Implement club selection UI"
   ```

3. **Quality Control**: Review changes before completing
   ```bash
   # Check what the agent has done
   cd .trees/sharing-feature
   git status
   git diff
   # Review the code, test functionality
   cd -
   gtree complete sharing-feature
   ```

### Git Integration

1. **Clean History**: Each feature becomes a single merge commit with full details
2. **Isolated Development**: No interference with main branch during development
3. **Easy Rollback**: Individual features can be reverted cleanly
4. **Parallel Development**: Multiple features can be developed simultaneously

## Troubleshooting

### Common Issues

#### Agent Not Starting
```bash
# Check if Claude CLI is installed
which claude

# Check if in git repository
git status

# Initialize gtree if not done
gtree init
```

#### Agent Stuck or Unresponsive
```bash
# Stop the agent
gtree stop feature-name

# Check agent logs for issues
gtree logs feature-name

# Restart with more specific instructions
gtree work feature-name "Continue from where you left off, focus on..."
```

#### Merge Conflicts
```bash
# Manual resolution needed
git status  # See conflicted files
# Resolve conflicts manually
git add .
git commit -m "Resolve merge conflicts"

# Then continue with gtree merge
gtree merge feature-name --force
```

#### Disk Space Issues
```bash
# Clean up completed features
gtree cleanup old-feature-name

# List all features to see what can be cleaned
gtree list

# Clean up multiple features
for feature in $(git worktree list | grep ".trees" | awk '{print $1}' | xargs basename); do
    gtree cleanup $feature
done
```

### Debugging

#### Enable Verbose Logging
```bash
# Edit .trees/.gtree.config
VERBOSE=true
DEBUG=true
```

#### Check Agent Status
```bash
# See if agent process is running
gtree status feature-name

# Manual process check
ps aux | grep claude
```

#### Validate Worktree State
```bash
# List all worktrees
git worktree list

# Check specific worktree
cd .trees/feature-name
git status
git log --oneline
```

## Advanced Features

### Custom Agent Prompts

You can customize the agent prompt by modifying the `work_on_feature()` function:

```bash
# Add custom instructions for specific project types
local prompt="You are working on a Flutter/Dart project...
Additional instructions:
- Follow Flutter best practices
- Use Provider for state management  
- Write widget tests for UI components
- Follow the existing project structure
"
```

### Integration with CI/CD

```bash
# In your CI/CD pipeline
if [ -d ".trees" ]; then
    echo "Active gtree features found:"
    ./gtree list
    
    # Optionally fail if unmerged features exist
    if [ $(./gtree list | grep -c "Status: working") -gt 0 ]; then
        echo "Cannot deploy with active features"
        exit 1
    fi
fi
```

### Batch Operations

```bash
# Stop all running agents
for feature in $(gtree list | grep "Agent: running" | awk '{print $2}'); do
    gtree stop $feature
done

# Complete all features
for feature in $(gtree list | grep "Status: working" | awk '{print $2}'); do
    gtree complete $feature
done
```

## Security Considerations

### Isolation Benefits
- **Code Isolation**: Feature development happens in separate worktrees
- **Branch Isolation**: Each feature has its own git branch
- **Process Isolation**: Sub-agents run as separate processes
- **No Main Branch Pollution**: Main branch stays clean until merge

### Access Control
- Sub-agents only have access to their feature worktree
- No network access unless explicitly configured
- All changes are tracked and logged
- Git history maintains full audit trail

### Safe Cleanup
- Worktrees can be removed safely without affecting main repo
- Failed features can be abandoned without consequences
- All operations are reversible through git

## Performance Considerations

### Resource Usage
- Each feature uses ~50-100MB for worktree
- Sub-agents may use 200-500MB RAM while running
- Log files grow over time and should be rotated

### Scaling
- Recommended limit: 5-10 concurrent features
- Clean up completed features regularly
- Monitor disk space in `.trees/` directory

### Optimization
- Use `AUTO_CLEANUP=true` to automatically clean up after merge
- Regularly run `gtree cleanup` on old features
- Consider log rotation for long-running projects

---

This comprehensive command enables sophisticated feature development workflows with complete isolation, intelligent automation, and detailed tracking - perfect for complex projects that benefit from AI-assisted development.