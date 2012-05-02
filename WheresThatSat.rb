#!/usr/bin/env ruby

$testmode = false
if (ARGV.length == 1 && ARGV[0] == 'test')
	$testmode = true
	puts "Test mode"
end

require 'rubygems'
require 'twitter'
require 'cgi'
require 'geocoder'
require 'wtsutil'

#
# Represents observer location (name and coordinates)
#
class WTSObserver
	attr_accessor :lat
	attr_accessor :lon
	attr_accessor :name
end

#
# Parameters:
#	tweet object
#
# Returns:
#	WTSObserver object representing location associated with tweet,
#	or nil if no location can be parsed from text, geo, or place
#
def parseTweetPlaceTag(tweet)
	geo = nil
	if (tweet.text.match(/\#place "([^"]+)"/i))
		geoquery = $1
		geocode = Geocoder.search(geoquery)
		if (geocode.length > 0)
			geo = WTSObserver.new
			geo.lat = geocode[0].latitude
			geo.lon = geocode[0].longitude
			geo.name = "\"#{geoquery}\""
		end
	end
## Need to adjust to suit twitter gem's geo/place format
# 	elsif (tweet[:geo] != nil)
# 		geo = WTSObserver.new
# 		geo.lat = tweet[:geo][:coordinates][0]
# 		geo.lon = tweet[:geo][:coordinates][1]
# 		user = from_user(tweet)
# 		if (user[-1,1] == 's')
# 			geo.name = "#{user}' coordinates"
# 		else
# 			geo.name = "#{user}'s coordinates"
# 		end
# 	elsif (tweet[:place] != nil)
# 		geo = WTSObserver.new
# 		bbox = tweet[:place][:bounding_box][:coordinates][0]
# 		geo.lat = (bbox[0][1] + bbox[2][1]) / 2.0
# 		geo.lon = (bbox[0][0] + bbox[2][0]) / 2.0
# 		geo.name = tweet[:place][:name]
# 	end
	return geo
end

#
# Parameters:
#	tweetText, text to search for time tag
#	tweetTimestamp, Time of source tweet (basis for relative time offsets)
#
# Returns:
#	[tweetTimestamp, false] if no time tag can be parsed
#	[tagTimestamp, true] if time tag can be parsed
#
def parseTweetTimeTag(tweetText, tweetTimestamp)
	if (tweetText.match(/\#time "([^"]+)"/i))
		description = $1
		if description.match(/([+-]?\d+(?:\.\d*)?) (second|minute|hour|day)s? (from now|ago)/i)
			count = $1
			unit = $2
			direction = $3
			offset = case unit
				when 'second': count.to_f
				when 'minute': count.to_f * 60.0
				when 'hour': count.to_f * 60.0 * 60.0
				when 'day': count.to_f * 24.0 * 60.0 * 60.0
			end
			if direction == "ago"
				offset *= -1
			end
			return tweetTimestamp + offset, true
		end
	end
	return tweetTimestamp, false
end

#
# Parameters:
#	gtg_args, string containing command line for Ground Track Generator
#		("--format csv" is assumed to be present in gtg_args)
#
# Returns:
#	array of gtg output records; each record is comprised of array of fields
#
def goGoGTG(gtg_args)
	gtg_cmd = './gtg ' + gtg_args
	gtg_pipe = IO.popen(gtg_cmd)
	gtg_data = gtg_pipe.read
	gtg_pipe.close
	return gtg_data.split("\n").collect {|record| record.split(',')}
end

#
# Parameters:
#	tleData, string containing two-line element set
#
# Returns:
#	string containing satellite number
#
def getTLEIdentifier(tleData)
	return tleData[2..6]
end

#
# Parameters:
#	tweet object
#
# Returns:
#	username of tweet author
#
def getTweetAuthor(tweet)
	return tweet.from_user || tweet.user.screen_name
end

#
# Parameters:
#	satellite_name, display name of satellite
#	tle_data, two-line element set of satellite
#	user_name, input twitter username
#	tweet_id, input tweet_id
#	mention_time - integer unix timestamp of focal time
#	response_time - integer unix timestamp of reply time.
#	explicit_mention_time - true if user specified mention time
#	is_geo, boolean whether observer location is defined (true if yes)
#
# Returns:
#	string containing tweet response text (including map link)
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
	reply_text = format "@%s When you mentioned %s, it was above %.4f%s %.4f%s. Here's more info: %s",
			user_name, satellite_name, mention_lat.abs, mention_lat >= 0 ? "N" : "S", mention_lon.abs, mention_lon >= 0 ? "E" : "W", url

end

#
# Parameters:
#	catalog object
#	twitter connection
#	tweetText, text of tweet
#	tweetId, id of tweet
#	tweetTimestamp, time of tweet
#	userName, author of tweet
#	location, WTSObserver/nil
#	selectedSatellites, array of satellite names to respond to
#		(if selectedSatellites is empty, respond to any satellite name in catalog)
#
# Returns:
#	number of responses posted to tweet. (Maybe be zero if no satellite names
#		were matched, or more than one if there were multiple matches)
#
def respondToTweet(catalog, twitter, tweetText, tweetId, tweetTimestamp, userName, location, selectedSatellites=[])
	
	if selectedSatellites.empty?
		selectedSatellites = catalog.entries
	end
	
	responseCount = 0
	
	selectedSatellites.each do |satelliteName|
		
		# match hyphenated or non-hyphenated forms of satellite_name
		satelliteNamePattern = satelliteName.gsub(/(?: |-)/, "[ -]");
		
		if tweetText.match(/\b#{satelliteNamePattern}\b/i)
			responseTimestamp = Time.now.utc
			
			# parseTweetPlaceTag is called by the caller, since it may need to
			# access other tweet properties (such as geo or place) besides text
			tweetTimestamp, hasTimeTag = parseTweetTimeTag(tweetText, tweetTimestamp)
			
			response = theresThatSat(satelliteName, catalog[satelliteName],
					userName, tweetId, tweetTimestamp.to_i, responseTimestamp.to_i,
					hasTimeTag, location)
			
			if $testmode
				puts response
			else
				twitter.update(response, :in_reply_to_status_id => tweetId)
			end
			
			responseCount += 1
		end
	end
	return responseCount
end

#
# Parameter:
#	config object
#	catalog object
#	twitter connection
#
# Results:
#	posts replies to search results
#
# Returns:
#	id of most recent search result
#
def respondToSearches(config, catalog, twitter)
	max = config.sinceId
	
	# load the list of satellite names to search for
	satellite_queries = config.searchTerms
	if satellite_queries == nil then return 0 end
	
	# assemble the list of names into a single OR query w/each name quoted
	searchQuery = satellite_queries.map {|name| "\"#{name}\""}.join(' OR ')
	
	searchResults = twitter.search(searchQuery, :since_id => config.sinceId, :result_type => "recent")
	
	searchResults.each do |tweet|
		if tweet.id > max then max = tweet.id end
		if (tweetAuthor = getTweetAuthor(tweet)) == 'WheresThatSat' then next end
		
		# skip any results that refer to us: they're handled as Mentions
		if tweet.text.match(/@WheresThatSat/i) then next end
		
		respondToTweet(catalog, twitter, tweet.text, tweet.id, tweet.created_at.utc,
				tweetAuthor, parseTweetPlaceTag(tweet), satellite_queries)
	end
	return max
end

#
# Parameter:
#	config object
#	catalog object
#	twitter connection
#
# Results:
#	posts replies to mentions
#
# Returns:
#	id of most recent mention
#
def respondToMentions(config, catalog, twitter)
	max = config.sinceId
	mentions = twitter.mentions(:since_id => config.sinceId)
	mentions.each do |tweet|
		if tweet.id > max then max = tweet.id end
		if (tweetAuthor = getTweetAuthor(tweet)) == 'WheresThatSat' then next end

		# To avoid redundant replies to retweets/quotes of our own tweets,
		# ignore mentions that aren't actually direct @replies.
		if !tweet.text.match(/^@WheresThatSat/i) then next end
		
		respondToTweet(catalog, twitter, tweet.text, tweet.id, tweet.created_at.utc,
				tweetAuthor, parseTweetPlaceTag(tweet))
	end
	return max
end

config = WTS::WTSConfig.new
catalog = WTS::WTSCatalog.new
twitter = Twitter.new(config.login)

mentionLastId = respondToMentions(config, catalog, twitter)
searchLastId = respondToSearches(config, catalog, twitter)

config.sinceId = [config.sinceId, mentionLastId, searchLastId].max
config.save
