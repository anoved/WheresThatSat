#!/usr/bin/env ruby

require 'cgi'

# This script is a test rig for the core response generator of WheresThatSat.rb.
# It does not invoke the Chatterbot module or interact with Twitter at all.
# Given a hard-coded satellite, mention time, reply time, and optionally geo,
# it runs Ground Track Generator and assembles the wheresthatsat.com/map.html
# link and associated tweet reply text (a subset of the info provided on map).



# satellite_name, the satellite name (and $catalog key)
# mention_time, integer unixtime of satellite mention
# response_time, integer unixtime of response time (probably now)

# http://t.co/5O5o2od1

def GoGoGTG(cmd)
	gtg_pipe = IO.popen(cmd)
	gtg_data = gtg_pipe.read
	gtg_pipe.close
	return gtg_data.split("\n").collect {|record| record.split(',')}
end



def TheresThatSat(satellite_name, mention_time, response_time, geo_given, geo_lat=0, geo_lon=0)
	
	tle_path = File.expand_path($catalog[satellite_name])
	wts_url = format 'http://wheresthatsat.com/map.html?sn=%s&un=%s', CGI.escape(satellite_name), CGI.escape('anoved')
	
	# trace

	wts_url += format '&t1=%d&t2=%d', mention_time, response_time
	trace_cmd = format './gtg --input "%s" --format csv --start "%d-4m" --end "%d+4m" --interval 2m', tle_path, mention_time, response_time
	trace_data = GoGoGTG(trace_cmd)
	trace_data.each {|line|
		wts_url += format '&ll=%.4f,%.4f', line[1], line[2]
	}
	
	# observer
	
	if (geo_given)
		
		# twitter mentioner username as observer name
		wts_url += format '&ol=%.4f,%.4f', geo_lat, geo_lon
		
	end
	
	# mention
	
	mention_cmd = format './gtg --input "%s" --format csv --start "%d" --steps 1 --attributes altitude velocity heading', tle_path, mention_time
	
	if (geo_given)
		mention_cmd += format ' --observer %f %f --attributes shadow elevation azimuth solarelev', geo_lat, geo_lon
	end
	
	mention_data = GoGoGTG(mention_cmd)
	m = mention_data[0]
	wts_url += format '&ml=%.4f,%.4f&ma=%f&ms=%f&mh=%f&mt=%d', m[1], m[2], m[3], m[4], m[5], mention_time
	
	if (geo_given)
		wts_url += format '&mi=%d&me=%f&mz=%f&mo=%f', m[6], m[7], m[8], m[9]
	end
	
	# response
	# mention and response code is essentially the same
	
	reply_cmd = format './gtg --input "%s" --format csv --start "%d" --steps 1 --attributes altitude velocity heading', tle_path, response_time
	
	if (geo_given)
		reply_cmd += format ' --observer %f %f --attributes shadow elevation azimuth solarelev', geo_lat, geo_lon
	end
	
	reply_data = GoGoGTG(reply_cmd)
	r = reply_data[0]
	wts_url += format '&rl=%.4f,%.4f&ra=%f&rs=%f&rh=%f&rt=%d', r[1], r[2], r[3], r[4], r[5], response_time
	
	if (geo_given)
		wts_url += format '&ri=%d&re=%f&rz=%f&ro=%f', r[6], r[7], r[8], r[9]
	end
		
	puts wts_url
		
end






# This assembles $catalog, a satellite-name to TLE-file-path index.
catalog_file = open "config/catalog.txt"
catalog_lines = catalog_file.read.split("\n")
catalog_file.close
$catalog = {}
catalog_lines.each do |catalog_line|
	name, path = catalog_line.split("\t")
	$catalog[name] = path
end


# use .to_i to get second-based times from Ruby Time objects

#http://maps.google.com/?ll=38.130236,15.375366&spn=3.745917,8.096924&t=h&z=8
TheresThatSat("ISS", 1334872442, 1334873042, true, 38.130236, 15.375366)
