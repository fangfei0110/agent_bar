# Changelog Window Design

**Goal:** When a provider has an available update, show a `Changelog` button in the panel that opens a dedicated window containing the provider's official changelog content plus an AI summary of the most relevant changes.

## Context

The panel currently exposes version state and an `Update` button, but it gives no context on what changed between the installed and available versions. The new feature needs to help users decide whether to update without leaving the app's workflow.

## Requirements

- Only show the new entry point when a provider is updateable.
- Use each provider's official changelog or release-notes page as the source of truth.
- Open a dedicated window, not an inline panel expansion.
- Preserve the original extracted content in the app.
- Generate an AI summary focused on the current version versus the latest available version.
- Degrade cleanly when source extraction or summarization fails.

## Source Strategy

Each provider gets a fixed official changelog URL in provider metadata.

- `OpenClaw`: official GitHub releases page for the project
- `OpenCode`: official changelog page on `opencode.ai`
- `Claude Code`: official GitHub releases page referenced by Anthropic docs
- `Codex CLI`: official GitHub releases page for `openai/codex`

This keeps the source predictable and testable. It also avoids trying to discover changelog URLs dynamically at runtime.

## Summary Backend Decision

Two implementation approaches were considered:

1. `summarize` CLI for both extraction and summary
2. Native app fetching plus a separate summarizer integration

The first option is the better fit for the current app:

- `summarize` already exists on the target machine
- it supports direct URL extraction and summarization
- it keeps networking and model orchestration outside the SwiftUI app code
- it is easier to swap behind a protocol later if needed

So the app will use a `ChangelogService` abstraction whose live implementation shells out to `summarize`.

## Window Design

The changelog window contains:

- a compact hero row with provider name, current version, latest version, and source URL
- a `Summary` section with AI-generated key changes
- an `Original` section with the extracted source content preserved as text
- an `Open in Browser` action for the source page
- clear loading and failure states for extraction and summary

The summary and original content are separate sections so the user can quickly skim and then inspect source details without leaving the app.

## Data Flow

1. User clicks `Changelog` from the panel.
2. The app opens a dedicated changelog window for that provider.
3. The model layer loads changelog data for the provider and version range.
4. The service runs `summarize <url> --extract ...` to capture source content.
5. The service runs `summarize <url> --prompt ...` to generate a concise version-aware summary.
6. The window updates once the content is loaded, or shows a partial/error state if one step fails.

## Failure Handling

- Missing changelog URL: do not show the button.
- Missing `summarize` command: show the window with a clear error and the source URL.
- Extraction fails: show error state and still allow `Open in Browser`.
- Summary fails: still show the extracted original content if available.
- Empty content: show a structured `No changelog content available` state.

## Testing Strategy

Add tests around:

- provider changelog URL mapping
- provider snapshots exposing changelog availability only when updates exist
- changelog state transitions from idle to loading to loaded or failed
- partial success behavior where original content loads but summary fails

The UI itself stays thin; most behavior is validated through model and service tests.
