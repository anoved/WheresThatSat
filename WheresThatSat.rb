#!/usr/bin/env ruby

$testmode = false
if (ARGV.length == 1 && ARGV[0] == 'test')
	$testmode = true
	puts "Test mode"
end

require 'rubygems'
require 'optparse'
require 'twitter'
require 'cgi'
require 'geocoder'
require 'wtsutil'
require 'encoded_polyline'

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
#	tweet or dm object
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
	elsif (tweet.methods.include?('geo') && tweet.geo != nil)
		geo = WTSObserver.new
		geo.lat = tweet.geo.latitude
		geo.lon = tweet.geo.longitude
		user = getTweetAuthor(tweet)
		if (user[-1,1] == 's')
			geo.name = "#{user}' coordinates"
		else
			geo.name = "#{user}'s coordinates"
		end
	elsif (tweet.methods.include?('place') && tweet.place != nil)
		geo = WTSObserver.new
		bbox = tweet.place.bounding_box.coordinates[0]
		geo.lat = (bbox[0][1] + bbox[2][1]) / 2.0
		geo.lon = (bbox[0][0] + bbox[2][0]) / 2.0
		geo.name = tweet.place.full_name
	end
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

def getDirectionOfHeading(heading)
	if (heading >= 0 && heading < 5.62): "north"
	elsif (heading >= 5.62 && heading < 16.87): "north by east"
	elsif (heading >= 16.87 && heading < 28.12): "north-northeast"
	elsif (heading >= 28.12 && heading < 39.37): "northeast by north"
	elsif (heading >= 39.37 && heading < 50.62): "northeast"
	elsif (heading >= 50.62 && heading < 61.87): "northeast by east"
	elsif (heading >= 61.87 && heading < 73.12): "east-northeast"
	elsif (heading >= 73.12 && heading < 84.37): "east by north"
	elsif (heading >= 84.37 && heading < 95.62): "east"
	elsif (heading >= 95.62 && heading < 106.87): "east by south"
	elsif (heading >= 106.87 && heading < 118.12): "east-southeast"
	elsif (heading >= 118.12 && heading < 129.37): "southeast by east"
	elsif (heading >= 129.37 && heading < 140.62): "southeast"
	elsif (heading >= 140.62 && heading < 151.87): "southeast by south"
	elsif (heading >= 151.87 && heading < 163.12): "south-southeast"
	elsif (heading >= 163.12 && heading < 174.37): "south by east"
	elsif (heading >= 174.37 && heading < 185.62): "south"
	elsif (heading >= 185.62 && heading < 196.87): "south by west"
	elsif (heading >= 196.87 && heading < 208.12): "south-southwest"
	elsif (heading >= 208.12 && heading < 219.37): "southwest by south"
	elsif (heading >= 219.37 && heading < 230.62): "southwest"
	elsif (heading >= 230.62 && heading < 241.87): "southwest by west"
	elsif (heading >= 241.87 && heading < 253.12): "west-southwest"
	elsif (heading >= 253.12 && heading < 264.37): "west by south"
	elsif (heading >= 264.37 && heading < 275.62): "west"
	elsif (heading >= 275.62 && heading < 286.87): "west by north"
	elsif (heading >= 286.87 && heading < 298.12): "west-northwest"
	elsif (heading >= 298.12 && heading < 309.37): "northwest by west"
	elsif (heading >= 309.37 && heading < 320.62): "northwest"
	elsif (heading >= 320.62 && heading < 331.87): "northwest by north"
	elsif (heading >= 331.87 && heading < 343.12): "north-northwest"
	elsif (heading >= 343.12 && heading < 354.37): "north by west"
	elsif (heading >= 354.37 && heading <= 360): "north"
	end
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
	trace_data.collect! {|point| [point[1].to_f, point[2].to_f]}
	url += format '&points=%s', CGI.escape(EncodedPolyline.encode_points(trace_data, 4))
	
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
	reply_text = format "When you mentioned %s, it was above %.4f%s %.4f%s. Here's more info: %s",
			satellite_name, mention_lat.abs, mention_lat >= 0 ? "N" : "S", mention_lon.abs, mention_lon >= 0 ? "E" : "W", url

end

