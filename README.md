# red bull tracker ios

native ios app for tracking red bull intake.

this is the swiftui version, not the web app version. it has login, synced entries, daily limits, themes, charts, barcode scanning, json import/export, and a bunch of small bits that make the app feel like it belongs on an iphone.

excel import/export is not part of this ios release. sync is intentionally simple right now: refresh on open, pull to refresh, and refresh after saving.

it is also not trying to be a medical app. it tracks cans, spend, caffeine, sugar estimates, and patterns. that is it.

# disclaimer

i have done no security testing or preformance optimisation. if you wish to do that, feel free to create a PR. if not ill do it sometime... i think.

## what works

- email/password accounts
- synced intake logs, refreshed on open, pull-to-refresh, and after saves
- add, edit, delete, and reset entries
- daily can/spend/stop-time limits
- quick add
- native barcode scanner
- built-in barcode lookup data
- per-user barcode mappings
- charts for spend, caffeine, flavour mix, and weekly trends
- json export/import
- keychain-backed sessions with explicit appwrite session cookie storage
- liquid glass-ish swiftui interface for newer ios, with sensible fallbacks

## backend

the app uses appwrite.

this repo does **not** include a real project id, database id, table id, api key, env file, proxy url, or anything from a private setup. the included `AppConfig.plist` is intentionally full of placeholders.

edit this before running it properly:

```text
RedBullTrackeriOS/AppConfig.plist
```

you need to fill in:

- `endpoint`
- `projectId`
- `databaseId`
- `intakeTableId`
- `barcodeTableId`

there is a `chatTableId` field because the original app had room for that shape of feature. this release does not need a secret key or server-side api key in the app. do not put one in there. seriously.

the appwrite swift auth cookie handling is annoying enough that the app grabs and stores the session cookie itself.

## appwrite shape

the intake table expects rows with roughly this shape:

- `userId`
- `cans`
- `flavour`
- `flavourAccent`
- `sizeMl`
- `pricePerCan`
- `dateTime`
- `notes`
- `store`
- `sugarFree`
- `caffeineMgPerCan`
- `importKey`
- `source`

the barcode table stores a user id, barcode, flavour, can size, price, sugar-free flag, and optional caffeine override.

row security matters. if create/read/update/delete permissions are wrong, the app will complain, and it will probably be right.

## running it

open:

```text
RedBullTrackeriOS.xcodeproj
```

then run the `RedBullTrackeriOS` scheme on an ios 17+ simulator or device.

command line build:

```sh
xcodebuild -project RedBullTrackeriOS.xcodeproj -scheme RedBullTrackeriOS -destination 'generic/platform=iOS Simulator' build
```

## tiny disclaimer

red bull is someone else's brand. this is just a tracker app. no affiliation, endorsement, secret handshake, whatever.

## notes for future me

- if the barcode data looks weird, it is because barcode data is weird

