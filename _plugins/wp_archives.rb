# Generates WordPress-compatible archive pages:
#   /category/<slug>/   /tag/<slug>/   /YYYY/   /YYYY/MM/   /YYYY/MM/DD/
# Category/tag slugs come from _data/wp_taxonomy.yml (exported from WordPress) so the
# old URLs keep working; anything new falls back to a WordPress-style slug.
module TransitSleuth
  class ArchivePage < Jekyll::PageWithoutAFile
    def initialize(site, dir, data)
      super(site, site.source, dir, "index.html")
      self.content = ""
      self.data = { "layout" => "archive" }.merge(data)
    end
  end

  class ArchiveGenerator < Jekyll::Generator
    safe true
    priority :low

    def self.wp_slug(name)
      Jekyll::Utils.slugify(name.to_s.gsub("&", " "), mode: "latin")
    end

    def self.norm(name)
      name.to_s.dup.force_encoding("UTF-8").unicode_normalize(:nfc)
    end

    # Exact WordPress slug for a category/tag name, or a WordPress-style slug for new terms.
    def self.term_slug(site, name, kind)
      map = site.config[kind == "tag" ? "tag_slugs" : "category_slugs"] || {}
      map[norm(name)] || wp_slug(name)
    end

    def generate(site)
      tax = site.data["wp_taxonomy"] || {}
      cat_slugs = (tax["categories"] || {}).transform_keys { |k| self.class.norm(k) }
      tag_slugs = (tax["tags"] || {}).transform_keys { |k| self.class.norm(k) }
      site.config["category_slugs"] = cat_slugs
      site.config["tag_slugs"] = tag_slugs

      {
        "category" => [site.categories, "Category"],
        "tag" => [site.tags, "Tag"],
      }.each do |kind, (index, label)|
        seen = {}
        index.each do |name, posts|
          slug = self.class.term_slug(site, name, kind)
          next if slug.empty?
          if seen[slug]
            seen[slug].data["posts"] = (seen[slug].data["posts"] + posts).uniq.sort_by(&:date).reverse
            next
          end
          page = ArchivePage.new(site, "#{kind}/#{slug}", {
            "title" => "#{label}: #{name}",
            "posts" => posts.sort_by(&:date).reverse,
          })
          seen[slug] = page
          site.pages << page
        end
      end

      # Old WordPress URLs that redirected elsewhere (_data/redirects.yml: "/old/path/": "/new/path/").
      (site.data["redirects"] || {}).each do |from, to|
        page = Jekyll::PageWithoutAFile.new(site, site.source, from.to_s.sub(%r{^/}, ""), "index.html")
        page.content = ""
        page.data = { "layout" => "redirect", "redirect_to" => to, "sitemap" => false }
        site.pages << page
      end

      # Single-author blog: WordPress's author archive lists every post.
      site.pages << ArchivePage.new(site, "author/adron", {
        "title" => "Author: Adron",
        "posts" => site.posts.docs.sort_by(&:date).reverse,
      })

      by = Hash.new { |h, k| h[k] = [] }
      site.posts.docs.each do |post|
        d = post.date
        by[[d.strftime("%Y")]] << post
        by[[d.strftime("%Y"), d.strftime("%m")]] << post
        by[[d.strftime("%Y"), d.strftime("%m"), d.strftime("%d")]] << post
      end
      by.each do |parts, posts|
        date = Time.new(*parts.map(&:to_i))
        title = case parts.size
                when 1 then "Year: #{parts[0]}"
                when 2 then "Month: #{date.strftime('%B %Y')}"
                else "Day: #{date.strftime('%B %-d, %Y')}"
                end
        site.pages << ArchivePage.new(site, parts.join("/"), {
          "title" => title,
          "posts" => posts.sort_by(&:date).reverse,
        })
      end
    end
  end
end

module TransitSleuth
  module Filters
    # {{ name | term_slug: "category" }} -> slug used in /category/<slug>/
    def term_slug(name, kind = "category")
      ArchiveGenerator.term_slug(@context.registers[:site], name, kind)
    end
  end
end
Liquid::Template.register_filter(TransitSleuth::Filters)

# WordPress served its RSS feed at /feed/. Keep that URL alive alongside /feed.xml.
Jekyll::Hooks.register :site, :post_write do |site|
  src = File.join(site.dest, "feed.xml")
  if File.exist?(src)
    dir = File.join(site.dest, "feed")
    FileUtils.mkdir_p(dir)
    FileUtils.cp(src, File.join(dir, "index.html"))
  end
end

