#!/usr/bin/env ruby

require 'rubygems'
require 'chatterbot/dsl'

# for url encoding
require 'cgi'

#debug_mode
verbose

# Ignore our own tweets to prevent a silly cycle of self-replies
blacklist "wheresthatsat"

# here we build an index of terms to look for, based on satellite names in our
# library of supported satellites. Currently hard-coded; should be assembled
# from what we find available to us provided by the TLE updater script.
# paths are relative to the directory containing this bot script
catalog = {
	"LANDSAT 5" => "tle/landsat5.tle",
	"LANDSAT 7" => "tle/landsat7.tle"
}

catalog.keys.each do |satellite|
	search(format '"%s"', satellite) do |tweet|

		#timestamp = Time.now.getgm.strftime("%Y-%m-%d %H:%M:%S.000000 UTC")		
		
		ct = tweet[:created_at].split(' ')
		hms = ct[4].split(':')
		created_at_time = Time.gm(ct[3], ct[2], ct[1], hms[0], hms[1], hms[2], 0)
		#timestamp = created_at_time.strftime("%Y-%m-%d %H:%M:%S.000000 UTC")
		timestamp = created_at_time.to_f
		
		# basic command
		tle_dir = File.expand_path(catalog[satellite])
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
		map_link = format "http://maps.google.com/?q=%s,%s+(%s)&z=2&output=embed", latitude, longitude, CGI.escape(satellite)
		reply_text = format "#USER# When you mentioned %s, it was located above %.3f %s %.3f %s at an altitude of %.1f km. %s", satellite, latitude.abs, latitude >= 0 ? "N" : "S", longitude.abs, longitude >= 0 ? "E" : "W", altitude, map_link
		
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
end

# this logs the time of this run so we'll only see new tweets next time
# this does occur automatically at_exit - but is needed explicitly if
# we plan to run a loop ourself.
#update_config
