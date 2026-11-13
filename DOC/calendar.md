# Google Calendar and Google Tasks on the N900 (research, 2026-11-12)

Goal: events from a Google calendar appear in the stock Maemo Calendar, and Google Tasks appear as its tasks (the Maemo calendar has a task type; a separate application is probably not needed).
Status: the synchronisation of iCal feeds into the Maemo Calendar **works** and is the application [apps/ical-sync](../apps/ical-sync) (package `ical-sync`, GUI + cron, installed 2026-11-12; the sections below describe how it was found and designed). Still to do: Google Calendar API with OAuth (private calendars, write back), Google Tasks. Items marked *[unverified]* were not tried on the phone.

## What is on the phone

- Packages `calendar` 0.8, `calendar-backend` 0.8-6 (Nokia, C++ library `libcalendar_backend.so`, tool `calendarclt` with a numbered menu), `libical` 1.43, `libcal1`, `sqlite3` 3.6.14, `python3.11` (our build).
- The database is SQLite: `/home/user/.calendar/calendardb` (owner `user`, mode 600). Tables: `Calendars` (id, name, colour, visibility, read-only, type), `Components` (id, calendar id, type, dates as epoch seconds, summary, location, description, status, uid, until, all-day, tzid), `ComponentDetails`, `ALARM`, `RECURSIVE` (rrule, rdate, exdate), `Instances` (expanded occurrences), `Parameters`, `XProperties`, `IDMAP` (local id to external id), `Trash`, `TIMEZONE`, `Birthdays`.
- Component types (`include/Common.h`): 1 event, 2 todo, 3 journal, 4 birthday. The phone has the calendars `N900`, `cal_ti_calendar_private` and `cal_ti_smart_birthdays` (read-only, birthdays from contacts); no task is stored yet.
- The table `IDMAP` and the `Trash` table are meant for synchronisation (local id to external id; deleted items), as used by the SyncML engine.

## Sources

- **calendar-backend** (LGPL 2.1), maintained by Maemo Leste: <https://github.com/maemo-leste/calendar-backend> (C++, autotools; `include/`, `src/`, `tools/import-tool.cpp` and `tools/calendar-tool.cpp` as examples, `caltest/` with `.ics` samples). Build dependencies: `libical-dev`, `libsqlite3-dev`, `libdbus-1-dev`, `libalarm-dev`, `libtime-dev`.
- The symbols of the library on the phone match the headers of that repository, e.g. `CMulticalendar::importIcsFileData(string file, int calendarId, string& eventId, int& dupTask, int& dupEvent, int& dupJournal, int& errorCode)` (checked with `strings`). So the headers can be used to build against the Nokia library on the phone *[unverified: a test program has to run]*.
- Not in our sysroot: `calendar-backend-dev` is missing, the headers would be taken from the repository above (`-I include`, link against the library copied from the phone).
- Other sources: the Maemo 5 API reference (calendar-backend, CMulticalendar/CCalendar classes) at maemo.org/api_refs/5.0 and the old thread [SyncEvolution in Fremantle](https://lists.maemo.org/pipermail/maemo-developers/2009-December/023276.html); [bug or feature in Calendar's handling of tasks](https://lists.maemo.org/pipermail/maemo-developers/2010-January/024047.html) (an `.ics` importer through this API; tasks got a wrong DUE/DTSTART, so tasks need testing); Maemo Leste has a Qt port of the calendar ([qalendar](https://github.com/maemo-leste/qalendar)).

## Ways to put data into the Calendar

1. **`importIcsFileData` through a small C++ tool** (best first step): the tool takes an `.ics` file and a calendar name, creates the calendar when needed, imports. The library also updates the instances table and the alarms (the alarm daemon `alarmd`), which direct SQL would have to do by hand. Duplicates are counted by the library (by UID). Known: the import of tasks and of items with alarms had bugs on the N900 (forum posts), to be tested.
2. **Our own C++ tool with `CMulticalendar` / `CEvent` / `CTodo`** (`addEvent`, `addTodo`, `modifyTodo`, `deleteComponent`) for a real two-way synchronisation: map the Google id to the local id (`IDMAP`), update only changed items, delete removed ones. More work, needed for tasks (set completed, percent, due date) and for writing back.
3. Direct SQL into `calendardb`: avoided (the Calendar application and `alarmd` do not see the change, expanded instances and alarms would be missing).

## Google side

- **Calendar:** Google Calendar API (OAuth 2, REST/JSON) or the iCal "secret address" of a calendar (`.ics` URL, read only, no OAuth, the simplest start for one-way download; the secret URL has to be kept private). CalDAV with a password is gone (OAuth 2 only).
- **Tasks:** Google Tasks API (REST/JSON, OAuth 2). The OAuth *device flow* (a code typed on another device) suits the phone; the token is stored in a file readable by the user only. Python 3 with `urllib`/`ssl` is enough (CA bundle of the `curl` package, the clock must be right: `ntp-sync`).
- Google Keep is left out (no official API for private accounts, `gkeepapi` did not work earlier).

## Result of the first test (2026-11-12)

the first prototype `calimport.py FILE.ics [CALENDAR]` (now part of `apps/ical-sync/ical_sync.py`) (run on the phone as `user`, Python 3 with `ctypes`) loads `libcalendar_backend.so.0` and calls `CMulticalendar::MCInstance()`, `getCalendarByName`, `addCalendar` and `importIcsFileData` directly. No C++ compiler is needed: a `std::string` argument is made with the phone's own `libstdc++` (`_ZNSsC1EPKcRKSaIcE`, destroyed with `_ZNSsD1Ev`; on ARM EABI a std::string passed by value goes as a pointer to the caller's copy). The Str objects must stay referenced while the library uses them (a temporary is destroyed at once: this was the first crash).

