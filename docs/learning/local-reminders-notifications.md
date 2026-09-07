# Local reminders vs remote push

Mind Mapper **19d** uses **on-device local notifications** (`UNUserNotificationCenter`). There is no APNs / FCM / Supabase push in this phase.

## Why local?

- The fire time lives in SQLite (`reminders`) and iOS’s notification scheduler.
- No server needs to know the user’s reminder text or wake the app.
- Works offline after Save.

Remote push would be for “the server has new data” — out of scope.

## Structured reminder proposal (not auto-schedule)

STORE extraction returns extra JSON fields (`should_set_notification`, title, description, datetime, recurrence). The chat bubble stays a natural ack. The app **never** schedules from extraction alone.

If the fact is remindable but the time is unclear (e.g. “ask HR about leave”), the model still sets `should_set_notification: true` and sends **`null`** for datetime. The confirm sheet shows placeholders; Save stays disabled until the user fills every field.

## Permission timing

`requestAuthorization` runs only after the user taps **Yes** on “Set a reminder?” — never on cold launch and never on STORE by itself. Denied → Settings copy + Open iOS Settings; do not re-prompt.

## Recurrence → calendar trigger

| Mode | `UNCalendarNotificationTrigger` |
|---|---|
| once | year/month/day/hour/minute, `repeats: false` |
| daily | hour + minute, repeating |
| weekly | weekday + hour + minute, repeating |
| monthly | day-of-month + hour + minute, repeating (months without that day, e.g. 31, are skipped by iOS) |

Related: [`19d-local-reminders-notifications_iOS.md`](../tasks/phase_1/19d-local-reminders-notifications_iOS.md), [`app-flow.md`](../design/app-flow.md).
