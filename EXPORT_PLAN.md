# Transit Sleuth — Post Export Plan

## What the site is

- **transitsleuth.com** is hosted on **WordPress.com** (not self-hosted). The underlying site is `transitsleuth.wordpress.com`, site ID `14059367`.
- The self-hosted REST route (`/wp-json/...`) returns 404. The **WordPress.com public API** works without auth for published content:
  - WP v2: `https://public-api.wordpress.com/wp/v2/sites/transitsleuth.wordpress.com/`
  - Legacy v1.1: `https://public-api.wordpress.com/rest/v1.1/sites/transitsleuth.wordpress.com/`

### Inventory (as of 2026-10-19)

| Item       | Count | Notes |
|------------|-------|-------|
| Posts      | 591   | 2009-03-19 → 2026-09-01 |
| Pages      | 3     | Optional; not "posts" but worth grabbing |
| Categories | 58    | "Wanderings" (289), "Bus Related" (115), "Bike Related" (112), "Rail Related" (110)… |
| Tags       | 732   | |
| Media      | ?     | `/media` endpoint requires auth (401), so images get pulled from post HTML instead |

Content is Gutenberg block HTML (`wp-block-paragraph`, `wp-block-heading`, etc.). Older posts (2009–2015) will be classic-editor HTML and probably contain YouTube/Vimeo embeds and WordPress.com shortcodes. The API returns them already rendered.

## Target output

```
posts/
  2009/
    2009-03-19-thursday-430pm-456pm-departure-double-unit-train/
      index.md
      images/…
  …
  2026/
    2026-09-01-every-bus-train-and-ferry-in-puget-sound-on-one-live-map/
      index.md
      images/
        featured.jpg
        …
```

Each post folder holds its own images, so a post can be moved or deleted without leaving broken links behind. `index.md` is Markdown with YAML front matter:

```yaml
---
title: "The 2 Line across Lake Washington is finally real."
date: 2026-06-03T22:25:53-07:00
modified: …
slug: the-2-line-across-lake-washington-is-finally-real
wp_id: 7424
original_url: https://transitsleuth.com/2026/06/03/the-2-line-across-lake-washington-is-finally-real/
categories: [Rail Related, sound transit, …]
tags: […]
featured_image: images/featured.jpg
excerpt: "…"
---
```

This works as-is with Hugo, Astro, Eleventy, Jekyll (with minor tweaks), or as a plain archive.

## Steps

1. **Fetch term maps.** Page through `/categories` and `/tags` (`per_page=100`) and build `id → name` maps (about 9 requests).
2. **Fetch all posts.** Page through `/posts?per_page=100&page=N&_embed=wp:featuredmedia` (6 pages). Save the raw JSON to `posts/_raw/` so it can be re-converted later without hitting the API again.
3. **Convert each post:**
   - Decode HTML entities in the title (`&nbsp;`, `&#8217;`, etc.).
   - Convert `content.rendered` from HTML to Markdown (Python `markdownify` or Node `turndown`). Remove `wp-block-*` classes and empty block spacers.
   - Keep `<iframe>` embeds (YouTube, maps) as raw HTML inside the Markdown rather than dropping them.
4. **Download images:**
   - Find every `<img src>` and `srcset` pointing to `transitsleuth.files.wordpress.com`, `transitsleuth.com/wp-content`, or `i[0-3].wp.com`.
   - Strip resize query params (`?w=…&h=…`) to get the original file.
   - Save to the post's `images/` folder and rewrite the links to relative paths. Do the same for the featured image from `_embedded`.
   - Skip duplicates, and log any 404s to `posts/_export_log.csv`.
5. **Rewrite internal links.** Change links to `transitsleuth.com/YYYY/MM/DD/slug/` to relative paths that point at the matching exported post.
6. **Verify.** Check that there are 591 `index.md` files and that no remaining image links point at WordPress.com. Spot-check about 10 posts across different years against the live site, especially older posts with embeds.
7. **Optional extras:** the 3 pages (`/pages`) and comments (v1.1 `/posts/{id}/replies`), if wanted.

## Implementation

I recommend a single Python script (`scripts/export.py`) using `requests`, `markdownify`, `beautifulsoup4`, and `pyyaml`. It should be idempotent: skip posts and images that already exist, and use a small delay between requests. The full run is about 15 API calls plus roughly 1,000–2,000 image downloads.

## The other option: WordPress.com's own export

In the WP.com dashboard, **Tools → Export → Export all** produces a WXR (XML) file plus a separate media archive. It also includes **drafts, private posts, and comments**, which the public API can't see. If drafts matter, download the WXR as well and feed it through the same conversion step. Either way, the public-API route above covers all 591 published posts without needing a login.

## Questions to settle before building

- **Output format:** Markdown with front matter (the default above), or keep raw HTML?
- **Destination:** a specific static site generator (Hugo, Astro, etc.)? This affects front-matter keys and URL/slug layout.
- **Scope:** include comments, the 3 pages, and/or drafts (which need WXR)?

---

