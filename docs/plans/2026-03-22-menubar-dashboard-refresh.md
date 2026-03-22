# Menu Bar Dashboard Refresh Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Refresh the menu panel and settings window into a compact, polished dashboard-style interface with a shared visual system.

**Architecture:** Add a small internal design system for surface styling, status pills, and compact metric layouts, then apply it consistently to the menu panel and settings window. Keep data flow unchanged and restrict the work to SwiftUI composition, style tokens, and minor view extraction.

**Tech Stack:** Swift 6.2, SwiftUI, AppKit, Swift Testing

---

### Task 1: Add a Small Shared Visual System

**Files:**
- Create: `Sources/AgentVersionBarApp/AppTheme.swift`
- Test: `Tests/AgentVersionBarTests/AppThemeTests.swift`

**Step 1: Write the failing test**

Add tests for a small semantic styling layer, covering status tint mapping and ensuring the design system exposes stable style choices for each `VersionStatus`.

**Step 2: Run test to verify it fails**

Run: `swift test`
Expected: FAIL because `AppTheme.swift` and its style helpers do not exist yet.

**Step 3: Write minimal implementation**

Create `AppTheme.swift` with:

- semantic colors for panel backgrounds, card backgrounds, strokes, and accent fills
- a `StatusAppearance` helper that maps `VersionStatus` to tint choices and symbols
- small reusable modifiers or wrappers for dashboard surfaces

**Step 4: Run test to verify it passes**

Run: `swift test`
Expected: PASS for the new theme tests.

**Step 5: Commit**

```bash
git add Sources/AgentVersionBarApp/AppTheme.swift Tests/AgentVersionBarTests/AppThemeTests.swift
git commit -m "feat: add shared menubar dashboard theme"
```

### Task 2: Refresh the Menu Panel

**Files:**
- Modify: `Sources/AgentVersionBarApp/MenuBarContentView.swift`

**Step 1: Write the failing test**

Use the new shared theme test coverage as the guardrail for the semantic style layer, then inspect the existing menu panel structure to refactor safely without changing data behavior.

**Step 2: Run test to verify current state**

Run: `swift test`
Expected: PASS on theme tests before UI refactor.

**Step 3: Write minimal implementation**

Refactor the panel into:

- a richer dashboard header
- polished provider cards with stronger hierarchy
- compact metric tiles
- better-styled buttons and error treatments

Keep refresh, settings, and quit actions intact.

**Step 4: Run build to verify it passes**

Run: `swift build -c debug --product AgentVersionBarApp`
Expected: PASS

**Step 5: Commit**

```bash
git add Sources/AgentVersionBarApp/MenuBarContentView.swift
git commit -m "feat: refresh menu panel dashboard styling"
```

### Task 3: Refresh the Settings Window

**Files:**
- Modify: `Sources/AgentVersionBarApp/SettingsView.swift`

**Step 1: Write the failing test**

No meaningful automated visual test exists for this SwiftUI composition. Reuse the semantic theme tests and treat build verification as the correctness gate for the UI refactor.

**Step 2: Run test to verify baseline**

Run: `swift test`
Expected: PASS on theme tests before the settings UI refactor.

**Step 3: Write minimal implementation**

Apply the shared visual system to settings:

- richer tab headers
- cleaner card composition
- refined control rows
- improved path and command blocks
- more consistent spacing, stroke, and typography

**Step 4: Run build to verify it passes**

Run: `swift build -c debug --product AgentVersionBarApp`
Expected: PASS

**Step 5: Commit**

```bash
git add Sources/AgentVersionBarApp/SettingsView.swift
git commit -m "feat: restyle settings dashboard"
```

### Task 4: Rebuild the Launch Bundle and Verify

**Files:**
- Modify: `.run/AgentVersionBar.app` via rebuild and copy

**Step 1: Rebuild the executable**

Run:

```bash
env CLANG_MODULE_CACHE_PATH=/tmp/clang-module-cache \
SWIFTPM_MODULECACHE_OVERRIDE=/tmp/swiftpm-module-cache \
swift build -c debug --product AgentVersionBarApp --package-path /Users/bytedance/projects/agent_version_bar
```

Expected: PASS

**Step 2: Refresh the app bundle contents**

Copy the rebuilt binary into `.run/AgentVersionBar.app/Contents/MacOS/AgentVersionBarApp` and sync `AppBundle/Info.plist`.

**Step 3: Relaunch the app**

Quit the old running process and open `.run/AgentVersionBar.app`.

**Step 4: Verify**

Confirm the running app shows the new compact dashboard panel and matching settings window.

**Step 5: Commit**

```bash
git add Sources/AgentVersionBarApp/AppTheme.swift Tests/AgentVersionBarTests/AppThemeTests.swift Sources/AgentVersionBarApp/MenuBarContentView.swift Sources/AgentVersionBarApp/SettingsView.swift docs/plans/2026-03-22-menubar-dashboard-design.md docs/plans/2026-03-22-menubar-dashboard-refresh.md
git commit -m "feat: refresh menubar dashboard ui"
```
