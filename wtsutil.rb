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
		
end
