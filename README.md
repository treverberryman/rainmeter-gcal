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

1. Load `rainmeter-gcal\\Calendar.ini` in Rainmeter, open the launcher, then select **Settings** > **SETUP**. This creates a private `tools/IcalCalendar.config.json` from the example and opens it.
2. In Google Calendar, open **Settings and sharing** for each calendar, then copy its **Secret address in iCal format**.
3. Add each URL, display name, and `#RRGGBB` color to `IcalCalendar.config.json`, then save the file.
4. Return to the flyout and select **Refresh**. The local event cache and any additional timeline slots are generated automatically.

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
