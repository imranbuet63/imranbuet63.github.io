#!/usr/bin/env ruby
# frozen_string_literal: true

# Converts every BibTeX file in _data into the publication data used by Jekyll.
# Run: ruby scripts/generate_publications.rb

require "yaml"

DATA_DIR = File.expand_path("../_data", __dir__)
OUTPUT = File.join(DATA_DIR, "publications.yml")

def bib_entries(text)
  entries = []
  offset = 0

  while (start = text.index(/@\w+\s*\{/, offset))
    open_brace = text.index("{", start)
    depth = 0
    finish = nil

    (open_brace...text.length).each do |index|
      case text[index]
      when "{" then depth += 1
      when "}"
        depth -= 1
        if depth.zero?
          finish = index
          break
        end
      end
    end

    break unless finish

    entries << text[start..finish]
    offset = finish + 1
  end

  entries
end

def fields_for(entry)
  body = entry[(entry.index("{") + 1)...-1]
  body = body[(body.index(",") + 1)..]
  fields = {}
  index = 0

  while index < body.length
    index += 1 while index < body.length && (body[index] == "," || body[index] =~ /\s/)
    break if index >= body.length

    name_start = index
    index += 1 while index < body.length && body[index] != "="
    name = body[name_start...index].strip.downcase
    index += 1
    index += 1 while index < body.length && body[index] =~ /\s/
    break if index >= body.length

    if body[index] == "{"
      value_start = index + 1
      depth = 1
      index += 1
      while index < body.length && depth.positive?
        depth += 1 if body[index] == "{"
        depth -= 1 if body[index] == "}"
        index += 1
      end
      fields[name] = body[value_start...(index - 1)]
    elsif body[index] == '"'
      value_start = index + 1
      index += 1
      index += 1 while index < body.length && body[index] != '"'
      fields[name] = body[value_start...index]
      index += 1
    else
      value_start = index
      index += 1 while index < body.length && body[index] != ","
      fields[name] = body[value_start...index].strip
    end
  end

  fields
end

def clean_text(value)
  value.to_s.gsub(/\\textbf\{([^}]*)\}/, "\\1")
       .gsub(/[{}]/, "")
       .gsub(/\\&/, "&")
       .gsub(/\\/, "")
       .gsub(/\s+/, " ")
       .strip
end

def format_authors(value)
  clean_text(value).split(/\s+and\s+/).map do |author|
    parts = author.split(",").map(&:strip)
    parts.length > 1 ? "#{parts[1..].join(' ')} #{parts[0]}" : author
  end.join(", ").gsub("Imran Khan", "<strong>Imran Khan</strong>")
end

publications = Dir.glob(File.join(DATA_DIR, "*.bib")).flat_map do |path|
  bib_entries(File.read(path)).map do |entry|
    fields = fields_for(entry)
    next unless fields["title"] && fields["author"] && fields["year"]

    {
      "title" => clean_text(fields["title"]),
      "venue" => clean_text(fields["booktitle"] || fields["journal"] || fields["series"] || "Poster"),
      "authors" => format_authors(fields["author"]),
      "year" => fields["year"].to_i
    }
  end.compact
end

publications.sort_by! { |publication| [-publication["year"], publication["title"]] }
File.write(OUTPUT, "# Generated from _data/*.bib by scripts/generate_publications.rb. Do not edit manually.\n" + YAML.dump(publications))
puts "Generated #{OUTPUT} with #{publications.length} publications."