#
# This method is a special case of theresThatSat intended for use by
# WheresThatSat reports - status updates that are not replies.
#
# Parameters:
#	sat, display name of satellite
#	tle, two-line element set of satellite
#	timestamp, integer unix timestamp
#
# Returns:
#	string containing tweet response text (including map link)
#
def heresThisSat(sat, tle, timestamp)
	
	# no username or tweet id (for announcements, although appropriate for --tweet...)
	url = format 'http://wheresthatsat.com/map.html?sn=%s&un=WheresThatSat&ut=0&si=%s', CGI.escape(sat), CGI.escape(getTLEIdentifier(tle))

	# trace
	startTime = timestamp - (5 * 60)
	endTime = timestamp + (5 * 60)
	url += format '&t1=%d&t2=%d', startTime, endTime
	trace_cmd = format '--tle "%s" --format csv --start "%d" --end "%d" --interval 1m', tle, startTime, endTime
	trace_data = goGoGTG(trace_cmd)
	trace_data.collect! {|point| [point[1].to_f, point[2].to_f]}
	url += format '&points=%s', CGI.escape(EncodedPolyline.encode_points(trace_data, 4))
	
	# marker
	markerCmd = format '--tle "%s" --format csv --start "%d" --steps 1 --attributes altitude velocity heading', tle, timestamp
	
	m = goGoGTG(markerCmd)[0]
	mlat = m[1].to_f
	mlon = m[2].to_f
	url += format '&ml=%.4f,%.4f&ma=%.2f&ms=%.2f&mh=%.2f&mt=%d', mlat, mlon, m[3].to_f, m[4].to_f, m[5].to_f, timestamp
	
	format "Right now, %s is moving %s at %.2f km/s, %.2f km above %.4f%s %.4f%s. Here's a map: %s", sat, getDirectionOfHeading(m[5].to_f), m[4].to_f, m[3].to_f, mlat.abs, mlat >= 0 ? "N" : "S", mlon.abs, mlon >= 0 ? "E" : "W", url
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
#	suppressReplyMarker, 
#	selectedSatellites, array of satellite names to respond to
#		(if selectedSatellites is empty, respond to any satellite name in catalog)
#	replyByDM, if true, send a dm instead of posting an status update
#
# Returns:
#	number of responses posted to tweet. (Maybe be zero if no satellite names
#		were matched, or more than one if there were multiple matches)
#
def respondToContent(catalog, twitter, tweetText, tweetId, tweetTimestamp, userName, location, suppressReplyMarker, selectedSatellites=[], replyByDM=false)
	
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
			
			if suppressReplyMarker
				hasTimeTag = true
			end
			
			response = theresThatSat(satelliteName, catalog[satelliteName],
					userName, tweetId, tweetTimestamp.to_i, responseTimestamp.to_i,
					hasTimeTag, location)
			
			if $testmode
				puts response
			else
				if replyByDM
					twitter.direct_message_create(userName, response)
				else
					twitter.update(format("@%s %s", userName, response), :in_reply_to_status_id => tweetId)
				end
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
	max = config.searchesSinceId
	
	# load the list of satellite names to search for
	satellite_queries = config.searchTerms
	if satellite_queries == nil then return config.searchesSinceId end
	
	# assemble the list of names into a single OR query w/each name quoted
	searchQuery = satellite_queries.map {|name| "\"#{name}\""}.join(' OR ')
	
	begin
		searchResults = twitter.search(searchQuery, :since_id => config.searchesSinceId, :result_type => "recent")
		searchResults.each do |tweet|
			if tweet.id > max then max = tweet.id end
			if (tweetAuthor = getTweetAuthor(tweet)) == 'WheresThatSat' then next end
			
			# skip any results that refer to us: they're handled as Mentions
			if tweet.text.match(/@WheresThatSat/i) then next end
			
			respondToContent(catalog, twitter, tweet.text, tweet.id, tweet.created_at.utc,
					tweetAuthor, parseTweetPlaceTag(tweet), false, satellite_queries)
		end
	rescue Twitter::Error => e
		puts STDERR, e
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
	max = config.mentionsSinceId
	begin
		mentions = twitter.mentions(:since_id => config.mentionsSinceId)
		mentions.each do |tweet|
			if tweet.id > max then max = tweet.id end
			if (tweetAuthor = getTweetAuthor(tweet)) == 'WheresThatSat' then next end
	
			# To avoid redundant replies to retweets/quotes of our own tweets,
			# ignore mentions that aren't actually direct @replies.
			if !tweet.text.match(/^@WheresThatSat/i) then next end
			
			respondToContent(catalog, twitter, tweet.text, tweet.id, tweet.created_at.utc,
					tweetAuthor, parseTweetPlaceTag(tweet), false)
		end
	rescue Twitter::Error => e
		puts STDERR, e
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
#	sends replies to dms
#
# Returns:
#	id of most recent dm
#
def respondToDMs(config, catalog, twitter)
	max = config.dmSinceId
	begin
		dms = twitter.direct_messages(:since_id => config.dmSinceId)
		dms.each do |dm|
			if dm.id > max then max = dm.id end
			respondToContent(catalog, twitter, dm.text, dm.id, dm.created_at.utc,
					dm.sender.screen_name, parseTweetPlaceTag(dm), false, [], true)
		end
	rescue Twitter::Error => e
		puts STDERR, e
	end
	return max
