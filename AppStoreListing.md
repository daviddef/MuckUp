# Grub — App Store Connect Listing

Copy-paste source for App Store Connect fields. Kept in the repo (not a scratch file) so it survives across sessions.

## App Information

**Name** (30 char max)
```
Grub: Spot It, Clean It Up
```
30/30 chars.

**Subtitle** (30 char max)
```
Report litter, rally your crew
```
31 chars — trim by one if App Store Connect rejects it, e.g. "Report litter, rally your crew" → "Report litter. Rally friends." (28 chars).

**Primary Category**
```
Lifestyle
```

**Secondary Category**
```
Social Networking
```

**Bundle ID**
```
com.daviddef.grub
```

**SKU** (any unique internal string)
```
grub-ios-001
```

## Pricing and Availability

**Price**: Free
**Availability**: All territories (adjust if you want to start narrower)

## Version Information

**Promotional Text** (170 char max — editable anytime without a new build)
```
Grub just got a new look — meet your animated crawling companion! Spot a mess, raise a muck, and watch your patch go from barren to thriving.
```

**Description** (4000 char max)
```
See something. Say something. Clean it up together.

Grub turns noticing litter and hazards in your neighbourhood into something you actually want to do. Spot a mess, snap a photo, and raise a "muck" — a pinned report anyone nearby can see, help close out, or show up for.

WHAT YOU CAN DO
• Raise a Muck — photograph litter or hazards and drop a pin in seconds
• Find nearby — browse a live map of open mucks, community clean-up events, and reported hazards near you, with a one-tap "near me" view and adjustable search radius
• Schedule Events — organise a clean-up, link the mucks you're targeting, and invite your Squad
• Squads — form a group with friends, classmates, or your local community and climb a shared leaderboard
• Weekly Challenges — a fresh community-wide goal every week, with real-time progress
• Badges & streaks — build a cleaning streak and unlock badges as your impact adds up
• Patch health — your local area has a visible state, barren, growing, or thriving, driven by the real ratio of cleared vs. outstanding mucks nearby
• Grub, your companion — a small creature who lives in your patch and grows through real life stages as your community's impact grows

WHY GRUB
Litter reporting apps tend to feel like paperwork. Grub is built to feel like a game you're playing with your neighbours — see the mess, log it, watch the map change, watch your patch (and your Grub) come alive.

Your data stays private and secure with iCloud sync via Sign in with Apple. Prefer to browse without an account? Continue as a guest — your data just stays on that device. You can delete your account and data at any time from Settings.

Grub is free, ad-free, and built for real communities who want their patch to look better than they found it.
```

**Keywords** (100 char max, comma-separated)
```
litter,cleanup,community,volunteer,environment,hazard report,neighbourhood,map,squad,eco
```
90/100 chars.

**What's New in This Version**
```
New crawling Grub animation — your companion is more alive than ever. Plus: in-app account deletion, fixed photo picker when raising a muck, fixed "Back to Home" navigation, and "Link Mucks" now expands by default when scheduling an event.
```

## URLs

**Support URL**
```
https://daviddef.github.io/MuckUp/support.html
```

**Marketing URL**
```
https://daviddef.github.io/MuckUp/
```

**Privacy Policy URL** (required — also goes in the App Privacy section below)
```
https://daviddef.github.io/MuckUp/privacy.html
```

## App Privacy ("Nutrition Label")

Data types to declare as collected, all linked to the user, purpose = App Functionality:
- **Location** (Precise)
- **Photos or Videos**
- **User Content** (muck descriptions, event details)
- **Identifiers** (Apple ID via Sign in with Apple)

Declare: **not used for tracking** — no cross-app/cross-site tracking exists in Grub.

Privacy Policy URL: same as above.

## Age Rating Questionnaire

My read based on actual app content:
- Violence, mature/suggestive content, gambling, horror: **None**
- Unrestricted web access: **No**
- User-generated content (photos, muck/event descriptions, no moderation queue beyond flag/hide): answer **Infrequent/Mild** — the app does let strangers post unmoderated photos and text
- Expected result: **4+ or 9+** depending on how Apple's questionnaire logic weighs the UGC answer

## App Review Information

**Contact**: your name, phone, email

**Demo account**: not required — reviewers can tap "Continue as Guest" to bypass Sign in with Apple entirely.

### Reply to "demo account required" automated flag (12 July 2026)

The automated check flags Sign in with Apple as a login and asks for a demo account. Grub's login is OPTIONAL. Reply to the App Store Connect message AND paste this at the TOP of App Review Information → Notes (the automated re-check re-scans the Notes field):

```
Grub does not require a login to access its features. The only sign-in
option is Sign in with Apple, which is entirely optional — tapping
"Continue as Guest" on the welcome screen gives full access to all app
functionality (viewing the map, raising a muck, finding nearby events,
reporting and blocking content) with no account or credentials required.

Because there is no username/password login, a demo account is not
applicable. Reviewers can access everything by tapping "Continue as Guest."
```

