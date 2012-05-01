#!/usr/bin/env ruby

$testmode = false
if (ARGV.length == 1 && ARGV[0] == 'test')
	$testmode = true
	puts "Test mode"
end

require 'rubygems'
require 'chatterbot/dsl'

# Ignore our own tweets to prevent a silly cycle of self-replies
blacklist "wheresthatsat"

require 'yaml'
require 'cgi'
require 'chronic'
require 'geocoder'
require './wtsutil'

class WTSObserver
	attr_accessor :lat
	attr_accessor :lon
	attr_accessor :name
end

# returns nil if no location can be parsed
# otherwise returns a WTSObserver object
def parseTweetPlaceTag(tweet)
	geo = nil
	if (tweet[:text].match(/\#place "([^"]+)"/i))
		geoquery = $1
		geocode = Geocoder.search(geoquery)
		if (geocode.length > 0)
			geo = WTSObserver.new
			geo.lat = geocode[0].latitude
			geo.lon = geocode[0].longitude
			geo.name = "\"#{geoquery}\""
		end
	elsif (tweet[:geo] != nil)
		geo = WTSObserver.new
		geo.lat = tweet[:geo][:coordinates][0]
		geo.lon = tweet[:geo][:coordinates][1]
		user = from_user(tweet)
		if (user[-1,1] == 's')
			geo.name = "#{user}' coordinates"
		else
			geo.name = "#{user}'s coordinates"
		end
	elsif (tweet[:place] != nil)
		geo = WTSObserver.new
		bbox = tweet[:place][:bounding_box][:coordinates][0]
		geo.lat = (bbox[0][1] + bbox[2][1]) / 2.0
		geo.lon = (bbox[0][0] + bbox[2][0]) / 2.0
		geo.name = tweet[:place][:name]
	end
	return geo
end

def parseTweetTimeTag(tweetText, tweetTimestamp)
	if (tweetText.match(/\#time "([^"]+)"/i))
		# the :now parameter uses the [UTC] timestamp of the tweet as
		# the basis for any relative time offsets, such as "hours from now"
		# (only "n units ago/from now" descriptions are global-compatible)
		specifiedTimestamp = Chronic.parse($1, :now => tweetTimestamp)
		if specifiedTimestamp != nil
			return specifiedTimestamp, true
		end
	end
	return tweetTimestamp, false
end

def goGoGTG(gtg_args)
	gtg_cmd = './gtg ' + gtg_args
	gtg_pipe = IO.popen(gtg_cmd)
	gtg_data = gtg_pipe.read
	gtg_pipe.close
	return gtg_data.split("\n").collect {|record| record.split(',')}
end

def getTLEIdentifier(tleData)
	return tleData[2..6]
end

#
# satellite_name, display name of satellite
# tle_data, two-line element set of satellite
# user_name, input twitter username
# tweet_id, input tweet_id
# mention_time - integer unix timestamp of focal time
# response_time - integer unix timestamp of reply time.
# explicit_mention_time - true if user specified mention time
# is_geo, boolean whether observer location is defined (true if yes)
#
def theresThatSat(satellite_name, tle_data, user_name, tweet_id, mention_time, response_time, explicit_mention_time, geo)
	
	url = format 'http://wheresthatsat.com/map.html?sn=%s&un=%s&ut=%d&si=%s', CGI.escape(satellite_name), CGI.escape(user_name), tweet_id, CGI.escape(getTLEIdentifier(tle_data))
	
	# trace
	trace_start_time = mention_time - (4 * 60)
	trace_end_time = (explicit_mention_time ? mention_time : response_time) + (4 * 60)
	url += format '&t1=%d&t2=%d', trace_start_time, trace_end_time
	trace_cmd = format '--tle "%s" --format csv --start "%d" --end "%d" --interval 1m', tle_data, trace_start_time, trace_end_time
	trace_data = goGoGTG(trace_cmd)
	trace_data.each do |point|
		url += format '&ll=%.4f,%.4f', point[1], point[2]
	end
	
	# observer
	if geo != nil then url += format '&ol=%.4f,%.4f&on=%s', geo.lat, geo.lon, CGI.escape(geo.name) end
	
	# mention
	mention_cmd = format '--tle "%s" --format csv --start "%d" --steps 1 --attributes altitude velocity heading', tle_data, mention_time
	if geo != nil then mention_cmd += format ' --observer %f %f --attributes shadow elevation azimuth solarelev', geo.lat, geo.lon end
	m = goGoGTG(mention_cmd)[0]
	mention_lat = m[1].to_f
	mention_lon = m[2].to_f
	url += format '&ml=%.4f,%.4f&ma=%.2f&ms=%.2f&mh=%.2f&mt=%d', m[1], m[2], m[3], m[4], m[5], mention_time
	if geo != nil then url += format'&mi=%d&me=%.2f&mz=%.2f&mo=%.2f', m[6], m[7], m[8], m[9] end
	
	# response (none if response_time < 0)
	if not explicit_mention_time
		reply_cmd = format '--tle "%s" --format csv --start "%d" --steps 1 --attributes altitude velocity heading', tle_data, response_time
		if geo != nil then reply_cmd += format ' --observer %f %f --attributes shadow elevation azimuth solarelev', geo.lat, geo.lon end
		r = goGoGTG(reply_cmd)[0]
		url += format '&rl=%.4f,%.4f&ra=%.2f&rs=%.2f&rh=%.2f&rt=%d', r[1], r[2], r[3], r[4], r[5], response_time
		if geo != nil then url += format '&ri=%d&re=%.2f&rz=%.2f&ro=%.2f', r[6], r[7], r[8], r[9] end
	end

	# return complete reply text
	reply_text = format "#USER# When you mentioned %s, it was above %.4f%s %.4f%s. Here's more info: %s",
			satellite_name, mention_lat.abs, mention_lat >= 0 ? "N" : "S", mention_lon.abs, mention_lon >= 0 ? "E" : "W", url

end

# returns Time object
# example search created_at timestamp: Fri, 13 Apr 2012 13:06:22 +0000
def parseSearchTimestamp(created_at)
	parts = created_at.split(' ')
	hms = parts[4].split(':')
	return Time.utc(parts[3], parts[2], parts[1], hms[0], hms[1], hms[2], 0)
end

# returns Time object
# example reply created_at timestamp: Fri Apr 13 13:06:22 +0000 2012
def parseReplyTimestamp(created_at)
	parts = created_at.split(' ')
	hms = parts[3].split(':')
	return Time.utc(parts[5], parts[1], parts[2], hms[0], hms[1], hms[2], 0)
end

def getTweetResponse(tweetText, tweetId, tweetTimestamp, userName, location, selectedSatellites=[])
	
	if selectedSatellites.empty?
		selectedSatellites = $catalog[:tle].keys
	end
	
	selectedSatellites.each do |satelliteName|
		
		# match hyphenated or non-hyphenated forms of satellite_name
		satelliteNamePattern = satelliteName.gsub(/(?: |-)/, "[ -]");
		
		if tweetText.match(/\b#{satelliteNamePattern}\b/i)
			responseTimestamp = Time.now.utc
			
			# parseTweetPlaceTag is called by the caller, since it may need to
			# access other tweet properties (such as geo or place) besides text
			tweetTimestamp, hasTimeTag = parseTweetTimeTag(tweetText, tweetTimestamp)
			
			return theresThatSat(satelliteName, $catalog[:tle][satelliteName],
					userName, tweetId, tweetTimestamp.to_i, responseTimestamp.to_i,
					hasTimeTag, location)
		end
	end
	return nil
end


# parameter acc_available: number of API calls available
# search_quota is a cutoff for how many search-related api calls to perform,
#  regardless of how many calls are available. will not perform more than min
#  of search_quota and acc_available.
# returns number of API calls consumed (acc)
def respondToSearches(acc_available, search_quota=20)

	if (acc_available < search_quota) then search_quota = acc_available end
		
	# load the list of satellite names to search for
	satellite_queries = YAML.load_file('config/sat_searches.yml')
	if satellite_queries == nil then return 0 end
	
	# assemble the list of names into a single OR query w/each name quoted
	query_text = satellite_queries.map {|name| "\"#{name}\""}.join(' OR ')
	
	acc = 1
	search(query_text) do |tweet|
		
		# skip any results that refer to us: they're handled as Mentions
		if tweet[:text].match(/@WheresThatSat/i) then next end
		
		response = getTweetResponse(
				tweet[:text], tweet[:id],	
				parseSearchTimestamp(tweet[:created_at]),
				from_user(tweet), parseTweetPlaceTag(tweet),
				satellite_queries)
		
		# a nil response indicates no satellite was mentioned
		# (more accurately - Twitter returned a match for our query, but we
		# couldn't find any matches, indicating some matching discrepancy)
		if response == nil then next end
				
		if $testmode
			puts response
		else
			if (acc + 1 >= search_quota)
				puts STDERR, format("Not responding to search %s: rate limit/quota.", tweet[:id].to_s)
				return acc
			end
			acc += 1
			reply response, tweet
		end
		
	end
	
	return acc
end

# parameter acc_available: number of API calls available
# returns number of API calls consumed (acc)
def respondToMentions(acc_available)
	if (acc_available == 0)
		puts STDERR, "Not responding to mentions: rate limit"
		return 0
	end
	acc = 1
	replies do |tweet|
		
		# To avoid redundant replies to retweets/quotes of our own tweets,
		# ignore mentions that aren't actually direct @replies.
		if !tweet[:text].match(/^@WheresThatSat/i) then next end
		
		response = getTweetResponse(
				tweet[:text], tweet[:id],
				parseReplyTimestamp(tweet[:created_at]),
				from_user(tweet), parseTweetPlaceTag(tweet))
		
		# a nil response indicates no satellite was mentioned
		if response == nil then next end
						
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
	return acc
end

# returns current API call count (cumulative for the past hour, or whatever
# period is represented by the set of per-interval call counts in :intervals)
def readAPICallCount()
	acc_intervals = YAML.load_file("config/intervals.yml")[:intervals]
	return acc_intervals.inject(0) {|sum, value| sum + value}
end

# writes current API call count; updates :intervals with current interval's acc
# and drops any old interval counts. returns final call count.
def writeAPICallCount(acc)
	
	intervals = YAML.load_file("config/intervals.yml")[:intervals]
	
	# drop all but the most recent five intervals from the list of intervals
	# (assuming a tracking period of six intervals - 6 x 10 minutes = 1 hour)
	while intervals.length > 5 do intervals.shift end
	
	# add the most recent count to the interval list
	intervals.push acc
	
	File.open("config/intervals.yml", "w") {|file| YAML.dump({:intervals => intervals}, file)}
	
	return intervals.inject(0) {|sum, value| sum + value}
end


def loadSatelliteCatalog(catalog_path='config/catalog.yml')
	$catalog = WTS.load_catalog(catalog_path)
	# the alias table maps alternate names to satellite names as they appear in catalog
	# resolve these aliases by creating new catalog entries with the alias name and source content
	$catalog[:alias].each do |aliasName, catalogName|
		if $catalog[:tle].include?(catalogName)
			$catalog[:tle][aliasName] = $catalog[:tle][catalogName]
		end
	end
end

loadSatelliteCatalog()

ac_initial = readAPICallCount()
ac_available = 150 - ac_initial
ac_consumed = 0

acc = respondToMentions(ac_available)
ac_consumed += acc
ac_available -= acc

acc = respondToSearches(ac_available)
ac_consumed += acc
ac_available -= acc

writeAPICallCount(ac_consumed)