# Hosting on GitHub Pages at transitsleuth.com (HTTPS)

## Current state (checked 2026-10-19)

- **Repo:** `git@github.com:Adron/transitsleuth.com.git` is already set up.
- **Registrar:** Automattic (WordPress.com). The domain expires 2030-04-22.
- **DNS:** nameservers are `ns1–3.wordpress.com`. The apex A records are `192.0.78.24` and `.25` (WP.com), and `www` points to the apex.
- **Email:** MX is `smtp-fwd.wordpress.com`, so WP.com email forwarding is active. **Moving DNS without carrying this over will break email to @transitsleuth.com.**

## What it takes

### 1. Build the site
GitHub Pages serves static files, so the exported Markdown needs a generator:
- **Jekyll:** GitHub builds it natively. Least setup, but slow with 591 posts and limited plugins.
- **Hugo or Astro:** fast, built by a GitHub Actions workflow and deployed with `actions/deploy-pages`. **Recommended: Hugo.** It builds ~600 posts in seconds, and page bundles (`index.md` + `images/`) match the export layout above exactly.

Keep the WordPress URL scheme so existing links and search rankings survive. In Hugo: `permalinks: posts: /:year/:month/:day/:slug/`. Category and tag archives can use `/category/:slug/` and `/tag/:slug/` to match WP.

### 2. Configure Pages on the repo
- Settings → Pages → Source: **GitHub Actions** (for Hugo/Astro).
- Custom domain: `transitsleuth.com`. With Actions deploys, set it in Settings (a `CNAME` file in the repo is only used by branch-based deploys, but adding `static/CNAME` doesn't hurt).
- Set `baseURL = "https://transitsleuth.com/"` in the generator config.
- **Verify the domain** for the Adron account (Settings → Pages → Verified domains, which adds a TXT record). This stops anyone else from claiming the domain on GitHub.
- Repo visibility: Pages from a private repo needs a paid plan. A public repo is free.

### 3. DNS changes
Records GitHub Pages needs:

| Host  | Type  | Value |
|-------|-------|-------|
| `@`   | A     | 185.199.108.153, 185.199.109.153, 185.199.110.153, 185.199.111.153 |
| `@`   | AAAA  | 2606:50c0:8000::153, 2606:50c0:8001::153, 2606:50c0:8002::153, 2606:50c0:8003::153 |
| `www` | CNAME | `adron.github.io` |
| `_github-pages-challenge-adron` | TXT | (value from GitHub's domain verification) |
| `@`   | MX    | **keep the existing email setup** (see below) |

There are two ways to make these changes:
- **A. Keep the domain at WordPress.com and edit DNS there** (Upgrades → Domains → DNS records). The apex A records are controlled by WP.com while the domain is attached to the blog, so first disconnect the domain from the WP.com site (or make the WP.com site use `transitsleuth.wordpress.com` as its primary address). Then add the records above. WP.com email forwarding keeps working because the nameservers don't change.
- **B. Transfer the domain or nameservers** to another provider (e.g. Cloudflare Registrar or Porkbun). This gives more control, but you need to recreate the MX/forwarding first (Cloudflare Email Routing, ImprovMX, etc.) or email breaks. WP.com domain transfers are also locked for 60 days after registration or transfer changes.

**Recommendation: Option A.** It's the smallest change and nothing breaks.

### 4. HTTPS
- GitHub provisions a Let's Encrypt certificate automatically once DNS resolves to GitHub. This can take from a few minutes up to about 24 hours.
- Then check **Settings → Pages → Enforce HTTPS** so http requests redirect to https.
- Remove any CAA record that excludes `letsencrypt.org` (none exist today).
- With both apex and `www` configured, GitHub redirects `www` → apex (or the reverse, depending on which one is set as the custom domain).
- Before cutover, rewrite any hard-coded `http://transitsleuth.com/...` links in posts to `https://` (or relative paths) to avoid mixed-content warnings. Embedded `http://` iframes and images should be upgraded or localized too.

### 5. Cutover order (minimizes downtime)
1. Export the posts, build the site, and deploy it. Check it at `https://adron.github.io/transitsleuth.com/` (use a temporary baseURL or a preview).
2. Verify the domain on GitHub (add the TXT record).
3. Lower the DNS TTLs, then disconnect the domain from the WP.com site and add the A/AAAA/CNAME records.
4. Set the custom domain in Pages, wait for the certificate, and turn on Enforce HTTPS.
5. Spot-check old URLs (`/2009/03/19/.../`), images, the RSS feed (`/feed/` → map with an alias or redirect page), and email forwarding.
6. Keep the WP.com site live at `transitsleuth.wordpress.com` (or set it private) as a fallback until you're satisfied.

### Things that won't carry over
- Comments become static (exported) or go away. Giscus/utterances can add new comments using GitHub Discussions.
- WP.com stats, Jetpack subscriptions, and email followers. Export the subscriber list from WP.com if you want it.
- Search: there's no server, so client-side search would use Pagefind or Hugo + Lunr.