### Reviewer response to Guideline 2.1 rejection (7 July 2026)

Apple asked for a screen recording plus 7 pieces of info in the Notes field before continuing review. Paste this into **App Review Information → Notes**, then attach the screen recording separately as instructed in App Store Connect.

```
Thanks for the detailed request — answers below.

ACCESS
No demo account is needed. On first launch, tap "Continue as Guest" on the
welcome screen to use the full app immediately without Sign in with Apple.
Location, camera, and photo library permission prompts appear naturally
during normal use (raising a muck, viewing the map) — no special setup
required to trigger them.

APP PURPOSE AND AUDIENCE
Grub helps community members report and coordinate cleanup of litter and
hazards in their local area. Users photograph and pin a "muck" (a litter/
hazard report), others nearby can see it on a map, help close it out, or
join a scheduled cleanup event. It's aimed at community groups, schools,
and neighbourhood volunteers who want a simple, game-like way to track
and coordinate real-world cleanup work.

CORE FEATURE FLOWS IN THE APP
- Raise a Muck: photograph litter/a hazard, add a description, and drop a
  pin at the location.
- Find nearby: browse a live map of open mucks, hazards, and community
  cleanup events near the user, with adjustable search radius.
- Schedule Events: organize a cleanup, link relevant mucks, invite a Squad.
- Squads: a group of users (e.g. friends, classmates) with a shared
  leaderboard.
- Account: Sign in with Apple (optional) syncs data via iCloud/CloudKit
  across a user's own devices; Delete Account in Settings permanently
  removes the user's mucks/events and profile.

ACCOUNT REGISTRATION, LOGIN, AND DELETION
- Registration/login: Sign in with Apple only (optional — Guest mode
  available). No separate username/password system exists.
- Deletion: Settings → Delete Account. This is a destructive action behind
  a confirmation alert; it deletes the signed-in user's owned Muck and
  MuckEvent records from the SwiftData/CloudKit store, then signs the user
  out. Guest sessions have no account to delete, so the option isn't shown
  for guests.

PAID CONTENT / SUBSCRIPTIONS
None. Grub is entirely free with no in-app purchases, subscriptions, or
paid content of any kind.

USER-GENERATED CONTENT, REPORTING, AND BLOCKING
Mucks, event descriptions, and photos are user-submitted. Moderation
controls (Guideline 1.2):
- Report: the "..." menu on any muck has "Report this Muck" — reported
  content is hidden pending review, and content passing a flag threshold
  is auto-hidden from all feeds.
- Block: the same menu has "Block this User" — blocking hides all of that
  author's content. Blocked users are listed and can be unblocked in
  Settings.
- Terms of Use with a zero-tolerance clause for objectionable content and
  abusive users is linked in Settings → About and at
  https://daviddef.github.io/MuckUp/terms.html
There is no direct user-to-user messaging.

SENSITIVE DATA / DEVICE CAPABILITY PROMPTS
- Location (While Using the App): requested when viewing the Find map or
  raising a muck, to show/place reports accurately. Purpose string:
  "Grub uses your location to show nearby mucks and events."
- Camera: requested when raising a muck to photograph litter/hazards.
  Purpose string: "Grub needs your camera to photograph mucks you report."
- Photo Library: requested when attaching an existing photo to a muck.
  Purpose string: "Grub needs photo library access to attach images to
  mucks."
- No contacts access, no App Tracking Transparency prompt — Grub does not
  track users across other apps/websites.

DEVICES AND OS TESTED
[FILL IN: e.g. "iPhone 15 Pro, iOS 18.x" and any other physical devices/
simulators you actually tested on before this submission]

EXTERNAL SERVICES / THIRD-PARTY DATA
- Apple Sign in with Apple (authentication)
- Apple CloudKit (private database sync for signed-in users' own data)
- Public environmental/event open-data feeds (Brisbane City Council,
  state parks, and similar open data council/government sources) queried
  read-only to show nearby public cleanup events — no user data is sent
  to these services beyond the device's current location for the query.
No AI services, no payment processors, no analytics/ad SDKs.

REGIONAL DIFFERENCES
None — the app functions identically in all regions. The public event
data sources are strongest in Australia (where the app was built and
tested) but the core muck-reporting and Squad features work anywhere.

REGULATED INDUSTRY / PROTECTED MATERIAL
Not applicable — Grub is a general-audience community/lifestyle app with
no regulated-industry content and no licensed third-party material.
```

**Before re-submitting**: record a screen capture on a physical iPhone (Settings → Control Center → add Screen Recording, or QuickTime with the phone plugged into a Mac via Finder's "New Movie Recording" and selecting the phone as the source). Show, in order: app launch → Continue as Guest → grant location/camera prompts as they appear → Raise a Muck end-to-end (photo + pin) → Find tab map → flagging a muck → Settings → Delete Account confirmation flow. Attach the file where App Store Connect's rejection message indicates.

## Version Release

Recommend **Manual release** so you control the exact go-live moment after approval.
