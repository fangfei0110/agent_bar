# Panel Status Dedup Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Remove the duplicate panel status icon while preserving the existing trailing status pill.

**Architecture:** Add a small panel-specific display rule on `VersionStatus`, lock it with a test, then update the panel card header to render only the provider text block and trailing status pill. Keep settings unchanged.

**Tech Stack:** Swift, SwiftUI, Swift Testing

---

### Task 1: Lock the panel display rule with a failing test

**Files:**
- Modify: `Tests/AgentVersionBarTests/AppThemeTests.swift`

**Step 1: Write the failing test**

Add a test asserting every `VersionStatus` hides the leading panel icon because the trailing pill already represents status.

**Step 2: Run test to verify it fails**

Run: `env CLANG_MODULE_CACHE_PATH=/tmp/clang-module-cache SWIFTPM_MODULECACHE_OVERRIDE=/tmp/swiftpm-module-cache swift test --filter AppThemeTests`

Expected: FAIL because the new panel display rule does not exist yet.

### Task 2: Implement the minimal panel layout change

**Files:**
- Modify: `Sources/AgentVersionBarApp/AppTheme.swift`
- Modify: `Sources/AgentVersionBarApp/MenuBarContentView.swift`

**Step 1: Add the panel-specific display rule**

Expose a `VersionStatus` property for whether a leading panel status icon should render.

**Step 2: Update the panel card header**

Use the new rule and remove the left status icon from the provider card layout.

**Step 3: Run targeted tests**

Run: `env CLANG_MODULE_CACHE_PATH=/tmp/clang-module-cache SWIFTPM_MODULECACHE_OVERRIDE=/tmp/swiftpm-module-cache swift test --filter AppThemeTests`

Expected: PASS.

### Task 3: Verify the app build

**Files:**
- Modify: `Sources/AgentVersionBarApp/MenuBarContentView.swift`

**Step 1: Run the full suite**

Run: `env CLANG_MODULE_CACHE_PATH=/tmp/clang-module-cache SWIFTPM_MODULECACHE_OVERRIDE=/tmp/swiftpm-module-cache swift test`

Expected: PASS.

**Step 2: Rebuild and relaunch the preview app**

Rebuild the app binary, refresh the preview bundle, and relaunch it to visually verify the deduped card header.
