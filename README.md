# SARIFIO — One App. Every Exchange.

Milestone 1 source package: the Android (and iOS-ready) Flutter app with an on-device **Test Mode**,
the Laravel staging API it switches to, and the build pipeline that turns it into
`SARIFIO-Android-Test.apk`.

| Folder | What it is |
|---|---|
| `mobile/` | Flutter app (Android first; iOS from the same code in Milestone 2) |
| `backend/` | Laravel 12 staging API as an overlay + `setup.sh`, Docker staging stack |
| `docs/API.md` | The API contract shared by the apps, website and admin dashboard |
| `.github/workflows/sarifio.yml` | Cloud build: produces the APK and runs the backend tests |

---

## 1 · Get the APK onto your Samsung

A phone cannot compile a Flutter app, so the APK is built once in the cloud or on a computer.

**Option A — GitHub (no software to install, recommended)**
1. Create a private GitHub repository and upload this whole folder (keep the folder structure).
2. Open the repository → **Actions** → **SARIFIO build** → **Run workflow**.
   Leave *api_base_url* empty for the on-device Test Mode build.
3. When the run finishes (≈10 min), open it and download the **SARIFIO-Android-Test** artifact (a zip
   containing the APK). You can do this from the phone's browser while signed in to GitHub.

**Option B — your own computer**
Install Flutter (stable), Android Studio (for the Android SDK) and Java 17, then:
```bash
cd mobile
./tool/build_apk.sh            # → mobile/dist/SARIFIO-Android-Test.apk
```

**Install on the Samsung**
1. Copy `SARIFIO-Android-Test.apk` to the phone (WhatsApp to yourself, Google Drive, or USB).
2. Open it from **My Files → Downloads**.
3. When asked, allow **Install unknown apps** for the app you opened it from
   (Settings → Apps → ⋮ → Special access → Install unknown apps).
4. Tap **Install**. If Play Protect warns about an unknown developer, choose **Install anyway** —
   this is expected for a test build that is not on Google Play.

> This test build is signed with a debug key. A Play Store build needs a release keystore
> (Milestone 7).

---

## 2 · Test Mode on the phone

Every screen shows an amber **TEST MODE · no real money moves** strip.

* **Sign up:** full name + phone number (country picker defaults to Somalia +252), then choose SMS or WhatsApp.
  In Test Mode the app shows the one-time code on screen — a fresh random code for every request,
  never a shared code. Tap **Use code**.
* **Exchange:** choose *You send* and *You receive*, enter the amount and the receiving number, tap
  **Get quote**, then **Exchange Now**. The quote is locked for 60 seconds.
* **Providers in Test Mode:** Sahal and EVC Plus (WaafiPay), eDahab, Premier Wallet (USD),
  **eBirr (ETB)** and **M-Pesa (KES)**. Binance and Visa show *Coming soon*.
* **Fees:** 1% SARIFIO fee on every exchange. Provider charges and the exchange-rate difference are
  shown as separate lines. Example: $100 Sahal → eDahab = $1.00 fee, $99.00 received.
* **Simulate outcomes:** Profile → Test environment → *Next exchange result*: Success, Payment fails,
  Payout fails (money returned, no fee), Manual review.
* **Switch to the staging server:** Profile → Test environment → Server → enter the HTTPS URL of the
  staging API. Exchanges then run on the server sandbox and appear in the same account on any device.
* **Languages and themes:** Profile → Language (EN / SO) and Appearance (System / Light / Dark).

Test rates used in the sandbox (1 USD = 125 ETB, 1 USD = 129 KES, 0.5% spread) are **illustrative
test values, not market rates**. Real rates are entered by administrators.

---

## 3 · Staging API

```bash
cd backend
./setup.sh                      # fresh Laravel 12 + SARIFIO overlay → backend/app
cd app && php artisan migrate --seed && php artisan test
```
Hosting (when you choose a server): `backend/deploy/docker-compose.yml` runs the API, queue
worker, PostgreSQL, Redis and Caddy with automatic HTTPS for `staging-api.sarifio.com`.
Copy `deploy/.env.staging.example` to `deploy/.env.staging`, set passwords and an `APP_KEY`, point
DNS at the server, then `docker compose -f deploy/docker-compose.yml up -d --build`.

What the API already does: name + phone OTP (hashed, single-use, 5-minute, attempt- and
rate-limited), multi-currency quotes (USD/ETB/KES) from one fee engine, idempotent exchange creation,
the transaction state machine, a double-entry ledger with separate test and live books (fee revenue
recognised only on settlement; refunds earn no fee), sandbox provider simulation, support tickets,
company settings, and the admin **API Integration Manager** endpoints (per-provider credential
forms, encrypted write-only credentials, connection tests, logs, enable/disable, status) plus routes,
rates, fee changes (audited) and reports.

---

## 4 · eBirr and M-Pesa

* Both are full providers in the app, the API, the seed data, the ledger and reports, each in its own
  currency (ETB, KES).
* The Integration Manager has dedicated credential sections. M-Pesa's connection test requests a
  real Daraja OAuth token, so a passing test proves the keys work. eBirr's fields follow a generic
  merchant pattern and must be aligned with eBirr's official documentation once access is granted.
* **Neither can be marked live** until official API access, the provider agreement and regulatory
  approval are recorded, production credentials exist, a production connection test passes, the
  platform runs in production mode, and a *second* administrator switches it on.
* Money-moving calls (collection, payout, status, webhooks) for every real provider are deliberately
  not implemented yet: they must be written against each provider's official specification. Until then
  they raise `IntegrationNotReady` — the platform never pretends an integration works.

**Adding another African wallet later:** create one adapter class in
`backend/overlay/app/Domain/Providers/Adapters/`, register it in `config/sarifio.php`, add the
provider in the admin dashboard, and set its routes and rates. The apps read providers from
`GET /api/v1/config`, so no app update is needed.

---

## 5 · Status

**Built in this package (Milestone 1)**
- Approved branding in the app: icon (adaptive + monochrome), Android 12+ and legacy splash, animated
  in-app splash, Sora/Manrope fonts.
- Onboarding, name + phone registration, OTP verification, login, remembered session, logout.
- Home, Exchange (quote expiry and refresh, 1% fee, provider charges, FX difference), live progress
  tracking, receipts, history with filters, support (WhatsApp / call / email, tickets, FAQ), profile,
  legal drafts, English/Somali, light/dark.
- On-device Test Mode engine and the HTTPS staging client behind one interface.
- Laravel staging API, provider registry, eBirr/M-Pesa adapters, ledger, tests, Docker staging stack.

**Verified here:** every Dart file parses; every PHP file passes `php -l`; the fee/FX arithmetic was
run and matches the 1% table. **Not verified here:** this workspace cannot download Flutter, the
Android SDK or Composer packages, so the first `flutter build` / `php artisan test` run (GitHub
Actions or your computer) is the first full compile. Report any error from that run and it will be fixed.

**Still to do**
- Milestone 2: KYC flow, notifications/push, saved recipients, biometrics, iOS/TestFlight setup.
- Milestone 3: SARIFIO.com website and customer web app.
- Milestone 4: admin dashboard UI (the API endpoints exist), staff MFA, expenses, full reporting.
- Milestone 5: website/app CMS beyond the company profile and announcements.
- Real provider integrations once official specifications, agreements and approvals are in hand.
- Native-speaker review of the Somali copy.
