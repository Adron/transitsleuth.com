# Migration Punch List

Running checklist for moving transitsleuth.com from WordPress.com to GitHub Pages behind CloudFront, with DNS in Route 53.
See [`EXPORT_PLAN.md`](EXPORT_PLAN.md) for the details behind each item.

## 1. Export content
- [x] Export all 591 posts (through 2026-09-01) and the 3 pages from the WordPress.com API
- [x] Keep the exact WordPress permalinks, including 32 percent-encoded Unicode slugs
- [x] Download all 529 uploads (images, PDFs, .docx) to `/wp-content/uploads/` at the original paths
- [x] Convert Jetpack tiled, classic, and block galleries into a responsive grid; point attachment-page links at the files
- [x] Copy 475 hotlinked SmugMug photos into the repo (restores 118 images broken on the live site by the dead `photos.adron.me`)
- [x] Optimize images (748 MB → about 440 MB, same file names)
- [x] Record category and tag slugs so archive URLs match WordPress
- [ ] Final re-sync right before cutover: `.venv/bin/python scripts/wp_export.py all`, then commit
- [ ] Optional: export comments (WordPress.com Tools → Export → WXR) if you want them archived

## 2. Rebuild in Jekyll
- [x] Jekyll 4.4 site; posts in `posts/_posts/`
- [x] `permalink: /:year/:month/:day/:title/` (Pacific time) so future posts keep the WordPress URL pattern
- [x] Category, tag, year, month, day, and author archives at the WordPress URLs (`_plugins/wp_archives.rb`)
- [x] Home pagination at `/page/N/`, 5 per page; same posts per page as WordPress (checked pages 2, 37, 118)
- [x] RSS at `/feed/` and `/feed.xml`; `sitemap.xml`; `robots.txt`; `404.html`
- [x] SEO tags: canonical, description, Open Graph, Twitter, JSON-LD, all using `https://transitsleuth.com`
- [x] Redirect for `/transit-sleuth-tv/` (was a 301 on WordPress)
- [x] Port the WordPress **Editor** theme (stylesheet, fonts, icons, sidebar tabs, widgets, post-meta column)
- [x] Local link check: every WordPress post, page, category, and tag URL resolves; no new broken internal links
- [x] Visual check against the live site, desktop and mobile
- [x] README with how to write new posts and re-sync

## 3. Deploy to GitHub
- [x] GitHub Actions workflow (`.github/workflows/pages.yml`) builds Jekyll 4 and deploys to Pages
- [x] Push to `main` and enable Pages with **Source: GitHub Actions**
- [x] First workflow run green on GitHub Pages
- [x] Build for the site root; CloudFront serves it at the real domain (preview: https://d3mkx1xaqftf68.cloudfront.net/)

## 4. Domain and DNS (Route 53 + CloudFront; runbook in [`infra/README.md`](infra/README.md))
- [x] Route 53 hosted zone `Z01415652KSSVPZMS4JU2` with an exact copy of the WordPress.com records (A, www, `*`, MX)
- [x] ACM certificate requested for transitsleuth.com + www, DNS validation records added in Route 53
- [x] CloudFront function `transitsleuth-viewer-request` (www→apex 301, `/feed/`→XML, directory index), tested
- [x] CloudFront distribution `E20W0QCXZCGJGY` in front of GitHub Pages (no domain attached yet)
- [x] CloudFront preview checked end to end (old URLs, images, feed, 404)
- [x] Found 4 WordPress email forwards (adron@, bikenhack@, transitsleuth@, transittweak@ → Gmail); WordPress forwarding requires WordPress nameservers, so it moves to AWS SES
- [x] SES inbound forwarding built in us-east-1: identity + DKIM, S3 bucket, Lambda `transitsleuth-mail-forward`, receipt rule in `substratal-prod-inbound`
- [x] Route 53: MX → SES inbound, SPF, DMARC, DKIM CNAMEs
- [x] Add the 3 DKIM CNAMEs in WordPress DNS; SES identity verified (DKIM `SUCCESS`, 2026-10-31 01:15 UTC)
- [x] Forwarder tested: sample message for adron@ forwarded to Gmail by the Lambda via SES (direct SMTP to SES inbound blocked on port 25 locally)
- [x] **Phase 1:** WordPress.com nameservers switched to the 4 Route 53 servers (2026-10-31 01:19 UTC); nothing detached or deleted
- [x] Registry delegates to Route 53 (whois updated 2026-10-31 01:28:57 UTC); public resolvers answer from Route 53; WordPress site still loads
- [x] ACM certificate `ISSUED` (transitsleuth.com + www)
- [x] Real email test: adron@ forwarded via SES to Gmail (2026-10-31 17:05 UTC)
- [x] **Phase 2** (2026-10-31 ~17:08 UTC): domain + certificate attached to CloudFront, tested with `--resolve`, apex/www A+AAAA aliased to CloudFront, `*` wildcard deleted
- [x] `http://` and `www.` 301 to `https://transitsleuth.com/`; certificate valid (ACM, transitsleuth.com + www)
- [ ] **Phase 3** (manual in WordPress.com): delete the 4 email forwarders; export subscribers; set the site's primary address to `transitsleuth.wordpress.com`; make the site private; keep the domain registration on auto-renew

## 5. Post-cutover checks
- [x] Live crawl: 857 old URLs (all 591 posts, 3 pages, 54 categories, 120 tags, pagination, feed, sitemap, 80 uploads): all 200 from CloudFront/GitHub
- [x] FeedBurner's source is `https://transitsleuth.com/feed/`, which serves valid RSS (application/xml) from the new site
- [x] Google Search Console: domain property verified (TXT in Route 53), sitemap submitted and read (2,130 URLs discovered)
- [ ] Watch Search Console's Pages/404 reports for a few weeks
- [ ] Bing Webmaster Tools (needs your Microsoft sign-in): Import from Google Search Console
- [ ] Add any old URLs that show up as 404s in Search Console to `_data/redirects.yml`
- [ ] Keep `transitsleuth.wordpress.com` up (private or unlinked) for a few weeks as a fallback, then decide whether to delete it

## Known gaps (accepted)
- Comments, likes, sharing buttons, and Jetpack email subscriptions (107 subscribers) don't carry over. Export the subscriber list from WordPress.com if you want to email them.
- WordPress attachment pages (`/…/post-slug/image-name/`) no longer exist; images link to the files directly.
- `?p=123` and `wp.me` shortlinks can't be redirected on static hosting.
- Paginated archives (`/category/x/page/2/`) are now single, complete lists at `/category/x/`.
- Old-URL redirects in `_data/redirects.yml` use meta refresh + canonical (www→apex and trailing-slash redirects are real 301s from CloudFront).
- Links already dead on WordPress (2009 `/blogs/my_transportation_obsession/…`, `/2012/annual-report/`, 3 SmugMug images) remain dead.
