# Rainmeter Google Calendar Skin

## Goal

Build a Rainmeter skin that integrates with Google Calendar and supports:

- Day view for the selected date
- Schedule view for upcoming events
- Scrollable event lists
- Interactive controls for navigation and expansion
- Collapsed icon state
- Flyout panel when the icon is clicked

## Product Direction

The skin should feel like a compact desktop widget first, not a full calendar app. The main interaction model:

- Collapsed state: a small calendar icon pinned on desktop
- Expanded state: a flyout panel anchored to that icon
- Day view: focused list of events for one day
- Schedule view: rolling upcoming agenda
- Scroll behavior: mouse wheel or explicit controls for event list movement
- Interactions: click to expand/collapse, switch views, move between dates, refresh calendar data

## Known Technical Constraints

Rainmeter does not provide native Google Calendar integration, so we will need an external integration layer. The most practical approach is:

- Rainmeter skin UI in `.ini`
- Lua for UI state and paging logic
- External fetch/auth helper to sync Google Calendar events into local JSON
- Rainmeter measures to read that local data and render it

Key implication:

- Google Calendar access will likely require OAuth 2.0 and a helper script or small local service
- Rainmeter alone is not the right place to handle the full OAuth browser flow cleanly
- The skin should be designed so UI and data sync are loosely coupled

## Proposed Architecture

### 1. Skin Layer

Rainmeter suite with:

- `Calendar.ini` as main launcher shell
- visual states for collapsed and expanded modes
- reusable style variables
- meters for header, tabs, buttons, event rows, and flyout shell

### 2. UI State Layer

Lua script to manage:

- current view mode
- selected date
- scroll offset
- expanded/collapsed state
- event pagination/windowing
- hit actions and redraw coordination

### 3. Data Layer

Local cache file, probably JSON, containing:

- calendars
- events
- timestamps
- normalized fields used by the skin

### 4. Sync Layer

External helper, likely PowerShell, Python, or Node, to:

- authenticate with Google Calendar
- fetch events
- normalize response data
- write cache for Rainmeter consumption

## Initial Scope

Version 1 should prioritize:

- one Google account
- one or more chosen calendars
- upcoming events schedule view
- selected-day event view
- expand/collapse interaction
- basic scrolling
- reliable refresh flow

Version 1 should not initially prioritize:

- event creation/editing
- drag and drop
- month grid view
- multiple simultaneous flyouts
- deep calendar settings UI inside Rainmeter

Stretch goals:

- timeline view with visual day time-blocks for events

## Milestones

### Milestone 1: Project Scaffold

- [x] Define suite folder structure
- [x] Create main Rainmeter skin file
- [x] Create variables and style organization
- [x] Create README progress tracker

### Milestone 2: UI Prototype

- [ ] Collapsed icon shows current month and day
- [x] Collapsed icon state
- [x] Click-to-flyout transition behavior
- [x] Header and view switch controls
- [x] Static day view prototype
- [x] Static schedule view prototype
- [x] Scrollable event container prototype

### Milestone 3: Local State Logic

- [x] Lua state model for expanded/collapsed mode
- [x] View switching logic
- [x] Date navigation logic
- [x] Scroll offset and visible row logic

### Milestone 4: Google Calendar Sync

- [x] Choose sync helper runtime
- [x] Set up Google Calendar API credentials flow
- [x] Pull events into local cache
- [x] Normalize recurring/all-day/timed events
- [x] Add manual refresh action
- [x] Add GUI helper for entering config values and launching authorization

### Milestone 5: Data Binding

- [ ] Bind cached event data into Rainmeter measures
- [ ] Render day view dynamically
- [ ] Render schedule view dynamically
- [ ] Empty-state handling
- [ ] Error-state handling

### Milestone 6: Polish

- [ ] Smooth flyout behavior
- [ ] Better styling and iconography
- [ ] Performance tuning
- [ ] Packaging and setup instructions

