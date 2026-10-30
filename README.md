# Transit Sleuth

The [transitsleuth.com](https://transitsleuth.com) blog: a Jekyll site that replaces the old WordPress.com site,
built and deployed to GitHub Pages by `.github/workflows/pages.yml` on every push to `main`.

## Layout

| Path | What it is |
|------|------------|
| `posts/_posts/` | All posts. Imported WordPress posts are `.html`; new posts can be `.md`. |
| `posts/_drafts/` | Unpublished drafts (`jekyll serve --drafts` to preview). |
| `about/`, `the-fleet/`, `disclaimer-and-manifesto/` | The WordPress pages. |
| `wp-content/uploads/` | Images and files, at the same paths WordPress used. |
| `_layouts/`, `_includes/`, `assets/` | Port of the WordPress **Editor** theme (Automattic, GPL). |
| `_plugins/wp_archives.rb` | Generates `/category/…/`, `/tag/…/`, `/YYYY/MM/…/`, `/author/adron/`, redirects, `/feed/`. |
| `_data/` | Navigation, blogroll, WordPress category/tag slugs, old-URL redirects. |
| `scripts/wp_export.py` | Re-runnable WordPress exporter (see below). |
| `_wp_export/` | Raw API dump plus image download logs (not published). |

## Writing a new post

Create `posts/_posts/YYYY-MM-DD-your-slug.md`:

```markdown
---
title: "Your Post Title"
date: 2026-11-01 09:30:00 -0700
categories: [Rail Related, sound transit]
tags: [light rail, seattle]
image: /wp-content/uploads/2026/11/hero.jpg   # optional featured image (also used for social cards)
description: "One or two sentences for search results and social cards."
---

Post body in Markdown.
```

It's published at `https://transitsleuth.com/YYYY/MM/DD/your-slug/`, the same URL pattern WordPress used
(`permalink: /:year/:month/:day/:title/` in `_config.yml`, in Pacific time). Put images under
`wp-content/uploads/YYYY/MM/`. Existing category/tag names reuse their old WordPress archive URLs; new ones
get a slug automatically.

## Running locally

```sh
bundle install
bundle exec jekyll serve          # http://localhost:4000
```

## Re-syncing from WordPress

While the WordPress.com site is still up, this pulls any new or edited posts:

```sh
python3 -m venv .venv && .venv/bin/pip install requests beautifulsoup4 pyyaml lxml
.venv/bin/python scripts/wp_export.py all      # fetch, convert, images, optimize (needs ImageMagick)
```

Each step can also be run on its own: `fetch`, `convert`, `images`, `optimize`.
