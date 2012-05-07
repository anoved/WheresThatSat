require 'yaml'

module WTS
		
	class WTSCatalog
		
		include Enumerable
		
		def initialize(catalogPath='config/catalog.yml')
			@catalogPath = catalogPath
			
			if File.exists?(catalogPath)
				@catalog = YAML.load_file(catalogPath)
			else
				@catalog = {}
			end
			
			if not @catalog.include? :alias
				@catalog[:alias] = {}
			end
			
			if not @catalog.include? :tle
				@catalog[:tle] = {}
			end
		
		end
		
		# .aliases and .tles used only for generating satellite list web page,
		# which could arguably be a method of this class, like .export...
		
		def aliases
			@catalog[:alias]
		end
		
		def tles
			@catalog[:tle]
		end
		
		def save
			self.export(@catalogPath)
		end
		
		def export(exportPath)
			File.open(exportPath, 'w') do |file|
				YAML.dump(@catalog, file)
			end
		end
		
		#
		# Parameters:
		#	key, which may be an alias name or a canonical name
		#
		# Returns:
		#	TLE data corresponding to key, or nil if none
		#
		def [](key)
			if @catalog[:alias].has_key?(key)
				@catalog[:tle][@catalog[:alias][key]]
			else
				@catalog[:tle][key]
			end
		end
		
		#
		# Parameters:
		#	key, which may be an alias name or a canonical name
		#		(if the key does not exist, it is used as a new canonical name)
		#	value, to be assigned to key
		#
		# Result:
		#	updates or creates catalog key with value
		#
		# Returns:
		#	assigned value
		#
		def []=(key, value)
			if @catalog[:alias].has_key?(key)
				# if the key exists as an alias, the value is assigned to
				# the associated canonical name
				@catalog[:tle][@catalog[:alias][key]] = value
			else
				# if the key exists only as a canonical name, or if it does
				# not exist at all, the value is assigned to that canonical key
				@catalog[:tle][key] = value
			end
		end
		
		#
		# Parameters:
		#	key, which is interpreted as a canonical name
		#		(no facility is provided to programmatically delete aliases)
		#
		# Results:
		#	deletes key-value pair from TLE hash, if present
		#
		# Returns:
		#	value of deleted key, or nil if none
		#
		def delete(key)
			if @catalog[:tle].has_key? key
				@catalog[:tle].delete(key)
			end
		end
		
		#
		# Results:
		#	yields each catalog key (alias and canonical)
		#	
		def each
			@catalog[:alias].keys.each do |aliasKey|
				yield aliasKey
			end
			@catalog[:tle].keys.each do |canonicalKey|
				yield canonicalKey
			end
		end
		
	end
	
	class WTSConfig
		
		def initialize(configPath='config/wts.yml')
			@configPath = configPath
			@config = YAML.load_file(configPath)
		end
				
		def save
			self.export(@configPath)
		end
		
		def export(exportPath)
			File.open(exportPath, 'w') do |file|
				YAML.dump(@config, file)
			end
		end
		
		def searchTerms
			@config[:searchTerms]
		end
		
		def tleIndexURLs
			@config[:tleIndexURLs]
		end
		
		def login
			@config[:authentication]
		end
		
		def searchesSinceId
			@config[:searchesSinceId]
		end
		
		def searchesSinceId=(id)
			@config[:searchesSinceId] = id
		end
		
		def mentionsSinceId
			@config[:mentionsSinceId]
		end
		
		def mentionsSinceId=(id)
			@config[:mentionsSinceId] = id
		end
		
		def dmSinceId
			@config[:dmSinceId]
		end
		
		def dmSinceId=(id)
			@config[:dmSinceId] = id
		end
		
		def announcementTerms
			@config[:announcementTerms]
		end
		
	end
	
end
