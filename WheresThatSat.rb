#!/usr/bin/env ruby

$testmode = true
if (ARGV.length == 1 && ARGV[0] == 'furreal')
	$testmode = false
else
	puts "Test mode"
end

require 'chatterbot/dsl'
	
#debug_mode
#verbose

# Ignore our own tweets to prevent a silly cycle of self-replies
blacklist "wheresthatsat"

require 'yaml'

# for url encoding
require 'cgi'

def GoGoGTG(gtg_args)
	gtg_cmd = './gtg ' + gtg_args
	gtg_pipe = IO.popen(gtg_cmd)
	gtg_data = gtg_pipe.read
	gtg_pipe.close
	return gtg_data.split("\n").collect {|record| record.split(',')}
end

#
# satellite_name, display name of satellite
# tle_path, path to satellite TLE file
# user_name, input twitter username
# tweet_id, input tweet_id
# mention_time - integer unix timestamp of focal time
# response_time - integer unix timestamp of reply time. Suppress reply time marker if < 0.
# is_geo, boolean whether observer location is defined (true if yes)
#
def TheresThatSat(satellite_name, tle_path, user_name, tweet_id, mention_time, response_time, is_geo, geo_lat, geo_lon)
	
	url = format 'http://wheresthatsat.com/map.html?sn=%s&un=%s&ut=%d', CGI.escape(satellite_name), CGI.escape(user_name), tweet_id
	
	# trace
	trace_start_time = mention_time - (4 * 60)
	trace_end_time = (response_time < 0 ? mention_time : response_time) + (4 * 60)
	url += format '&t1=%d&t2=%d', trace_start_time, trace_end_time
	trace_cmd = format '--input "%s" --format csv --start "%d" --end "%d" --interval 1m', tle_path, trace_start_time, trace_end_time
	trace_data = GoGoGTG(trace_cmd)
	trace_data.each do |point|
		url += format '&ll=%.4f,%.4f', point[1], point[2]
	end
	
	# observer
	if is_geo then url += format '&ol=%.4f,%.4f', geo_lat, geo_lon end
	
	# mention
	mention_cmd = format '--input "%s" --format csv --start "%d" --steps 1 --attributes altitude velocity heading', tle_path, mention_time
	if is_geo then mention_cmd += format ' --observer %f %f --attributes shadow elevation azimuth solarelev', geo_lat, geo_lon end
	m = GoGoGTG(mention_cmd)[0]
	mention_lat = m[1].to_f
	mention_lon = m[2].to_f
	url += format '&ml=%.4f,%.4f&ma=%.2f&ms=%.2f&mh=%.2f&mt=%d', m[1], m[2], m[3], m[4], m[5], mention_time
	if is_geo then url += format'&mi=%d&me=%.2f&mz=%.2f&mo=%.2f', m[6], m[7], m[8], m[9] end
	
	# response (none if response_time < 0)
	if (response_time >= 0)
		reply_cmd = format '--input "%s" --format csv --start "%d" --steps 1 --attributes altitude velocity heading', tle_path, response_time
		if is_geo then reply_cmd += format ' --observer %f %f --attributes shadow elevation azimuth solarelev', geo_lat, geo_lon end
		r = GoGoGTG(reply_cmd)[0]
		url += format '&rl=%.4f,%.4f&ra=%.2f&rs=%.2f&rh=%.2f&rt=%d', r[1], r[2], r[3], r[4], r[5], response_time
		if is_geo then url += format '&ri=%d&re=%.2f&rz=%.2f&ro=%.2f', r[6], r[7], r[8], r[9] end
	end

	# return complete reply text
	reply_text = format "#USER# When you mentioned %s, it was above %.4f%s %.4f%s. Here's more info: %s",
			satellite_name, mention_lat.abs, mention_lat >= 0 ? "N" : "S", mention_lon.abs, mention_lon >= 0 ? "E" : "W", url

end

# sets $catalog global variable to hash of satellite names -> TLE file paths
def LoadSatelliteCatalog(catalog_path='config/catalog.yml')
	$catalog = YAML.load_file(catalog_path)
end

# returns integer number of seconds since UNIX epoch
# example search created_at timestamp: Fri, 13 Apr 2012 13:06:22 +0000
def ParseSearchTimestamp(created_at)
	parts = created_at.split(' ')
	hms = parts[4].split(':')
	return Time.utc(parts[3], parts[2], parts[1], hms[0], hms[1], hms[2], 0).to_i
end

# returns integer number of seconds since UNIX epoch
# example reply created_at timestamp: Fri Apr 13 13:06:22 +0000 2012
def ParseReplyTimestamp(created_at)
	parts = created_at.split(' ')
	hms = parts[3].split(':')
	return Time.utc(parts[5], parts[1], parts[2], hms[0], hms[1], hms[2], 0).to_i
end

