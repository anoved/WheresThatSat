require 'yaml'

module WTS
		
	def WTS.load_catalog(path='config/catalog.yml')
		
		if File.exists?(path)
			catalog = YAML.load_file(path)
		else
			catalog = {}
		end
		
		if not catalog.include? :alias
			catalog[:alias] = {}
		end
		
		if not catalog.include? :tle
			catalog[:tle] = {}
		end
		
		return catalog
		
	end
	
	def WTS.write_catalog(catalog, path='config/catalog.yml')
		
		File.open(path, 'w') do |file|
			YAML.dump(catalog, file)
		end
		
	end
	
	class WTSCatalog
		
		include Enumerable
		
		def initialize(catalogPath='config/catalog.yml')
			@catalog = WTS.load_catalog(catalogPath)
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
	
end
