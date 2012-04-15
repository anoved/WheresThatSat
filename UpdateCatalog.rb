#!/usr/bin/env ruby

# This script retrieves current TLE files from Celestrak for the satellites
# defined in our catalog, satellites.txt, which is a list of satellite names
# exactly as they appear in the Celestrak files

require 'open-uri'

# load the list of TLE lists to load
fsources = open "tle_sources.txt"
tle_urls = fsources.read.split("\n")
fsources.close

catalog = {}

tle_urls.each do |tle_url|
	
	puts "Updating index: #{tle_url}"
	
	# load this TLE list
	tle_index = open tle_url
	tle_lines = tle_index.read.split("\r\n")
	tle_index.close
	
	# split into sets of three lines: NAME, 1..., 2...
	line = 0
	while line + 2 <= tle_lines.length 
	
		tle_name = tle_lines[line]
		tle_text = tle_lines[line..line+2].join("\n")
		
		# remove alternate names, status codes, and extra whitespace from name		
		tle_name.gsub!(/\(.+?\)/, "")
		tle_name.gsub!(/\[.+?\]/, "")
		tle_name.rstrip!
		
		
		# replace any non-alphanumeric characters in the name with underscores
		tle_filename = "tle/" + tle_name.gsub(/[^A-Za-z0-9]+/, "_") + ".tle"
		
		# save the tle text to tle_filename
		tle_file = open tle_filename, "w"
		tle_file.write tle_text + "\n"
		tle_file.close
		
		# Put this TLE in the catalog. Consider putting a few variations of the
		# name in the catalog - with and without hyphens, for example.
		# Avoid writing duplicates; some sats are listed in multiple indices.
		if ! catalog.include? tle_name
			catalog[tle_name] = tle_filename
		end
		
		line += 3
	end
end

# special cases - extra/popular names
catalog["International Space Station"] = "tle/ISS.tle"

# write the catalog to file
catalog_file = open "tle_catalog.txt", "w"
catalog.keys.sort.each do |key|
	catalog_file.write(format "%s\t%s\n", key, catalog[key])
end
catalog_file.close
