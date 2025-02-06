#!/usr/bin/env ruby
require 'nokogiri'
require 'csv'
require 'pry'

# Usage: ruby script.rb "<input file pattern>" output.csv
if ARGV.size < 2
  puts "Usage: #{__FILE__} \"<input file pattern>\" output.csv"
  exit 1
end

files = ARGV
output_file = files.pop

CSV.open(output_file, "w", write_headers: true, headers: ["first name", "last name", "linkedin URL", "Event"]) do |csv|
  files.each do |input_file|
    puts "Processing file: #{input_file}"
    html = File.read(input_file)
    doc  = Nokogiri::HTML(html)

    # Process each <li> element in the file
    doc.css('li').each do |li|
        # Select the anchor without aria-hidden that contains "linkedin.com/in/"
        a = li.at_css('a:not([aria-hidden])[href*="linkedin.com/in/"]')
        next unless a  # skip if not found

        # The visible name is inside a <span> with aria-hidden="true"
        name_span = a.at_css('span[aria-hidden="true"]')
        next unless name_span

        full_name = name_span.text.strip
        # Remove extra text after a comma (e.g. "Harris, MBA" becomes "Harris")
        full_name = full_name.split(',').first.strip

        # Split the name into words; choose the first word as the first name and the last word as the last name.
        name_parts = full_name.split
        # Optionally remove parts with a dot (like initials) if desired
        name_parts.select! { |s| s !~ /\./ }
        next if name_parts.empty?  # skip if no name remains

        first_name = name_parts.first
        last_name  = name_parts.size > 1 ? name_parts.last : ""

        # Skip rows if the first name is "LinkedIn"
        next if first_name.downcase == "linkedin"

        linkedin_url = a['href']
        csv << [first_name, last_name, linkedin_url, 'Las Vegas Investor Conference']
        csv.flush
    end
  end
end

puts "CSV file written to #{output_file}"
