# Theme Switcher Design

## Goal

Add three selectable visual themes for the app: `Warm`, `Light`, and `Dark`. Users should be able to switch themes from the panel without increasing panel height, and set the default theme from Settings.

## Requirements

- Provide exactly three themes: `Warm`, `Light`, `Dark`
- Allow fast switching from the panel
- Keep panel height compact
- Add a default-theme setting in Settings
- Persist the chosen theme across launches
- Reuse the existing design system and view structure

## Approaches

### Option 1: Compact Theme Menu in the Panel

Add a small theme button in the panel header that opens a menu with the three themes. Persist the chosen theme in `UserDefaults` and apply it to both panel and settings.

Pros:
- Fits the compact panel constraint
- Minimal layout disruption
- Clear and direct interaction

Cons:
- One more click than an inline segmented control

### Option 2: Inline Segmented Control in the Panel

Place a `Warm / Light / Dark` segmented control directly in the panel header.

Pros:
- Immediate visibility
- One-click switching

Cons:
- Increases panel height and visual density
- Conflicts with the compact layout goal

### Option 3: Settings-Only Theme Control

Keep theme selection only in Settings and remove panel switching.

Pros:
- Simplest UI change
- No panel space cost

Cons:
- Misses the requested panel-level switching

## Recommendation

Choose Option 1. A compact menu button in the panel keeps the layout tight while still making theme switching accessible.

## Architecture

- Add a new `AppThemeStyle` enum representing `warm`, `light`, and `dark`
- Move the current hard-coded theme tokens into palette data keyed by `AppThemeStyle`
- Store the selected theme in `AppModel`
- Persist the selected theme to `UserDefaults`
- Drive panel and settings colors from the active theme palette

## UI Changes

### Panel

- Add a small theme menu button in the header
- Show the currently active theme in the menu state, not as a large visible control
- Do not increase the current panel height meaningfully

### Settings

- Add a new `Default Theme` control under `Preference`
- Use a `Picker` that lists `Warm`, `Light`, and `Dark`
- Keep the current settings layout and only extend it

## Testing

- Add tests for theme enum behavior and persistence through `AppModel`
- Keep existing theme token tests and extend them for multiple palettes
- Build and relaunch the preview app after implementation

