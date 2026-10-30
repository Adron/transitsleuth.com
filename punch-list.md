# Migration Punch List

Running checklist for moving transitsleuth.com from WordPress.com to GitHub Pages.
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
- [x] First workflow run green; site live at https://adron.github.io/transitsleuth.com/ (images inside posts only resolve once the custom domain is set)

## 4. Domain and DNS
- [ ] Verify `transitsleuth.com` for the Adron GitHub account (Settings → Pages → Verified domains; add the TXT record)
- [ ] Lower the DNS TTL a day ahead
- [ ] Detach the domain from the WordPress.com site (or make `transitsleuth.wordpress.com` its primary address)
- [ ] In WordPress.com DNS, replace the apex A records with GitHub's 4 A and 4 AAAA records; point `www` CNAME at `adron.github.io`
- [ ] **Keep the MX record and email forwarding**; send a test email to an @transitsleuth.com address after the change
- [ ] Set the custom domain `transitsleuth.com` in repo Settings → Pages
- [ ] Wait for the certificate, then turn on **Enforce HTTPS**
- [ ] Check that `http://`, `www.` and `https://` all end up at `https://transitsleuth.com/`

## 5. Post-cutover checks
- [ ] Spot-check old URLs on the live domain: a 2009 post, a Unicode-slug post, `/page/119/`, `/category/wanderings/`, `/tag/seattle/`, `/2013/11/`, an image, a PDF
- [ ] Update FeedBurner's source feed to `https://transitsleuth.com/feed.xml` (GitHub serves `/feed/` as text/html, which FeedBurner may not accept)
- [ ] Google Search Console: verify the domain, submit `https://transitsleuth.com/sitemap.xml`, and watch the Pages/404 reports for a few weeks
- [ ] Bing Webmaster Tools: submit the sitemap (the site already has an `msvalidate` tag on WordPress, which isn't carried over; re-verify via DNS)
- [ ] Add any old URLs that show up as 404s in Search Console to `_data/redirects.yml`
- [ ] Keep `transitsleuth.wordpress.com` up (private or unlinked) for a few weeks as a fallback, then decide whether to delete it

## Known gaps (accepted)
- Comments, likes, sharing buttons, and Jetpack email subscriptions (107 subscribers) don't carry over. Export the subscriber list from WordPress.com if you want to email them.
- WordPress attachment pages (`/…/post-slug/image-name/`) no longer exist; images link to the files directly.
- `?p=123` and `wp.me` shortlinks can't be redirected on static hosting.
- Paginated archives (`/category/x/page/2/`) are now single, complete lists at `/category/x/`.
- GitHub Pages can't send real 301s; redirects use meta refresh + canonical, which Google treats as permanent.
- Links already dead on WordPress (2009 `/blogs/my_transportation_obsession/…`, `/2012/annual-report/`, 3 SmugMug images) remain dead.