## Progress Log

### 2026-03-30

- [x] Defined the product goal and feature set
- [x] Chose a decoupled architecture: Rainmeter UI + Lua state + external Google sync helper
- [x] Created this README as the initial project tracker
- [x] Scaffolded the first `GoogleCalendar` Rainmeter suite
- [x] Added a clickable collapsed icon and flyout panel prototype
- [x] Added Lua-driven day view, schedule view, date switching, and scroll state with mock events
- [x] Chose PowerShell as the sync helper runtime for Windows/Rainmeter compatibility
- [x] Added a generated Lua cache file and wired the skin to load cached event data before falling back to mock data
- [x] Added an initial `Sync-GoogleCalendar.ps1` helper with working mock-cache generation and a stubbed Google mode
- [x] Replaced the stubbed Google mode with a refresh-token based Calendar API fetch path
- [x] Added an example config template for Google Calendar credentials and calendar selection
- [x] Normalized timed and all-day Google events into the cache shape consumed by the Rainmeter UI
- [x] Added a browser-based helper to obtain the initial Google refresh token using the desktop-app OAuth flow
- [x] Wired the Rainmeter refresh control to execute the PowerShell sync helper and reload the cache on completion
- [x] Added a Windows setup GUI to save credentials/config values and start the Google authorization flow without hand-editing JSON
- [x] Added a Rainmeter `SETUP` button to launch the Windows configuration and authorization GUI from the flyout
- [x] Added support for app-owned OAuth credentials via an optional `tools/GoogleCalendar.app.json` file so users do not need to enter client details when the skin is packaged professionally
- [x] Updated the setup GUI to load the signed-in user's available calendars after authorization and let them choose calendars from a checkbox list instead of typing calendar IDs manually
- [x] Updated sync to resolve selected calendar display names from the Google Calendar list so event metadata uses readable calendar labels
- [x] Fixed the live Google sync path end-to-end so selected calendars, refresh-token auth, and cache regeneration now produce real events in the Rainmeter skin
- [x] Simplified and stabilized the Rainmeter Lua layer so day view, schedule view, date navigation, settings overlay, scroll state, and cache reload all work together again
- [x] Added a dedicated settings overlay and moved setup access out of the main agenda header
- [x] Reworked event rows so the left column shows `MON DD` on the first line and an event time range on the second line
- [x] Added a persisted `use12HourTime` setting, exposed it in setup, and added an in-skin overlay toggle that rewrites config and resyncs events
- [x] Added Rainmeter-safe text sanitization so unsupported emoji are stripped from event display text instead of rendering as mojibake
- [x] Polished the collapsed icon and flyout layout, including D-pad navigation, cleaner header controls, and removal of the stray empty event row
- [x] Recorded `TIMELINE` as a stretch-goal future view mode for visual time blocks

## Open Decisions

- Cache format: stay on generated Lua cache or also emit a JSON debug copy
- Flyout behavior: keep the current instant expand/collapse or revisit animation later
- Scroll UX: keep wheel + D-pad buttons, or simplify to wheel-only
- Time-format UX: keep the 12-hour toggle in both setup and the Rainmeter overlay, or consolidate it to one surface
- Topmost behavior: determine whether Rainmeter saved skin state or a different z-order setting is overriding the skin's `DefaultAlwaysOnTop` / `!ZPos 2` settings
- Whether to keep `clientSecret` in the local config or switch fully to a PKCE-only public-client setup if Google credentials policy allows it cleanly for this desktop flow

## Recommended Next Step

Investigate the remaining always-on-top issue outside the repo files first, because the skin already sets `DefaultAlwaysOnTop=2` and runs `!ZPos 2` on refresh but can still fall behind dragged windows. After that, the next highest-value pass is UI polish: refine the collapsed icon button treatment and decide whether to keep both setup-surface and overlay-surface controls for time format.