`apps/ical-sync/tests/test1.ics` (2 events, one all-day weekly with `COUNT=3`, and one `VTODO` with a due date) was imported into a new calendar `Test`:
- the calendar is created (`addCalendar`, colour 2, type `LOCAL_CALENDAR`); error code 500 is `CALENDAR_OPERATION_SUCCESSFUL`;
- events go to `Components` with type 1, times in UTC epoch seconds (checked), the all-day event ends at 23:59:59, `RRULE` is stored in `RECURSIVE`;
- the task has type 2, `DateStart` = the due date, `Priority` 5;
- `Instances` stays empty (the Calendar application expands the occurrences itself).
Back-up of the database before the test: `/home/user/.calendar/calendardb.before-calimport` (on the phone).
Checked by the user in the Calendar application: the event and the task are shown (the birthdays there come from the contacts, the read-only calendar `cal_ti_smart_birthdays`, not from the import). A second import of the same file skips the items by UID (the library reports duplicates: tasks 1, events 2, error code 210; 3 items stay). `calimport.py --delete NAME` removes a calendar with its items (`deleteCalendar`); the test calendar was removed that way.
Not yet checked: an updated item with the same UID (a skipped duplicate: changes would have to be applied by deleting first), alarms, `VTODO` with `STATUS:COMPLETED`.

Consequence for the plan: **ICS is enough for both events and tasks**, so a C++ tool is probably not needed. The sync script turns Google data into `.ics` (VEVENT, VTODO) and imports; changed or deleted items are handled by deleting the items of that calendar (`deleteComponent`, `deleteCalendar`) and importing again, or through UIDs.

## Newer calendar in Maemo Leste?

