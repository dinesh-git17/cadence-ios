# AASA Spec & Hosting Requirements — Cadence

## File Location

Serve the file at **both** paths. iOS 9–10 fetched from the root; iOS 11+
fetches from `.well-known/`. Both must return 200 with no redirect:

```
https://cadence.dineshd.dev/.well-known/apple-app-site-association   ← primary
https://cadence.dineshd.dev/apple-app-site-association               ← iOS 9/10 legacy
```

## Hosting Requirements

| Requirement | Detail |
|---|---|
| Protocol | HTTPS only. HTTP is never consulted. |
| Status code | 200. Any redirect (301, 302) causes iOS to abort — it does not follow redirects. |
| Content-Type | `application/json` — required. Do not use `application/pkcs7-mime` (that's the old signed format, deprecated). |
| Cache-Control | Set a short `max-age` on your origin (e.g. `max-age=3600`). Apple's CDN ignores this and caches aggressively (~24h), but your CDN/proxy should still serve the file quickly. |
| File size | Keep under 128KB (Apple limit). The Cadence file is tiny — not a concern. |
| No authentication | The file must be publicly accessible. No auth headers, no cookies. |

## Full AASA File

```json
{
  "applinks": {
    "details": [
      {
        "appIDs": [
          "ABCDE12345.com.dineshd.cadence"
        ],
        "components": [
          {
            "/": "/invite/*",
            "comment": "Partner invite deep links — single-use tokens"
          }
        ]
      },
      {
        "appID": "ABCDE12345.com.dineshd.cadence",
        "paths": ["/invite/*"]
      }
    ]
  }
}
```

Replace `ABCDE12345` with the real Team ID from the Apple Developer portal
(Membership → Team ID). This is a 10-character alphanumeric string.

**Why two entries?**
- The `appIDs` + `components` block is parsed by iOS 14+.
- The `appID` + `paths` block is the iOS 9–13 fallback.
- iOS 14+ ignores the legacy block. iOS 9–13 ignores the modern block.
- Both are safe to include in the same `details` array.

## If You Add a Beta Bundle ID

If a separate scheme with bundle ID `com.dineshd.cadence.beta` is used for
internal builds, add it to the modern `appIDs` array only. You do not need a
second legacy entry:

```json
"appIDs": [
  "ABCDE12345.com.dineshd.cadence",
  "ABCDE12345.com.dineshd.cadence.beta"
]
```

## Supabase / CDN Hosting Notes

If the domain is served via Supabase Storage or a CDN (Cloudflare, Fastly, etc.),
verify the CDN is not stripping or overriding the `Content-Type` header.
Cloudflare in particular may serve `.json` files with `text/plain` if the MIME
type isn't explicitly configured. Set a page rule or transform rule to force
`Content-Type: application/json` for the AASA path.

Also confirm the CDN does not serve the AASA behind a login challenge or
challenge page (Cloudflare "I'm Under Attack" mode will break this).

## Verification Commands

Run these before TestFlight and before App Store submission.

**Fetch and inspect from your machine:**
```bash
curl -sI https://cadence.dineshd.dev/.well-known/apple-app-site-association
# Expect: HTTP/2 200, content-type: application/json
# Must NOT see: location header (redirect)

curl -s https://cadence.dineshd.dev/.well-known/apple-app-site-association | python3 -m json.tool
# Expect: valid JSON, no error
```

**Validate with Apple's swcutil on a physical device:**
Open Xcode → Window → Devices and Simulators → select device → open console, then
tap a `https://cadence.dineshd.dev/invite/anytoken` link. Look for log lines from
`swcd` (the shared web credentials daemon):
```
swcd[...] Fetching app-site-association for cadence.dineshd.dev
swcd[...] App-site-association for cadence.dineshd.dev is valid
```

If you see "failed to fetch" or "invalid", the AASA file or headers are wrong.

**Online validators (useful for CI pre-checks):**
- https://branch.io/resources/aasa-validator/
- https://yurl.chayev.com

## CDN Cache Propagation

Apple fetches the AASA through `app-site-association.cdn-apple.com`. The cache
TTL is approximately 24 hours. After deploying a new AASA:

- New installs will pick up the new file after CDN expiry (~24h)
- Existing installs re-check periodically (app launch + install)
- You cannot force a cache bust on user devices
- For urgent changes, deploy quickly and accept the propagation delay
- Never rely on AASA changes taking effect immediately in production

During development, `?mode=developer` in the entitlement bypasses this CDN
entirely and fetches directly from your server — making changes instant.
