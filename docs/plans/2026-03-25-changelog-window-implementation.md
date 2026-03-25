# Changelog Window Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add an update-only `Changelog` action that opens a dedicated window showing official changelog content and an AI summary generated through the local `summarize` CLI.

**Architecture:** Extend provider metadata with official changelog URLs and expose changelog availability on snapshots. Add a changelog model plus window scene, and back it with a service protocol whose live implementation shells out to `summarize` for both extraction and summary. Keep UI state separate from refresh/update state so the panel remains responsive.

**Tech Stack:** Swift, SwiftUI, Swift Testing, local `summarize` CLI

---

### Task 1: Add provider changelog metadata and snapshot gating

**Files:**
- Modify: `Sources/AgentVersionBarApp/Models.swift`
- Test: `Tests/AgentVersionBarTests/VersionRefreshServiceTests.swift`

**Step 1: Write the failing test**

Add tests asserting:
- each provider exposes the expected official changelog URL
- a snapshot only offers changelog access when `status == .updateAvailable`

**Step 2: Run test to verify it fails**

Run: `env CLANG_MODULE_CACHE_PATH=/tmp/clang-module-cache SWIFTPM_MODULECACHE_OVERRIDE=/tmp/swiftpm-module-cache swift test --filter VersionRefreshServiceTests`

Expected: FAIL because changelog metadata does not exist yet.

**Step 3: Write minimal implementation**

Add provider URL metadata and a computed snapshot property for changelog availability.

**Step 4: Run test to verify it passes**

Run: `env CLANG_MODULE_CACHE_PATH=/tmp/clang-module-cache SWIFTPM_MODULECACHE_OVERRIDE=/tmp/swiftpm-module-cache swift test --filter VersionRefreshServiceTests`

Expected: PASS.

### Task 2: Add changelog service and state model

**Files:**
- Create: `Sources/AgentVersionBarApp/ChangelogService.swift`
- Create: `Sources/AgentVersionBarApp/ChangelogWindowModel.swift`
- Modify: `Sources/AgentVersionBarApp/AppModel.swift`
- Test: `Tests/AgentVersionBarTests/AppModelTests.swift`

**Step 1: Write the failing test**

Add tests covering changelog loading state, successful result handling, and partial-failure handling.

**Step 2: Run test to verify it fails**

Run: `env CLANG_MODULE_CACHE_PATH=/tmp/clang-module-cache SWIFTPM_MODULECACHE_OVERRIDE=/tmp/swiftpm-module-cache swift test --filter AppModelTests`

Expected: FAIL because changelog model/service types do not exist yet.

**Step 3: Write minimal implementation**

Create a changelog service protocol and a model that stores:
- provider
- source URL
- current version
- latest version
- loading state
- summary text
- original text
- error message

Use a live implementation that calls:
- `summarize <url> --extract --format md --markdown-mode readability --plain`
- `summarize <url> --plain --length medium --prompt <version-aware prompt>`

**Step 4: Run test to verify it passes**

Run: `env CLANG_MODULE_CACHE_PATH=/tmp/clang-module-cache SWIFTPM_MODULECACHE_OVERRIDE=/tmp/swiftpm-module-cache swift test --filter AppModelTests`

Expected: PASS.

### Task 3: Add the changelog window UI and panel entry point

**Files:**
- Create: `Sources/AgentVersionBarApp/ChangelogView.swift`
- Modify: `Sources/AgentVersionBarApp/AgentVersionBarApp.swift`
- Modify: `Sources/AgentVersionBarApp/MenuBarContentView.swift`
- Modify: `Sources/AgentVersionBarApp/AppTheme.swift`

**Step 1: Write the failing test**

If needed, add a model-level test covering the action gate for showing the button. Keep UI logic thin.

**Step 2: Run test to verify it fails**

Run: `env CLANG_MODULE_CACHE_PATH=/tmp/clang-module-cache SWIFTPM_MODULECACHE_OVERRIDE=/tmp/swiftpm-module-cache swift test --filter AppModelTests`

Expected: FAIL only if an added gate test is not yet implemented.

**Step 3: Write minimal implementation**

Add:
- a new changelog window scene
- a `Changelog` button beside `Update` when the snapshot exposes changelog access
- a window view with loading, summary, original, and browser-open actions

**Step 4: Run test to verify it passes**

Run: `env CLANG_MODULE_CACHE_PATH=/tmp/clang-module-cache SWIFTPM_MODULECACHE_OVERRIDE=/tmp/swiftpm-module-cache swift test`

Expected: PASS.

### Task 4: Verify the app workflow

**Files:**
- Modify: `Sources/AgentVersionBarApp/ChangelogView.swift`
- Modify: `Sources/AgentVersionBarApp/MenuBarContentView.swift`

**Step 1: Rebuild the app**

Run: `env CLANG_MODULE_CACHE_PATH=/tmp/clang-module-cache SWIFTPM_MODULECACHE_OVERRIDE=/tmp/swiftpm-module-cache swift build -c debug --product AgentVersionBarApp --package-path /Users/bytedance/projects/agent_version_bar`

Expected: PASS.

**Step 2: Sync the rebuilt app bundle**

Copy the binary into `.run/AgentVersionBar.app` and `AgentVersionBarPreview.app`.

**Step 3: Relaunch the preview app**

Quit the running app and open the preview bundle to verify:
- `Changelog` only appears when updates are available
- the changelog window opens
- summary and original content render in separate sections
