# Rainmeter Google Calendar

## Purpose

This repository provides a two-part Rainmeter calendar skin:

- `Calendar.ini` is a compact launcher showing the month, day, and ISO week number.
- `Flyout/Flyout.ini` is the expanded Day and Schedule interface.

Calendar data is fetched from one or more Google Calendar **Secret iCal** feeds. No Google Cloud app setup is required.

## Repository layout

```text
rainmeter-gcal/
├── Calendar.ini                 # Launcher skin
├── Flyout/Flyout.ini            # Expanded flyout skin
├── @Resources/
│   ├── Scripts/                 # Lua UI and positioning logic
│   ├── Data/                    # Local generated cache (ignored)
│   ├── Variables.inc            # Shared layout and color variables
│   └── Styles.inc               # Shared Rainmeter styles
└── tools/
    ├── Sync-IcalCalendar.ps1    # Google iCal fetch + recurrence expansion
    └── IcalCalendar.config.example.json
```

## First-time setup

1. Load `rainmeter-gcal\\Calendar.ini` in Rainmeter, open the launcher, then select **Settings** > **SETUP**.
2. The guided setup opens Google Calendar and asks for each calendar’s **Secret address in iCal format** (found in **Settings and sharing** > **Integrate calendar**).
3. Give each calendar a display name and color, then select **Save**. The private configuration is created automatically.
4. Leave **Sync calendars after saving** selected to fetch events immediately; otherwise, choose **Refresh** in the flyout later.

## Security and publishing

Secret iCal URLs grant read access to their calendar data. Never commit, publish, screenshot, or share `tools/IcalCalendar.config.json`.

The repository ignores:

- the private iCal configuration;
- generated event cache and timeline files;
- local sync output and flyout marker files.

Only the example configuration is safe to publish.

## Current functionality

- Multiple calendars with per-calendar hex colors.
- Google iCal sync with recurring-event and `BYDAY` weekly expansion.
- Day timeline with stable overlap columns, scrolling, and a current-time pill/line.
- Schedule view with six visible agenda rows.
- Responsive flyout placement that stays inside the usable Windows work area and avoids the launcher.
- 12/24-hour display toggle and ISO week number.

## Release checklist

- Verify `IcalCalendar.config.json` and generated cache files are absent from `git status`.
- Load both Rainmeter configurations from a clean setup.
- Test launcher placement in all four desktop corners.
- Refresh a feed, verify calendar colors, recurring events, Day scrolling, and Schedule scrolling.
- Package the `rainmeter-gcal` folder as an `.rmskin` or release archive.
