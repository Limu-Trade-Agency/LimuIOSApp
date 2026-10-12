# App Store screenshots — Limu Mobile 1.0

## Source

[`Limu-Android-Screenshots.zip`](https://drive.google.com/file/d/15mxlGFeZKv3dugP0DAvCp9L7uEbw7gvx/view)
(42.6 MB, owner `management@limu.co.mw`). Despite the filename these are **iOS simulator captures** —
they were taken from the iOS build and handed over as the visual reference for building a one-to-one
Android copy of the app. So they are genuine iOS screenshots and the shot list below is already
proven to exist.

The file is not publicly shared, so it could not be opened from here to check the images
themselves. One thing still has to be verified before they can be uploaded.

## Verify the capture size first

App Store Connect accepts a fixed set of pixel dimensions and silently rejects everything else.
What matters is **which simulator** these were captured on.

| Simulator | Pixels (portrait) | Accepted by App Store? |
| --- | --- | --- |
| iPhone 17 Pro **Max** | 1320 × 2868 | **Yes** — this is the 6.9" slot |
| iPhone 16 Pro Max / 15 Pro Max | 1290 × 2796 | **Yes** — also the 6.9" slot |
| iPhone 17 Pro | 1206 × 2622 | **No** — 6.3", not an upload size |
| iPhone 17 / 16 | 1179 × 2556 | **No** |

`iOS_Test_Execution_Log.docx` records the test pass running on an **iPhone 17 Pro** (check D4), which
is the 6.3" device — not an accepted size. If that is also what these captures came from, the set
has to be retaken on a Pro Max simulator. Same screens, same account, one different device: about
twenty minutes of work.

Check before doing anything else:

```bash
unzip -l Limu-Android-Screenshots.zip | head -30
sips -g pixelWidth -g pixelHeight *.png    # macOS
python -c "from PIL import Image,glob; [print(f, Image.open(f).size) for f in glob.glob('*.png')]"
```

If the answer is 1320 × 2868 or 1290 × 2796, the set is usable as-is and this is done. Anything
else, recapture per the procedure below.

## Required sizes

The target ships `TARGETED_DEVICE_FAMILY = "1,2"` — iPhone **and** iPad — so **both** sets are
required. If iPad support is not actually wanted for 1.0, changing that setting to `"1"` removes the
iPad requirement entirely and halves this work. Worth deciding before anyone starts capturing.

| Display | Pixels (portrait) | Capture on | Required? |
| --- | --- | --- | --- |
| iPhone 6.9" | 1290 × 2796 **or** 1320 × 2868 | iPhone 17 Pro Max simulator | **Yes** |
| iPad 13" | 2064 × 2752 **or** 2048 × 2732 | iPad Pro 13-inch (M4) simulator | **Yes**, while the target includes iPad |

Apple scales the 6.9" iPhone set down to cover every smaller iPhone, so no other iPhone size is
needed. Between three and ten images per size; ten is the maximum.

### Hard requirements

- Exact pixel dimensions, RGB, flattened, no alpha channel. PNG or JPEG.
- No device frames, no drop shadows, no rounded-corner masks, no marketing chrome around the edge.
- The status bar must look real and clean. Simulator screenshots are fine; override the clock with
  `xcrun simctl status_bar` (below) before capturing.
- No placeholder, lorem-ipsum or obviously fake content, and no other company's trademarks.

## Shot list

Eight shots, in this order. The order in App Store Connect is the order shoppers see, and the first
two carry almost all the weight. Cross-check against the Android reference set — if a screen is
missing there, it is missing here too.

| # | Screen | How to reach it | Caption |
| --- | --- | --- | --- |
| 1 | Home dashboard | Sign in with a KYC-complete account | **Every consignment, one screen** |
| 2 | Cargo list | Cargo tab | **Follow your cargo from booking to delivery** |
| 3 | Cargo detail with timeline | Tap any cargo row, scroll to the timeline | **See exactly where it has been** |
| 4 | Shipments list | Shipments tab | **Live shipment status and location** |
| 5 | Order forms list, filters visible | Order Forms tab | **Every order form, sorted by stage** |
| 6 | Order form review with item photos | Open an order form in Client Review | **Review and approve, item by item** |
| 7 | Notifications centre | Bell icon from Home | **Know the moment something moves** |
| 8 | Profile / KYC | Profile tab | **Your details, kept current** |

Captions are optional — App Store Connect has no caption field, so text has to be burned into the
images during design. Plain unannotated screenshots are acceptable and are the lower-risk option
for 1.0.

## Data prerequisite

Shots 1–7 need an account with **real cargo, shipment, order-form and notification records**. The
test account used for the first testing pass had none, which is exactly why F12–F16 came back
blocked. Empty states make terrible screenshots and Apple has rejected listings for showing them.

Use either an existing live client account with history, or a local backend seeded from
`limutradee (1).sql` with `--local-api`. If the local route is used, check every shot for
`localhost` URLs or obviously synthetic names before uploading.

**Do not** capture with `--logged-in`. That launch flag serves `MockData`, and shipping mock
content in a store listing is both dishonest and a rejection risk.

## Capture procedure

```bash
# 1. Boot the device and clean up the status bar
xcrun simctl boot "iPhone 17 Pro Max"
xcrun simctl status_bar "iPhone 17 Pro Max" override \
  --time 9:41 --batteryState charged --batteryLevel 100 \
  --cellularBars 4 --wifiBars 3

# 2. Run the app, sign in, navigate to each screen, and capture
xcrun simctl io "iPhone 17 Pro Max" screenshot 01-home.png

# 3. Confirm the dimensions before uploading
sips -g pixelWidth -g pixelHeight 01-home.png
```

Repeat for `iPad Pro 13-inch (M4)`. Store the results in `docs/release/screenshots/ios/6.9/` and
`docs/release/screenshots/ios/13/`, named `01-home.png` … `08-profile.png` so the upload order is
unambiguous.

## Note for the Android copy

The same shot list applies to the Play Store listing, at Google's sizes rather than Apple's: phone
screenshots between 320 px and 3840 px on the long edge with a 16:9 to 9:16 aspect ratio, plus a
1024 × 500 feature graphic that has no App Store equivalent. Capture those from the Android build
once it exists — reusing the iOS captures on Play would show iOS status bars and tab bars, which is
the same mistake in the other direction.

## Status

**Blocked on the size check above.** If the existing captures are 6.9", the iPhone set is done and
only the iPad set remains. Everything else — iPad, or a full recapture — needs a Mac running Xcode
and an account with real data, neither of which is available on the current Windows workstation.
