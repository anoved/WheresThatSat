#!/usr/bin/env ruby

require 'rubygems'
require 'optparse'
require 'open-uri'
require 'cgi'
require 'pathname'
require 'wtsutil'

def formatAliasList(catalog)
	text = "<ul>\n"
	catalog.aliases.sort.each do |aliasName, canonicalName|
		text += "<li>#{aliasName} &rarr; #{canonicalName}</li>\n"
	end
	text += "</ul>\n"
	return text
end

def formatSatelliteList(catalog)
	text = "<table><tr>\n<td><ul>"
	perColumn = (catalog.tles.keys.length / 3.0).ceil
	count = 0
	catalog.tles.keys.sort.each do |name|
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

def getCatalogPageTemplate(templatePath='config/satellites_template.html')
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

def updateCatalog(config)

	catalog = WTS::WTSCatalog.new
	
	# names of all satellites initially present in the catalog, plus
	# lists to keep track of those that will be added or updated
	initial = catalog.entries
	additions = []
	updates = []
	
	config.tleIndexURLs.each do |url|
		
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

			if catalog.include?(tleName)
				updates.push(tleName)
			else
				additions.push(tleName)
			end
			
			catalog[tleName] = tleText
			
			line += 3
			
		end
	end
	
	# names of satellites to remove (present initially but no longer in indices)
	removed = initial - (updates + additions)
	removed.each {|oldKey| catalog.delete(oldKey)}
	
	catalog.save
	
	return catalog, additions, removed
end

def parseCommandLineOptions
	
	options = {
		:catalog => false,
		:webpage => ''};
	
	op = OptionParser.new
	
	op.on("--catalog") do |v|
		options[:catalog] = true
	end
	
	op.on("--webpage PATH", String) do |v|
		options[:webpage] = v
	end
	
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

# first we need a catalog
if options[:catalog]
	# update the catalog contents
	catalog, additions, removals = updateCatalog(config)
else
	# use the current catalog
	catalog = WTS::WTSCatalog.new
	additions = []
	removals = []
end

# now we have a catalog; update things that depend on it
if options[:webpage] != ''
	pageText = formatCatalogPage(catalog, getCatalogPageTemplate())
	File.open(options[:webpage], 'w') do |file|
		file.write(pageText)
	end
end

