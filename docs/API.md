# SARIFIO API — v1 (staging contract)

Shared by the Android app, the iOS app, the website and the admin dashboard.
Base URL: `https://<staging-host>/api/v1` · JSON only · UTF-8.

**Money:** every amount is an integer in **minor units** of its currency (`USD` cents, `ETB` santim,
`KES` cents — all 2 decimals) and travels with its ISO 4217 code. **Rates** are integers in
micro-units: `1 USD = 125.50 ETB` → `125500000`. No floating point anywhere in the money path.

Authentication: `Authorization: Bearer <token>` (Laravel Sanctum personal access token) for every
route marked 🔒. Errors use one shape:

```json
{ "error": { "code": "quote_expired", "message": "This quote has expired. Please refresh." } }
```

| HTTP | `code` examples |
|---|---|
| 401 | `unauthenticated` |
| 403 | `kyc_required`, `route_disabled`, `limit_exceeded` |
| 404 | `not_found` |
| 409 | `idempotency_conflict`, `quote_already_used` |
| 410 | `quote_expired`, `otp_expired` |
| 422 | `validation_failed`, `otp_invalid`, `amount_out_of_range` |
| 429 | `too_many_requests`, `otp_resend_too_soon`, `otp_attempts_exceeded` |

---

## Authentication (name + phone, then OTP)

### `POST /auth/otp/request`
```json
{ "phone": "+252906793240", "name": "Hudayfi Mohamed", "purpose": "register", "channel": "sms" }
```
* `purpose`: `register` (needs `name`) or `login`.
* `channel`: `sms` | `whatsapp` | `email`. The server only accepts channels that are configured; `email`
  only when the account has a verified email.

Response `201`:
```json
{ "request_id": "otp_01J…", "channel": "sms", "expires_in": 300, "resend_in": 60,
  "test_code": "482913" }
```
`test_code` is returned **only** when the server runs with `APP_ENV=staging` **and**
`SANDBOX_OTP_REVEAL=true`. It is a fresh random code for that request — never a shared code.
Production refuses to start if `SANDBOX_OTP_REVEAL` is true.

Rules: 6 digits · 5 minutes · single use · 5 wrong attempts burn the code · resend after 60 s ·
max 5 requests per phone per hour and 20 per IP per hour.

### `POST /auth/otp/verify`
```json
{ "request_id": "otp_01J…", "code": "482913", "device_name": "Samsung SM-S918B" }
```
Response `200`: `{ "token": "1|…", "user": User }`

### `POST /auth/logout` 🔒 → `204` (revokes the current token)

---

## Account

### `GET /me` 🔒 → `User`
### `PATCH /me` 🔒 `{ "name": "…", "email": "…", "language": "so" }` → `User`

```json
User = { "id": "usr_…", "name": "…", "phone": "+2529…", "email": null, "email_verified": false,
         "language": "en", "kyc_status": "not_started", "limits": { "per_tx_cents": 50000, "daily_cents": 100000 },
         "created_at": "…" }
```
`kyc_status`: `not_started` | `pending` | `verified` | `rejected`. In staging, new users get sandbox limits.

---

## Configuration (public, cached 60 s)

### `GET /config`
```json
{
  "environment": "staging",
  "test_mode": true,
  "company": { "name": "SARIFIO", "tagline": "One App. Every Exchange.", "website": "sarifio.com",
               "email": "info@sarifio.com", "support_email": "support@sarifio.com",
               "phone": "+252906793240", "whatsapp": "+252906793240" },
  "fee": { "bps": 100 },
  "providers": [
    { "code": "sahal", "name": "Sahal", "group": "WaafiPay", "country": "SO", "currency": "USD",
      "status": "sandbox", "can_collect": true, "can_payout": true },
    { "code": "ebirr", "name": "eBirr", "group": null, "country": "ET", "currency": "ETB",
      "status": "sandbox", "can_collect": true, "can_payout": true },
    { "code": "mpesa", "name": "M-Pesa", "group": null, "country": "KE", "currency": "KES",
      "status": "sandbox", "can_collect": true, "can_payout": true }
  ],
  "routes": [ { "from": "sahal", "to": "ebirr", "enabled": true, "provider_fee_bps": 0 } ],
  "rates":  [ { "from": "USD", "to": "ETB", "mid_rate_micro": 125000000, "spread_bps": 50,
                "updated_at": "2026-10-16T18:00:00Z" } ],
  "announcements": [ { "id": "ann_1", "title": { "en": "…", "so": "…" }, "body": { "en": "…", "so": "…" } } ],
  "otp_channels": ["sms"]
}
```
Provider `status`: `not_configured` | `sandbox` | `testing` | `awaiting_approval` | `live` | `disabled` | `error`.
A route is offered only when it is enabled, both providers can collect/payout in the current
environment, **and** a rate exists for the currency pair. The provider list is data, not code: the
apps render whatever `/config` returns, so a new wallet (e.g. another African mobile-money
service) appears in every client once an adapter is deployed and an administrator enables it.