end

#
# Preferably, do not show reply-time location marker for these responses.
# (Similar to #time queries and spontaneous "solo" location announcements.)
#
# Parameters:
#	config object
#	catalog object
#	twitter connection
#	tweetId of tweet to respond to
#
def respondToTweet(config, catalog, twitter, tweetId)
	begin
		tweet = twitter.status(tweetId)
		tweetAuthor = getTweetAuthor(tweet)
		respondToContent(catalog, twitter, tweet.text, tweet.id, tweet.created_at.utc,
				tweetAuthor, parseTweetPlaceTag(tweet), true)
	rescue Twitter::Error => e
		puts STDERR, e
	end
end

#
# Parameters:
#	config object
#	catalog object
#	twitter connection
#
# Results:
#	random satellite location report is posted to Twitter
#
def postRandomReport(config, catalog, twitter)
	terms = config.announcementTerms
	return if terms.empty?
	
	# note terms must currently be defined exactly as listed in catalog;
	# making this lookup case/hyphen insensitive would be convenient
	sat = terms[rand(terms.length)]
	
	postReport(config, catalog, twitter, sat)
end

#
# Parameters:
#	config object
#	catalog object
#	twitter connection
#	name of satellite to report
#
# Results:
#	satellite location report posted to Twitter
#
def postReport(config, catalog, twitter, satelliteName)
	return if not catalog.include? satelliteName
	report = heresThisSat(satelliteName, catalog[satelliteName], Time.now.utc.to_i)
	begin
		twitter.update(report)
	rescue Twitter::Error => e
		puts STDERR, e
	end
end

#
# Returns:
#	hash of options indicating which actions WheresThatSat should perform
#
def parseCommandLineOptions
	
	# default options
	options = {
		:report => false,
		:mentions => false,
		:searches => false,
		:dm => false,
		:tweet => 0};
	
	op = OptionParser.new
	
	# configure the options
	
	op.on("--report") do |v|
		options[:report] = true
	end
	
	op.on("--mentions") do |v|
		options[:mentions] = true
	end
	
	op.on("--searches") do |v|
		options[:searches] = true
	end
	
	op.on("--dm") do |v|
		options[:dm] = true
	end
	
	op.on("--tweet ID", Integer) do |v|
		if v <= 0
			raise OptionParser::InvalidArgument, v
		end
		options[:tweet] = v
	end
	
	# parse the options; report and quit if problems are encountered
	begin
		op.parse!
	rescue OptionParser::ParseError => err
		puts STDERR, err
		exit 1
	end
	
	return options
end

options = parseCommandLineOptions
config = WTS::WTSConfig.new
catalog = WTS::WTSCatalog.new
twitter = Twitter.new(config.login)

if options[:report]
	postRandomReport(config, catalog, twitter)
end

if options[:mentions]
	config.mentionsSinceId = respondToMentions(config, catalog, twitter)
end

if options[:searches]
	config.searchesSinceId = respondToSearches(config, catalog, twitter)
end

if options[:dm]
	config.dmSinceId = respondToDMs(config, catalog, twitter)
end

if options[:tweet] != 0
	respondToTweet(config, catalog, twitter, options[:tweet])
end

# update configuration with any changes.
config.save
