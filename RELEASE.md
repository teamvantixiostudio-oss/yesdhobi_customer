# Releasing the Yes Dhobi customer app

Everything in the repo is ready. What is left needs your developer accounts and
your signing key, which only you can hold.

| | |
| --- | --- |
| App name | Yes Dhobi |
| Android package | `com.yesdhobi.app.yes_dhobi` |
| iOS bundle id | `com.yesdhobi.app.yesDhobi` |
| Version | `1.0.0+1` (set in `pubspec.yaml`) |

---

## Before you start: two things that will cost you weeks if you skip them

**1. Check your Play Console account type — do this today.**

Open Play Console → Setup → Account details. If it is a **personal** account
created after 13 November 2023, Google will not give you production access
until you have run a closed test with **12 testers opted in continuously for
14 days**. Organisation accounts are not subject to this.

If you are on a personal account, start the closed test now. The 14 days run
in the background while everything else is prepared. Testers who opt out and
back in reset their clock.

**2. The API must be on HTTPS before the iPhone app can ship.**

The app currently talks to `http://yesdhobi-alb-…elb.amazonaws.com`. Android
tolerates that because the app declares cleartext traffic. **iOS blocks it
outright** — on an iPhone every single request fails, so the app is not merely
at risk of rejection, it does not work.

The fix is `api.yesdhobi.com` with a free ACM certificate, about 30 minutes of
work plus DNS propagation. The steps are in `backend/DEPLOY.md` section 11.3 of
the `yes-dhobi` repo. Once it is live, change `baseUrl` in
`lib/services/api_client.dart` to `https://api.yesdhobi.com/api/v1`.

Android can ship before this is done. iOS cannot.

---

## Android — Play Store

### Step 1. Create the signing key (once, ever)

```bash
keytool -genkey -v -keystore upload-keystore.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload
```

Put `upload-keystore.jks` in the `android/` folder. Then copy
`android/key.properties.example` to `android/key.properties` and fill in the
passwords you just chose.

**Back this file up somewhere safe.** If you lose the keystore you can never
publish an update to this app again — you would have to create a brand new
Play listing and every user would have to reinstall. Neither Google nor we can
recover it. Both files are gitignored, so they will never end up in the repo.

### Step 2. Build

```bash
flutter build appbundle --release
```

The file lands at `build/app/outputs/bundle/release/app-release.aab`.

If you skip step 1 the build still succeeds, but it is signed with a debug key
and Play will reject it.

### Step 3. Upload

Play Console → Create app → fill in the listing → Production (or Closed
testing, if you are serving the 14-day requirement) → upload the `.aab`.

You will be asked for the items in "Store listing content" below.

---

## iOS — App Store

**This cannot be done from a Windows machine.** Building an iOS app requires
macOS and Xcode. Your options are a Mac, or a cloud Mac service such as
Codemagic or Bitrise.

Do not start until the HTTPS change above is live, or the app will be rejected
for not working.

1. Apple Developer Program — $99/year, and verification takes a couple of days
   for a company (you need a D-U-N-S number).
2. On the Mac: `flutter build ipa --release`
3. Open `build/ios/archive/Runner.xcarchive` in Xcode → Distribute App → App
   Store Connect.
4. In App Store Connect, fill in the listing and submit for review. Review is
   usually 1–3 days.

---

## Store listing content

Prepare these once; both stores ask for roughly the same things.

- **Short description** (Play, 80 chars): Doorstep laundry pickup and delivery,
  washed and ironed by trusted local partners.
- **Full description**: Book a pickup, track your rider live, and get your
  clothes back fresh. Pay by UPI, card or cash on delivery.
- **Screenshots**: at least 2 for Play (phone), at least 3 for Apple (6.7" and
  6.5"). Take them from a real device running the app.
- **App icon**: 512×512 PNG for Play, 1024×1024 for Apple.
- **Feature graphic** (Play only): 1024×500.
- **Privacy policy URL** — **required by both stores.** You must host one, for
  example at `https://yesdhobi.com/privacy`. It has to state what you collect
  (name, phone, address, location) and why.
- **Category**: Lifestyle. **Content rating**: everyone.

### Play Data Safety answers

Answer the questionnaire with exactly this, which is what the app actually does:

| Data | Collected | Shared | Why |
| --- | --- | --- | --- |
| Name | Yes | No | Account, and so the rider knows who to meet |
| Phone number | Yes | No | Login by OTP, and contacting you about an order |
| Email | Optional | No | Account recovery |
| Address | Yes | No | Pickup and delivery |
| Approximate + precise location | Yes | No | Finding your address and live rider tracking |
| Payment info | No | No | Handled entirely by the payment gateway; we never see card details |

Everything is encrypted in transit. Users can request deletion by contacting
support — say so in the form, and make sure support actually honours it.

### Permissions, and what to say if review asks

| Permission | Why |
| --- | --- |
| `INTERNET`, `ACCESS_NETWORK_STATE` | Talking to the Yes Dhobi API |
| `ACCESS_FINE_LOCATION`, `ACCESS_COARSE_LOCATION` | Setting the pickup address accurately and showing the rider's position on the tracking map. Foreground only — the app never tracks location in the background |

---

## Before you submit, check these

- [ ] Play account type checked; closed test started if it is a personal account
- [ ] `OtpDevMode=false` on the backend — otherwise every OTP is `1234` and a
      reviewer will see it
- [ ] Privacy policy published and reachable
- [ ] A test account for the Apple reviewer (a phone number they can use, plus
      how to get the OTP) — Apple will reject an app they cannot sign into
- [ ] HTTPS live, if submitting to Apple
