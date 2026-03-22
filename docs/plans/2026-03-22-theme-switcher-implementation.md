# Theme Switcher Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add warm, light, and dark themes with panel-level switching and a default-theme setting in Settings.

**Architecture:** Introduce a persistent `AppThemeStyle` state in `AppModel`, refactor `AppTheme` into palette-driven tokens, and expose a compact theme menu in the panel plus a default-theme picker in Settings. Reuse the existing view structure and keep the panel compact.

**Tech Stack:** Swift 6.2, SwiftUI, Foundation, Swift Testing

---

### Task 1: Add Theme State and Persistence

**Files:**
- Modify: `Sources/AgentVersionBarApp/AppModel.swift`
- Test: `Tests/AgentVersionBarTests/AppModelTests.swift`

**Step 1: Write the failing test**

Add tests that verify:

- `AppThemeStyle` defaults to `warm` when no stored value exists
- changing the theme persists the value
- a new `AppModel` instance restores the stored theme

**Step 2: Run test to verify it fails**

Run: `swift test`
Expected: FAIL because theme state is not implemented in `AppModel`.

**Step 3: Write minimal implementation**

Add:

- `AppThemeStyle` enum
- a new defaults key in `AppModel`
- `@Published var themeStyle`
- a `setTheme(_:)` helper or equivalent persistence logic
- injectable `UserDefaults` for testing

**Step 4: Run test to verify it passes**

Run: `swift test`
Expected: PASS

**Step 5: Commit**

```bash
git add Sources/AgentVersionBarApp/AppModel.swift Tests/AgentVersionBarTests/AppModelTests.swift
git commit -m "feat: add persistent theme state"
```

### Task 2: Refactor the Theme System for Three Palettes

**Files:**
- Modify: `Sources/AgentVersionBarApp/AppTheme.swift`
- Modify: `Tests/AgentVersionBarTests/AppThemeTests.swift`

**Step 1: Write the failing test**

Add tests that verify all three palettes exist and that each one exposes distinct top-level surface tokens.

**Step 2: Run test to verify it fails**

Run: `swift test`
Expected: FAIL because `AppTheme` is still single-palette.

**Step 3: Write minimal implementation**

Refactor `AppTheme` so it can return a palette for a given `AppThemeStyle`, including:

- panel background tokens
- surface tokens
- text tokens
- button and code-block tokens

**Step 4: Run test to verify it passes**

Run: `swift test`
Expected: PASS

**Step 5: Commit**

```bash
git add Sources/AgentVersionBarApp/AppTheme.swift Tests/AgentVersionBarTests/AppThemeTests.swift
git commit -m "feat: add multi-palette theme system"
```

### Task 3: Add the Panel Theme Switcher

**Files:**
- Modify: `Sources/AgentVersionBarApp/MenuBarContentView.swift`

**Step 1: Write the failing test**

No direct UI automation exists here. Use the theme-state and theme-palette tests as the correctness boundary, then build after the panel UI change.

**Step 2: Run tests to confirm baseline**

Run: `swift test`
Expected: PASS

**Step 3: Write minimal implementation**

Add a compact `Menu` button in the panel header with the three themes and a checkmark for the active one. Make the panel and its child controls render from the active theme palette.

**Step 4: Run build to verify it passes**

Run: `swift test`
Expected: PASS

**Step 5: Commit**

```bash
git add Sources/AgentVersionBarApp/MenuBarContentView.swift
git commit -m "feat: add panel theme switcher"
```

### Task 4: Add Default Theme Settings

**Files:**
- Modify: `Sources/AgentVersionBarApp/SettingsView.swift`

**Step 1: Write the failing test**

No direct visual test. Reuse the existing theme persistence tests and build verification after the settings change.

**Step 2: Run tests to confirm baseline**

Run: `swift test`
Expected: PASS

**Step 3: Write minimal implementation**

Add a `Default Theme` picker under `Preference` and bind it to the persisted theme state.

**Step 4: Run build to verify it passes**

Run: `swift test`
Expected: PASS

**Step 5: Commit**

```bash
git add Sources/AgentVersionBarApp/SettingsView.swift
git commit -m "feat: add default theme setting"
```

### Task 5: Rebuild and Relaunch Preview

**Files:**
- Modify: `.run/AgentVersionBar.app` via rebuild and bundle sync
- Modify: `AgentVersionBarPreview.app` via preview copy

**Step 1: Rebuild**

Run:

```bash
env CLANG_MODULE_CACHE_PATH=/tmp/clang-module-cache \
SWIFTPM_MODULECACHE_OVERRIDE=/tmp/swiftpm-module-cache \
swift test
```

Expected: PASS

**Step 2: Sync the app bundle**

Copy the rebuilt executable into `.run/AgentVersionBar.app`.

**Step 3: Refresh the preview bundle**

Copy `.run/AgentVersionBar.app` to `AgentVersionBarPreview.app`.

**Step 4: Relaunch**

Quit the running app and open `AgentVersionBarPreview.app`.

**Step 5: Commit**

```bash
git add Sources/AgentVersionBarApp/AppModel.swift Sources/AgentVersionBarApp/AppTheme.swift Sources/AgentVersionBarApp/MenuBarContentView.swift Sources/AgentVersionBarApp/SettingsView.swift Tests/AgentVersionBarTests/AppModelTests.swift Tests/AgentVersionBarTests/AppThemeTests.swift docs/plans/2026-03-22-theme-switcher-design.md docs/plans/2026-03-22-theme-switcher-implementation.md
git commit -m "feat: add switchable app themes"
```
