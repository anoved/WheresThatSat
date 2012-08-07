#!/usr/bin/env ruby

require 'rubygems'
require 'optparse'
require 'open-uri'
require 'cgi'
require 'pathname'
require 'logger'
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

def updateCatalog(config)

	catalog = WTS::WTSCatalog.new
		
	config.tleIndexURLs.each do |url|
		
		# read the TLE index
		$log.info("Retrieving #{url}")
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
			
			$log.debug(" #{tleName}")
			catalog[tleName] = tleText
			
			line += 3
			
		end
	end
	
	catalog.save
	
	return catalog
end

def parseCommandLineOptions
	
	options = {
		:catalog => false,
		:webpage => '',
		:verbose => false};
	
	op = OptionParser.new
	
	op.on("--catalog") do |v|
		options[:catalog] = true
	end
	
	op.on("--webpage PATH", String) do |v|
		options[:webpage] = v
	end
	
	op.on("--verbose") do |v|
		options[:verbose] = true
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
$log = Logger.new(STDOUT)

if options[:verbose]
	$log.level = Logger::DEBUG
else
	$log.level = Logger::WARN
end

if options[:catalog]
	$log.info("Updating catalog")
	catalog = updateCatalog(config)
else
	$log.info("Using existing catalog")
	catalog = WTS::WTSCatalog.new
end

if options[:webpage] != ''
	$log.info("Updating #{options[:webpage]}")
	pageText = formatCatalogPage(catalog, getCatalogPageTemplate())
	File.open(options[:webpage], 'w') do |file|
		file.write(pageText)
	end
end