# parameter acc_available: number of API calls available
# search_quota is a cutoff for how many search-related api calls to perform,
#  regardless of how many calls are available. will not perform more than min
#  of search_quota and acc_available.
# returns number of API calls consumed (acc)
def RespondToSearches(acc_available, search_quota=20)

	if (acc_available < search_quota) then search_quota = acc_available end
	
	acc = 0
	
	# load the list of satellite names to search for
	satellite_queries = YAML.load_file('config/sat_searches.yml')
	
	satellite_queries.each do |satellite_name|
		
		if (acc + 1 >= search_quota)
			puts STDERR, format("Stopping search at %s: rate limit/quota", satellite_name)
			return acc
		end
		acc += 1
		
		search(format('"%s"', satellite_name)) do |tweet|
			
			# skip any results that refer to us: they're handled as Mentions
			if tweet[:text].match(/@WheresThatSat/i) then next end
			
			# time
			input_timestamp = ParseSearchTimestamp(tweet[:created_at])
			output_timestamp = Time.now.utc.to_i
			
			# location
			input_geo = false
			input_lat = 0
			input_lon = 0
			if (tweet[:geo] != nil)
				input_geo = true
				input_lat = tweet[:geo][:coordinates][0]
				input_lon = tweet[:geo][:coordinates][1]
			elsif (tweet[:place] != nil)
				input_geo = true
				bbox = tweet[:place][:bounding_box][:coordinates][0]
				input_lat = (bbox[0][1] + bbox[2][1]) / 2.0
				input_lon = (bbox[0][0] + bbox[2][0]) / 2.0
			end
			
			# (No explicit time/location tags expected in non-mention search results)
						
			response = TheresThatSat satellite_name, $catalog[satellite_name],
					from_user(tweet), tweet[:id], input_timestamp, output_timestamp,
					input_geo, input_lat, input_lon
			
			if $testmode
				puts response
			else
				if (acc + 1 >= search_quota)
					puts STDERR, format("Not responding to search %s: rate limit/quota.", tweet[:id].to_s)
					return acc
				end
				acc += 1
				reply response tweet
			end
			
		end
	end
	
	return acc
end

# parameter acc_available: number of API calls available
# returns number of API calls consumed (acc)
def RespondToMentions(acc_available)
	if (acc_available == 0)
		puts STDERR, "Not responding to mentions: rate limit"
		return 0
	end
	acc = 1	
	replies do |tweet|		
		$catalog.keys.each do |satellite_name|
			if tweet[:text].match(/\b#{satellite_name}\b/i)
				
				# By default, plot ground track from mention time to our reply time.
				input_timestamp = ParseReplyTimestamp(tweet[:created_at])
				output_timestamp = Time.now.utc.to_i
				
				# Don't respond to this tweet if it's too old (overriding even
				# our bot interval - we don't want to render any huge ranges
				# on the map, or try passing them through the URL parameters)
				#if (output_timestamp - input_timestamp > (15 * 60))
				#	next
				#end
				
				if (tweet[:text].match(/\#time(\d+)/i))
					# If the user specifies a specific time (which may be long past,
					# or in the future), plot ground track around that time, and do
					# not output a separate track point representing our reply time.
					input_timestamp = $1.to_i
					output_timestamp = -1
					if $testmode then puts format "Explicit timestamp: %d", input_timestamp end
				end
				
				# By default, no location associated with input.
				input_geo = false
				input_lat = 0
				input_lon = 0
				if (tweet[:text].match(/\#latlon([+-]?\d+\.?\d*),([+-]?\d+\.?\d*)/i))
					# A location was explicitly specified in the tweet.
					# (Support more flexible and intuitive location specifications
					# - including geocoding of city names, for example.)
					input_geo = true
					input_lat = $1.to_f
					input_lon = $2.to_f
					if $testmode then puts format "Explicit geo: %f, %f", input_lat, input_lon end
				elsif (tweet[:geo] != nil)
					# A point location is given
					input_geo = true
					input_lat = tweet[:geo][:coordinates][0]
					input_lon = tweet[:geo][:coordinates][1]
					if $testmode then puts format "Implicit point geo: %f, %f", input_lat, input_lon end
				elsif (tweet[:place] != nil)
					# A place location is given
					input_geo = true
					bbox = tweet[:place][:bounding_box][:coordinates][0]
					# bit naive here -- untested on dateline, etc.
					input_lat = (bbox[0][1] + bbox[2][1]) / 2.0
					input_lon = (bbox[0][0] + bbox[2][0]) / 2.0
					if $testmode then puts format "Implicit place geo: %f, %f", input_lat, input_lon end
				end
	
				response = TheresThatSat satellite_name, $catalog[satellite_name],
						from_user(tweet), tweet[:id], input_timestamp, output_timestamp,
						input_geo, input_lat, input_lon
				
				if ($testmode)
					# In test mode, just print the response for inspection.
					puts response
				else
					# Otherwise, post the response in reply to the input Tweet.
					if (acc + 1 >= acc_available)
						puts STDERR, format("Not responding to mention %s or earlier: rate limit.", tweet[:id].to_s)
						return acc
					end
					acc += 1
					reply response, tweet
				end
			end
		end
	end
	
	return acc
end

# returns current API call count (cumulative for the past hour, or whatever
# period is represented by the set of per-interval call counts in :intervals)
def ReadAPICallCount()
	acc_intervals = YAML.load_file("config/intervals.yml")[:intervals]
	return acc_intervals.inject(0) {|sum, value| sum + value}
end

# writes current API call count; updates :intervals with current interval's acc
# and drops any old interval counts. returns final call count.
def WriteAPICallCount(acc)
	
	intervals = YAML.load_file("config/intervals.yml")[:intervals]
	
	# drop all but the most recent five intervals from the list of intervals
	# (assuming a tracking period of six intervals - 6 x 10 minutes = 1 hour)
	while intervals.length > 5 do intervals.shift end
	
	# add the most recent count to the interval list
	intervals.push acc
	
	File.open("config/intervals.yml", "w") {|file| YAML.dump({:intervals => intervals}, file)}
	
	return intervals.inject(0) {|sum, value| sum + value}
end


LoadSatelliteCatalog()

ac_initial = ReadAPICallCount()
ac_available = 150 - ac_initial
ac_consumed = 0

acc = RespondToMentions(ac_available)
ac_consumed += acc
ac_available -= acc

acc = RespondToSearches(ac_available)
ac_consumed += acc
ac_available -= acc

WriteAPICallCount(ac_consumed)
