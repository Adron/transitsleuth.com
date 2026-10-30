# transitsleuth.com infrastructure (AWS)

```
visitor ──DNS──▶ Route 53 (transitsleuth.com zone)
        ──HTTPS─▶ CloudFront E20W0QCXZCGJGY  (ACM cert, viewer-request function)
                    └─▶ GitHub Pages: https://adron.github.io/transitsleuth.com/  (built by .github/workflows/pages.yml)
```

The domain stays **registered at WordPress.com** (Automattic); only its nameservers point at Route 53.

## Resources (AWS account 196936048600)

| Resource | ID / value |
|----------|------------|
| Route 53 hosted zone | `Z01415652KSSVPZMS4JU2` |
| Nameservers | `ns-1206.awsdns-22.org`, `ns-1645.awsdns-13.co.uk`, `ns-379.awsdns-47.com`, `ns-615.awsdns-12.net` |
| ACM certificate (us-east-1) | `arn:aws:acm:us-east-1:196936048600:certificate/31876a51-470c-4d9a-a052-657881f99411` (transitsleuth.com, www) |
| CloudFront distribution | `E20W0QCXZCGJGY` → `d3mkx1xaqftf68.cloudfront.net` |
| CloudFront function | `transitsleuth-viewer-request`; source in [`cloudfront-viewer-request.js`](cloudfront-viewer-request.js) |

CloudFront settings: origin `adron.github.io` with origin path `/transitsleuth.com`, HTTPS only. It uses
the managed CachingOptimized policy, which honors GitHub's `max-age=600`, so deploys show up within about 10
minutes without an invalidation. It also uses the managed SecurityHeadersPolicy (HSTS for 1 year, the same
as WordPress), PriceClass_100, HTTP/2+3, and IPv6.

The viewer-request function:
- 301-redirects `www.transitsleuth.com` to `transitsleuth.com`.
- Rewrites `/feed/` to `/feed.xml`, so feed readers get `application/xml`.
- Rewrites `/path/` to `/path/index.html`.
- 301-redirects extensionless paths to add the trailing slash.

To change it, edit the `.js` file, then update and publish the function (console or
`aws cloudfront update-function` + `publish-function`).

## Why CloudFront instead of pointing DNS straight at GitHub Pages

WordPress sends `Strict-Transport-Security: max-age=31536000`, so returning visitors' browsers *require*
HTTPS. GitHub Pages can only issue its Let's Encrypt certificate after DNS already points at GitHub, which
leaves a window of certificate errors that HSTS turns into hard failures. With CloudFront, the ACM
certificate is issued *before* the switch. It also gives real 301s and correct feed content types.

## Zero-downtime cutover runbook

### Phase 1: move DNS hosting only (visitors see no change)
The Route 53 zone copies the WordPress.com zone (apex A `192.0.78.24/25`, `www` and `*` CNAME to the apex),
so web answers are identical whichever nameservers a resolver uses during propagation.

**Email:** WordPress.com email forwarding only works with WordPress nameservers
([support doc](https://wordpress.com/support/add-email/email-forwarding/)), so forwarding moves to
**ImprovMX** (free plan). Route 53 has MX `10 mx1.improvmx.com` / `20 mx2.improvmx.com` and SPF
`v=spf1 include:spf.improvmx.com ~all`. Aliases, all going to adronhall@gmail.com: adron@, bikenhack@,
transitsleuth@, transittweak@. While the old nameservers are still cached, mail goes to WordPress
forwarding (still configured); after that it goes to ImprovMX, so mail keeps flowing throughout. Set up the
ImprovMX aliases **before** the nameserver change.

1. WordPress.com → **Upgrades → Domains → transitsleuth.com → Name servers**. Turn off "Use WordPress.com
   name servers" and enter the four Route 53 nameservers above.
   - **Don't** detach the domain from the WordPress site, delete the site, cancel the plan or domain, or
     turn off email forwarding. The WordPress site keeps serving transitsleuth.com through the copied A
     records, the same way `compositecode.blog` works today.
2. Check: `dig NS transitsleuth.com +short` shows the awsdns servers. The `.com` delegation TTL is 48
   hours; WordPress keeps answering for resolvers that still have the old nameservers cached.
3. The ACM certificate validates automatically once Route 53 is authoritative (`PENDING_VALIDATION` →
   `ISSUED`).
4. Send a test email to each @transitsleuth.com alias and confirm it arrives in Gmail through ImprovMX
   (the ImprovMX dashboard shows a log of delivered mail).

### Phase 2: switch the website (after Phase 1 has settled, ideally 48 hours or more)
5. Add the aliases `transitsleuth.com` and `www.transitsleuth.com` plus the ACM certificate to the CloudFront
   distribution (SNI, TLSv1.2_2021). Wait for it to deploy.
6. Test before switching: `curl -sI --resolve transitsleuth.com:443:<cloudfront-ip> https://transitsleuth.com/`.
7. In Route 53, replace the apex A records with **A + AAAA alias → CloudFront** and point `www` (CNAME or alias)
   at the distribution. Delete the `*` wildcard; it only existed for WordPress.
   Rollback = restore the A records `192.0.78.24/25` (TTL 300).
8. Leave MX and SPF (ImprovMX) alone.

### Phase 3: wrap-up (after a few weeks)
9. WordPress.com: switch the site's primary address to `transitsleuth.wordpress.com` and make the site
   private (or delete it once you're sure). Keep the **domain registration and auto-renew** at WordPress.com,
   or transfer the registration to Route 53 Domains later; either way DNS stays in Route 53.
