# Menu Bar Dashboard Design

## Goal

Refresh the menu panel and settings window so the app feels like a compact, professional developer dashboard instead of a default SwiftUI form. The interface should stay tight enough for menu bar use while adding clearer hierarchy, stronger state emphasis, and a more polished visual system.

## Direction

- Visual style: cold, professional, graphite-heavy, with restrained blue and teal accents
- Density: compact, not expanded into a large inspector-style panel
- Tone: closer to a premium developer utility than a stock system menu

## Approach Options

### Option 1: Dashboard Compact

Keep the panel compact, but redesign the header, cards, badges, and settings groups into a unified dashboard surface. Use layered backgrounds, subtle borders, status pills, and stronger typography hierarchy.

Pros:
- Best fit for menu bar usage
- Highest perceived quality for moderate code change
- Preserves quick scanning

Cons:
- Requires some custom view composition instead of default SwiftUI grouping

### Option 2: Native Plus

Keep the current structure and mostly refine spacing, font weight, and badges while staying near the default AppKit/SwiftUI look.

Pros:
- Very safe
- Minimal implementation risk

Cons:
- Limited visual lift
- Would still feel generic

### Option 3: Ops Console

Push toward a denser operational dashboard with stronger numeric emphasis and more technical styling.

Pros:
- Strong scanability
- Distinct identity

Cons:
- Too rigid for a menu bar utility
- Risks feeling heavy and cramped

## Recommendation

Choose Option 1, Dashboard Compact. It matches the requested style, keeps the footprint practical for a menu bar app, and creates a coherent system that can be shared by both the panel and the settings window.

## UI Architecture

### Shared Visual System

Create a small set of reusable SwiftUI building blocks and tokens:

- surface backgrounds
- soft card borders
- accent pills
- section headers
- compact metric tiles
- consistent spacing and corner radii

This prevents the panel and settings window from drifting into separate styles.

### Menu Panel

The panel should feel like a small status dashboard:

- a stronger header block with title, subheading, and live status chips
- provider cards with clearer separation between provider identity, versions, and actions
- subtler card fills with better edge treatment
- more intentional action row styling

The panel width can increase slightly, but the content should remain compact and vertically efficient.

### Settings Window

The settings window should become a settings center using the same design system:

- stronger tab section headers
- grouped cards with cleaner inner spacing
- clearer informational hierarchy
- improved path and command presentation
- lighter visual noise in repetitive controls

## Error Handling

No behavior change to version fetching or update logic. Error messages remain, but their presentation should be visually integrated into the card design.

## Testing

- Build the app successfully with the updated SwiftUI hierarchy
- Verify the bundle used for launching contains the rebuilt binary
- Manually inspect the panel and settings visuals in the running app

