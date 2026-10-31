# transitsleuth.com infrastructure (AWS)

```
visitor ──DNS──▶ Route 53 (transitsleuth.com zone)
        ──HTTPS─▶ CloudFront E20W0QCXZCGJGY  (ACM cert, viewer-request function)
                    └─▶ GitHub Pages: https://adron.github.io/transitsleuth.com/  (built by .github/workflows/pages.yml)

mail ──MX──▶ SES inbound (us-east-1) ──▶ S3 transitsleuth-inbound-mail-196936048600/inbound/
                                     └─▶ Lambda transitsleuth-mail-forward ──SES──▶ adronhall@gmail.com
```

The domain stays **registered at WordPress.com** (Automattic); only its nameservers point at Route 53.

## Resources (AWS account 196936048600)

| Resource | ID / value |
|----------|------------|
| Route 53 hosted zone | `Z01415652KSSVPZMS4JU2` |
| Nameservers | `ns-1206.awsdns-22.org`, `ns-1645.awsdns-13.co.uk`, `ns-379.awsdns-47.com`, `ns-615.awsdns-12.net` |
| ACM certificate (us-east-1) | `arn:aws:acm:us-east-1:196936048600:certificate/31876a51-470c-4d9a-a052-657881f99411` (transitsleuth.com, www) |
| CloudFront distribution | `E20W0QCXZCGJGY` → `d3mkx1xaqftf68.cloudfront.net`, aliases transitsleuth.com + www (live since 2026-10-31) |
| CloudFront function | `transitsleuth-viewer-request`; source in [`cloudfront-viewer-request.js`](cloudfront-viewer-request.js) |
| SES identity (us-east-1) | `transitsleuth.com` (Easy DKIM, RSA 2048; 3 `_domainkey` CNAMEs in Route 53) |
| SES receipt rule | `transitsleuth-forwarding` in the active rule set `substratal-prod-inbound` (shared, see below) |
| S3 bucket | `transitsleuth-inbound-mail-196936048600` (private, SSE-S3, `inbound/` expires after 30 days) |
| Lambda | `transitsleuth-mail-forward` (python3.13, arm64); source in [`email-forwarder/`](email-forwarder/lambda_function.py) |
| IAM role | `transitsleuth-mail-forward` (read `inbound/*`, send as transitsleuth.com, own logs) |
| Log group | `/aws/lambda/transitsleuth-mail-forward` (90-day retention) |

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

## Email forwarding (SES)

| Alias | Forwards to |
|-------|-------------|
| adron@transitsleuth.com | adronhall@gmail.com |
| bikenhack@transitsleuth.com | adronhall@gmail.com |
| transitsleuth@transitsleuth.com | adronhall@gmail.com |
| transittweak@transitsleuth.com | adronhall@gmail.com |

- DNS: MX `10 inbound-smtp.us-east-1.amazonaws.com`, SPF `v=spf1 include:amazonses.com ~all`, DMARC
  `_dmarc` `v=DMARC1; p=none;`.
- Forwarded mail arrives **From "Sender Name via Transit Sleuth" <forwarder@transitsleuth.com>**, with
  **Reply-To set to the original sender**. SES can only send from verified identities. Messages SES flags as
  spam or a virus are dropped.
- **Add or change an alias:** add the address to the receipt rule's recipients *and* to the Lambda's
  `FORWARD_MAP` environment variable (JSON).
- **Shared rule set:** SES allows one active receipt rule set per region, and `substratal-prod-inbound`
  (managed by the Substratal Terraform) is the active one in us-east-1. The `transitsleuth-forwarding` rule is
  added to it outside Terraform. Terraform doesn't remove rules it doesn't manage, but if that rule set is
  ever replaced or deactivated, re-create this rule (or move transitsleuth mail to its own rule set in
  `us-east-2`).
- **Deploy Lambda code changes:** zip `email-forwarder/lambda_function.py` and run
  `aws lambda update-function-code --function-name transitsleuth-mail-forward --zip-file fileb://fwd.zip`.

## Why CloudFront instead of pointing DNS straight at GitHub Pages

WordPress sends `Strict-Transport-Security: max-age=31536000`, so returning visitors' browsers *require*
HTTPS. GitHub Pages can only issue its Let's Encrypt certificate after DNS already points at GitHub, which
leaves a window of certificate errors that HSTS turns into hard failures. With CloudFront, the ACM
certificate is issued *before* the switch. It also gives real 301s and correct feed content types.

## Zero-downtime cutover runbook

**Status:** Phases 1 and 2 complete (2026-10-31). Phase 3 (WordPress wind-down) is manual; see `punch-list.md`.

Live DNS: apex and `www` A+AAAA alias → CloudFront; MX/SPF/DKIM/DMARC for SES; TXT `google-site-verification` (Search Console domain property; keep it).

### Phase 1: move DNS hosting only (visitors see no change)
The Route 53 zone copies the WordPress.com zone (apex A `192.0.78.24/25`, `www` and `*` CNAME to the apex),
so web answers are identical whichever nameservers a resolver uses during propagation.

**Email:** WordPress.com email forwarding only works with WordPress nameservers
([support doc](https://wordpress.com/support/add-email/email-forwarding/)), so forwarding moves to **SES**
(above). While the old nameservers are still cached, mail goes to WordPress forwarding (still configured);
after that it goes to SES, so mail keeps flowing throughout. Before the switch, the SES identity must show
DKIM `SUCCESS`. Because WordPress still answers DNS until then, the 3 `_domainkey` CNAMEs are also added
in WordPress's DNS records.

1. WordPress.com → **Upgrades → Domains → transitsleuth.com → Name servers**. Turn off "Use WordPress.com
   name servers" and enter the four Route 53 nameservers above.
   - **Don't** detach the domain from the WordPress site, delete the site, cancel the plan or domain, or
     turn off email forwarding. The WordPress site keeps serving transitsleuth.com through the copied A
     records, the same way `compositecode.blog` works today.
2. Check: `dig NS transitsleuth.com +short` shows the awsdns servers. The `.com` delegation TTL is 48
   hours; WordPress keeps answering for resolvers that still have the old nameservers cached.
3. The ACM certificate validates automatically once Route 53 is authoritative (`PENDING_VALIDATION` →
   `ISSUED`).
4. Send a test email to each @transitsleuth.com alias and confirm it arrives in Gmail "via Transit Sleuth"
   (CloudWatch log group `/aws/lambda/transitsleuth-mail-forward` shows each forward).

### Phase 2: switch the website (after Phase 1 has settled, ideally 48 hours or more)
5. Add the aliases `transitsleuth.com` and `www.transitsleuth.com` plus the ACM certificate to the CloudFront
   distribution (SNI, TLSv1.2_2021). Wait for it to deploy.
6. Test before switching: `curl -sI --resolve transitsleuth.com:443:<cloudfront-ip> https://transitsleuth.com/`.
7. In Route 53, replace the apex A records with **A + AAAA alias → CloudFront** and point `www` (CNAME or alias)
   at the distribution. Delete the `*` wildcard; it only existed for WordPress.
   Rollback = restore the A records `192.0.78.24/25` (TTL 300).
8. Leave MX, SPF, DMARC and the DKIM records (SES) alone.

### Phase 3: wrap-up (after a few weeks)
9. WordPress.com: switch the site's primary address to `transitsleuth.wordpress.com` and make the site
   private (or delete it once you're sure). Keep the **domain registration and auto-renew** at WordPress.com,
   or transfer the registration to Route 53 Domains later; either way DNS stays in Route 53.