---

## Quotes

### `POST /quotes` 🔒
```json
{ "from": "sahal", "to": "ebirr", "amount_minor": 10000 }
```
The sending currency is the `from` wallet's currency. Response `201`:
```json
{ "id": "qt_…", "from": "sahal", "to": "ebirr",
  "currency": "USD", "receive_currency": "ETB",
  "amount_minor": 10000, "fee_bps": 100, "fee_minor": 100,
  "provider_fee_minor": 0,
  "mid_rate_micro": 125000000, "rate_micro": 124375000,
  "rate_difference_minor": 6187,
  "receive_minor": 1231313,
  "expires_at": "2026-10-16T18:30:30Z" }
```
One fee engine, used by apps, website, admin, accounting and receipts:
```
fee          = round_half_up(amount × fee_bps / 10 000)                 sending currency
provider_fee = round_half_up(amount × route.provider_fee_bps / 10 000)  sending currency
net          = amount − fee − provider_fee                              sending currency
rate         = round_half_up(mid_rate × (10 000 − spread_bps) / 10 000)
receive      = round_half_up(net × rate / 1 000 000)                    receiving currency
rate_diff    = round_half_up(net × mid_rate / 1 000 000) − receive      receiving currency
```
The 1% SARIFIO fee, provider charges and the exchange-rate difference are always reported as
separate lines. Quotes live 60 s; the transaction keeps the numbers of its accepted quote forever.
Legacy USD-only clients may send/receive `*_cents` names; they map to the `*_minor` fields.

---

## Exchanges

### `POST /exchanges` 🔒 — header `Idempotency-Key: <uuid v4>` (required)
```json
{ "quote_id": "qt_…", "recipient_account": "+252621234567", "recipient_name": "Amina" }
```
Same key + same body → the original response is replayed. Same key + different body → `409 idempotency_conflict`.

Response `201` → `Transaction`.

### `GET /exchanges?status=&cursor=` 🔒 → `{ "data": [Transaction], "next_cursor": null }`
### `GET /exchanges/{id}` 🔒 → `Transaction`

```json
Transaction = {
  "id": "tx_…", "reference": "SRF-7Q2K-91XD", "status": "payout_processing", "test": true,
  "from": { "code": "sahal", "name": "Sahal", "group": "WaafiPay" },
  "to":   { "code": "ebirr", "name": "eBirr", "group": null },
  "currency": "USD", "receive_currency": "ETB",
  "amount_minor": 10000, "fee_bps": 100, "fee_minor": 100, "provider_fee_minor": 0,
  "rate_micro": 124375000, "rate_difference_minor": 6187, "receive_minor": 1231313,
  "recipient_account": "•••• 4567", "recipient_name": "Amina",
  "events": [ { "status": "created", "at": "…" }, { "status": "awaiting_payment", "at": "…" } ],
  "failure_reason": null, "created_at": "…", "updated_at": "…"
}
```

### Status machine
```
created → quoted → awaiting_payment → payment_verified → payout_processing → settled
                         │                    │                   │
                         ├→ cancelled         ├→ manual_review    ├→ failed → refunded
                         └→ failed            └→ refunded         └→ manual_review
```
* `settled` only after the payout provider confirms through a verified webhook or status query.
* The SARIFIO fee is recognised as revenue only on `settled`; `refunded` reverses it.

---

## Support

### `POST /support/tickets` 🔒 `{ "subject": "…", "message": "…", "transaction_id": "tx_…" }` → `Ticket`
### `GET /support/tickets` 🔒 → `{ "data": [Ticket] }`
```json
Ticket = { "id": "tkt_…", "number": "T-10021", "subject": "…", "status": "open", "created_at": "…" }
```

---

## Staging-only sandbox controls (404 in production)

### `POST /sandbox/next-outcome` 🔒 `{ "outcome": "success" | "fail_payment" | "fail_payout" | "manual_review" }`
Sets what the sandbox provider does to the **next** exchange of this user.