No. `maemo-leste/calendar-backend` is version 0.9.1 (the last real change in 2020: compile fixes, `icaltime_is_utc`; in 2025 only CI and `debian/compat`), the same code as on the phone (0.8-6), now for modern libical. Its UI, **qalendar** (Qt 5, <https://github.com/maemo-leste/qalendar>), is a new application on the same backend, not a newer Hildon calendar. A backport is not worth it: the backend and the database format are the same, a Qt 5 UI would not run on Maemo 5, and what we need (the import) already works with the installed library. The Hildon `calendar` application (0.8) itself is Nokia closed source *[unverified]*.

## Synchronisation design: replace changed items (chosen 2026-11-12)

The library finds duplicates only by *summary + start + type + calendar* (`SELECT_DUPLICATE_ENTRY` in `DbCalls.h`), not by UID; the UID is not stored in `Components.Uid` after an import. An edited or moved Google event would be added again and the old one would stay. So the sync script keeps its own map (state file in `/home/user/.gcal-sync/`, or the `IDMAP` table):

1. Split the downloaded `.ics` into items by UID (a `VEVENT` with its `RECURRENCE-ID` overrides, a `VTODO`); keep the `VTIMEZONE` blocks; hash the text of each item.
2. New UID: import the item alone (a small `.ics`), read the ids that appeared in `Components` for that calendar (before/after, `sqlite3` module of our Python, read only), store `UID -> ids, hash`.
3. Changed hash: delete the stored ids (`CCalendar::deleteComponent`) and import the item again.
4. UID gone from the download (or cancelled/completed task, as wanted): delete its ids.
5. Unchanged: do nothing. Items that the user created in the phone calendar are not touched (only ids in the map are deleted).

## `ical-sync` (tested 2026-11-12)

Sources (iCal URLs) are in `~/.ical-sync/sources.conf` (mode 600), the map UID -> items in `~/.ical-sync/state.json`. Commands: `add NAME URL [--calendar T] [--interval MIN] [--keep-past DAYS]`, `list`, `remove NAME [--events all|future|none]`, `sync [NAME] [--force] [--dry-run] [--if-online]`.
Test with the public Czech holidays (209 events in the feed, 100 are current or future, single events that ended more than `--keep-past` days ago, default 30, max 365, are neither imported nor touched later: they stay in the calendar as they are): first sync 18 s for 100 items (one import per item); a repeated sync changes nothing; a changed hash deletes and re-imports the item; an item missing in the feed is deleted; an item deleted in the phone comes back. A sync with nothing to do (interval not elapsed, or no connection with `--if-online`) exits before the library is even loaded.

## Scheduling without draining the battery (state on the phone 2026-11-12)

On the phone: BusyBox `crond` and `crontab` exist but no job starts `crond` (not running); `alarmd` 1.1.16 (RTC alarms, wakes the phone: the clock and calendar alarms use it) and `iphbd` with `libiphb0` (the IP heartbeat: a program asks to be woken together with other network wake-ups). The cost of a sync is not the CPU: it is waking the phone and bringing up the radio. So:

1. **Only when a connection is up already** (`--if-online`: default route exists; the script never asks the connection manager, so no connection dialog and no radio switched on for the sync).
2. **`crond` (suspended phone is not woken)**: a job such as `*/30 * * * * ical-sync.py sync --if-online` costs nothing while the phone sleeps (the job runs when it wakes for another reason, late but free) and exits at once when the interval (6 h by default) has not elapsed. `crond` has to be started by an upstart job (`/etc/event.d/ical-sync`: `start on started xomap`, `exec crond -f -L /dev/null`, like `bt-kbmouse`). One more small process, no wake-ups of its own.
3. **Later, if a regular time matters:** `alarmd` (a wake-up per event; the Calendar itself uses it) or `libiphb` through `ctypes` to piggyback on other wake-ups. Not needed for an interval of hours.
4. The interval is a setting (`interval_minutes`) of each source; the GUI only edits the file, nothing else has to be rescheduled (the cron line stays the same).

## Public `.ics` for tests

The official public calendars of Google need no login and no secret, e.g. the Czech holidays: `https://calendar.google.com/calendar/ical/cs.czech%23holiday%40group.v.calendar.google.com/public/basic.ics` (checked 2026-11-12: 78 kB, 209 all-day events from 2021 on, `X-WR-TIMEZONE:UTC`). Own calendar: Google Calendar on the web → Settings → the calendar → *Integrate calendar* → *Secret address in iCal format* (private, no sharing needed; anyone who has the link can read the calendar, so it is kept in a file with mode 600 on the phone, never in the repository) or *Public address in iCal format* (only when the calendar is made public).

## Plan

1. Test program on the phone: link a C++ program against `libcalendar_backend` (headers from the Leste repository, cross build in the Workshop with the `maemo-gcc` toolchain, C++ with the glibc 2.5 sysroot) and import `caltest/ical.ics` into a test calendar; check the result in the Calendar application and with `sqlite3`. Delete the test calendar afterwards (back up `calendardb` first).
2. Python script on the phone: Google Calendar through the secret iCal URL first (no OAuth), write `.ics`, call the import tool; run from cron or an upstart job.
3. Tasks: a test of `addTodo` (due date, completed state, notes), then Google Tasks through the API, read only first.
4. OAuth 2 for the calendar API when the secret URL is not enough (private calendars, write back).
5. A hildonlite settings window (account, intervals, last sync) and a `.deb`, as for the other applications.

## Google Tasks: design notes (2026-11-13)

Status: **only thought through, nothing built**. Open points are marked *[to test]*.

- **Access:** Google Tasks has no public iCal feed, only the REST API `tasks.googleapis.com` with OAuth2. An OAuth client of type Desktop (Google Cloud project, Tasks API enabled); the `client_secret` and the refresh token go to a mode 600 file on the phone, never into git or chat. Authorise on the PC (loopback redirect) and copy only the refresh token to the phone; the device flow probably does not allow the Tasks scope *[to test]*. A project in the state "Testing" makes refresh tokens expire after 7 days, so switch it to "In production" (unverified app, a warning at sign-in, fine for personal use).
- **Mapping:** a Google task <-> a Maemo calendar item (`ComponentType` 2), kept in the same `state.json` map as the events: Google `id` and `etag`/`updated`, local component id and a hash of the fields. Task lists of Google = calendars in the phone. Incremental reading with `updatedMin`, `showCompleted`, `showDeleted`.
- **Two-way:** changes in the phone (done, title, due date, new task) are found through `Components.Status` and `ModifiedTime` and sent with `PATCH`/`POST`; a conflict is won by the newer change (`updated` of Google against `ModifiedTime`). *[to test]*: how a completed task is stored (`STATUS:COMPLETED`), notes, alarms, and a change of an existing task through `modifyTodo` or a direct write instead of delete + import (a re-import would change the identity of the item and its alarms).
- **Subtasks:** Google allows one level (`parent`). Maemo Calendar has no subtasks; `RELATED-TO` is probably ignored. Options: separate tasks with the parent in the title ("Parent > Child") and the relation kept in our map, or the subtasks as lines of the notes of the parent (then they cannot be ticked separately).
- **GUI application for tasks (planned):** a list of tasks with one level of nesting in the native look, changes written through to the calendar and to Google; ticking tasks; settings with the connection to the Google accounts. **Portrait** orientation (like the Phone application) for the list and ticking, **landscape with the keyboard** for writing new tasks; Hildon can switch the orientation (the accelerometer, `HildonPortraitFlags` / `hildon_gtk_window_set_portrait_flags`) *[to test in hildonlite]*.
- **Where:** most likely as a new source type of `ical-sync` (the same cron, state and removal dialog) plus a separate GUI for the task list.
