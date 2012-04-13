#!/usr/bin/env ruby

require 'rubygems'
require 'chatterbot/dsl'

# for url encoding
require 'cgi'

#debug_mode
verbose
# Ignore our own tweets to prevent a silly cycle of self-replies
blacklist "wheresthatsat"

def TheresThatSat(satellite_name, satellite_tle, timestamp, tweet)

	# basic command
	tle_dir = File.expand_path(satellite_tle)
	gtg_cmd = format '/usr/local/bin/gtg --input "%s" --start "%s" --format csv --attributes altitude', tle_dir, timestamp
	
	# if the tweet is georeferenced, pass its coordinates to gtg as the
	# observer location and ask for elevation/azimuth attributes
	# geo documented here: https://dev.twitter.com/docs/api/1/get/statuses/show/%3Aid
	#if tweet[:geo] != nil
	#	observer_latitude = tweet[:geo][:coordinates][0]
	#	observer_longitude = tweet[:geo][:coordinates][1]
		# append this junk to the pipe; after the pipe, have another conditional to insert obs angle to reply
	#	gtg_cmd += format " --observer %s %s --attributes elevation azimuth", observer_latitude, observer_longitude
	#end
			
	# run gtg to get the coordinates and attribute information.
	# needs error handling
	gtg_pipe = IO.popen(gtg_cmd)
	gtg_data = gtg_pipe.read.split("\n")
	gtg_pipe.close
	
	# split the output lines into fields, and find the first [only] record
	# should confirm that we got the record successfully
	gtg_data.collect! {|line| line.split(',')}
	info = gtg_data.detect {|line| line[0] == '0'}
	
	# info pieces that we need for the reply
	# should confirm that we got all these attributes
	latitude = info[1].to_f
	longitude = info[2].to_f
	altitude = info[3].to_f
	
	# assemble the basic reply
	# we should keep track of the length of the reply, so as not to exceed
	# the 140 character maximum. Usernames are [mostly] <= 15 characters.
	# We can round values to a few short places to save space, too.
	#map_link = format "http://maps.google.com/?q=%s,%s+(%s)&z=2&output=embed", latitude, longitude, CGI.escape(satellite_name)
	reply_text = format "#USER# When you mentioned %s, it was located above %.3f %s %.3f %s at an altitude of %.1f km.", satellite_name, latitude.abs, latitude >= 0 ? "N" : "S", longitude.abs, longitude >= 0 ? "E" : "W", altitude
	
	# links get converted to t.co links
	# which are a constant length: 20
	# (well, https links are 21; see https://dev.twitter.com/discussions/4458)
	#http://t.co/SYGdx0uM
	# pretty close, as-is; 132 characters with estimated maximum username, link, and coordinates.
	
	# append observer-specific attributes to the reply if georeferenced
	#if tweet[:geo] != nil
		# should confirm that we got these attributes
	#	elevation = info[4].to_f
	#	azimuth = info[5].to_f
	#	reply_text += format " (El: %.2f, Az: %.2f)", elevation, azimuth
	#end
	
	# post the reply
	reply reply_text, tweet

end

catalog_file = open "tle_catalog.txt"
catalog_lines = catalog_file.read.split("\n")
catalog_file.close
catalog = {}
catalog_lines.each do |catalog_line|
	name, path = catalog_line.split("\t")
	catalog[name] = path
end

# sat_searches.txt contains a list of catalog keys (one per line) to search for
# - these are the satellites we'll tell people about spontaneously.
search_file = open "sat_searches.txt"
search_satellites = search_file.read.split("\n")
search_file.close

search_satellites.each do |satellite|
	search(format '"%s"', satellite) do |tweet|
		
		# skip search results that mention us; we'll handle those as replies
		if tweet[:text].match(/@WheresThatSat/i)
			next
		end
		
		# example search created_at timestamp: Fri, 13 Apr 2012 13:06:22 +0000
		tp = tweet[:created_at].split(' ')
		hms = tp[4].split(':')
		timestamp = Time.gm(tp[3], tp[2], tp[1], hms[0], hms[1], hms[2], 0).to_f
		
		#puts "#{timestamp} - #{satellite}"
		TheresThatSat satellite, catalog[satellite], timestamp, tweet
	end
end

replies do |tweet|
	catalog.keys.each do |satellite|
		if tweet[:text].match(/\b#{satellite}\b/i)
			
			# example reply created_at timestamp: Fri Apr 13 13:06:22 +0000 2012
			tp = tweet[:created_at].split(' ')
			hms = tp[3].split(':')
			timestamp = Time.gm(tp[5], tp[1], tp[2], hms[0], hms[1], hms[2], 0).to_f
			
			TheresThatSat satellite, catalog[satellite], timestamp, tweet
		end
	end
end
