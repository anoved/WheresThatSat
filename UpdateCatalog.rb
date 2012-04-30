#!/usr/bin/env ruby

require 'yaml'
require 'open-uri'
require './wtsutil.rb'

urls = YAML.load_file('config/tle_sources.yml');

# load the current catalog
catalog = WTS.load_catalog('testcatalog.yml')

# names of satellites initially present in the catalog
initial = catalog[:tle].keys

# names of new satellites added in this update
additions = []

# names of existing satellites that are updated
updates = []

urls.each do |url|
	
	# read the TLE index
	index = open url
	content = index.read.split("\r\n")
	index.close
	
	# split into sets of three lines (names + two line element set)
	line = 0
	while line + 2 <= content.length
	
		tleName = content[line]
		tleText = content[line+1..line+2].join("\n")
		
		# remove alternate names, status codes, and extra whitespace from name
		tleName.gsub!(/\(.+?\)/, "")
		tleName.gsub!(/\[.+?\]/, "")
		tleName.rstrip!
		
		if catalog[:tle].include?(tleName)
			updates.push(tleName)
		else
			additions.push(tleName)
		end
		
		catalog[:tle][tleName] = tleText
		
		line += 3
		
	end
	
end

# names of satellites to remove (present initially but no longer in indices)
removed = initial - (updates + additions)
removed.each {|oldKey| catalog[:tle].delete(oldKey)}

WTS.write_catalog(catalog, 'testcatalog.yml')
