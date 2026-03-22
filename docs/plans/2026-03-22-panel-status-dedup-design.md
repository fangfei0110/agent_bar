# Panel Status Dedup Design

**Goal:** Remove duplicated status signaling from each panel agent card without changing settings behavior or the existing status vocabulary.

## Context

The panel card currently shows the same status twice in the header:
- a leading circular status icon on the left
- a trailing status pill on the right

For common cases like `Up to date`, this creates redundant visual weight and makes the card feel busier than necessary.

## Decision

Keep the trailing status pill and remove the leading status icon from the panel card.

## Why

- The pill already carries both icon and label, so it is the more informative element.
- Removing the left icon cleans up the first scan line and gives more space to the provider name.
- This is a panel-only change; settings cards keep their existing layout.

## Non-Goals

- No changes to status names or status-color mapping.
- No changes to settings card status badges.
- No changes to update logic or version-fetching behavior.
