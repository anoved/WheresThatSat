#!/usr/bin/env ruby

require 'yaml'
require 'open-uri'
require './wtsutil.rb'
require 'cgi'

def formatAliasList(catalog)
	text = "<ul>\n"
	catalog[:alias].sort.each do |aliasName, canonicalName|
		text += "<li>#{aliasName} &rarr; #{canonicalName}</li>\n"
	end
	text += "</ul>\n"
	return text
end

def formatSatelliteList(catalog)
	text = "<table><tr>\n<td><ul>"
	perColumn = (catalog[:tle].keys.length / 3.0).ceil
	count = 0
	catalog[:tle].keys.sort.each do |name|
		searchLink = "http://nssdc.gsfc.nasa.gov/nmc/spacecraftSearch.do?spacecraft=%s" % CGI.escape(name)
		text += "<li><a href=\"#{searchLink}\">#{name}</a></li>\n"
		count += 1
		if count > perColumn
			text += "</ul></td>\n<td><ul>\n"
			count = 0
		end
	end
	text += "</ul></td>\n</tr></table>\n"
	return text
end

def updateCatalogPage(catalog, templatePath)
	templateFile = open templatePath
	text = templateFile.read
	templateFile.close
	text.gsub!(/<!--ALIAS NAMES-->/, formatAliasList(catalog))
	text.gsub!(/<!--CANONICAL NAMES-->/, formatSatelliteList(catalog))
	return text
end

urls = YAML.load_file('config/tle_sources.yml');

# load the current catalog
catalog = WTS.load_catalog

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

WTS.write_catalog(catalog)
