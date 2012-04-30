#!/usr/bin/env ruby

require 'yaml'
require 'open-uri'
require './wtsutil.rb'
require 'cgi'
require 'pathname'

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
		searchLink = format "http://nssdc.gsfc.nasa.gov/nmc/spacecraftSearch.do?spacecraft=%s", CGI.escape(name)
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

def getCatalogPageTemplate(templatePath='default-config/satellites_template.html')
	templateFile = open templatePath
	text = templateFile.read
	templateFile.close
	return text
end

def formatCatalogPage(catalog, template)
	text = template.gsub("<!--ALIAS NAMES-->", formatAliasList(catalog))
	text.gsub!("<!--CANONICAL NAMES-->", formatSatelliteList(catalog))
	return text
end

def formatPhraseList(list)
	if list.empty?
		return ""
	end
	if list.length == 1
		format "%s", list[0]
	elsif list.length == 2
		format "%s and %s", list[0], list[1]
	else
		format "%s, and %s", list[0..-2].join(', '), list[-1]
	end
end

# could be used for local logging as well as Twitter update announcements.
def getCatalogUpdateSummary(additions, removals)
	text = "Satellite catalog updated."
	if not additions.empty?
		text += format " Added %s.", formatPhraseList(additions)
	end
	if not removals.empty?
		text += format " Removed %s.", formatPhraseList(removals)
	end
	# rough tweet length limit
	#if text.length > 160
	#	text = text[0..158] + "…"
	#end
	return text
end

def updateCatalog()
	
	urls = YAML.load_file('config/tle_sources.yml');
	
	catalog = WTS.load_catalog
	
	# names of all satellites initially present in the catalog, plus
	# lists to keep track of those that will be added or updated
	initial = catalog[:tle].keys
	additions = []
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
	
	return catalog, additions, removed
end

catalog, additions, removals = updateCatalog

if ARGV.length > 0
	catalogPagePath = Pathname.new(ARGV[0])
	catalogPageDirectory = catalogPagePath.parent.to_s
	catalogPageFilename = catalogPagePath.basename.to_s
	
	catalogPageText = formatCatalogPage(catalog, getCatalogPageTemplate())
	File.open(catalogPagePath, 'w') do |file|
		file.write(catalogPageText)
	end
	updateSummary = getCatalogUpdateSummary(additions, removals)
	`cd "#{catalogPageDirectory}"; git commit -m "#{updateSummary}" "#{catalogPageFilename}"`
end
