namespace :import do
  desc "Import all content from a WordPress WXR export: rake import:wordpress[path/to/export.xml]"
  task :wordpress, [ :path ] => :environment do |_t, args|
    importer = build_importer(args)
    results = importer.import_all
    results.each { |type, r| puts "#{type.to_s.ljust(10)} #{r}" }
    print_errors(results.values)
  end

  namespace :wordpress do
    %i[tributes gallery events recipes].each do |type|
      desc "Import only #{type} from a WordPress WXR export: rake import:wordpress:#{type}[path]"
      task type, [ :path ] => :environment do |_t, args|
        result = build_importer(args).public_send("import_#{type}")
        puts "#{type}: #{result}"
        print_errors([ result ])
      end
    end
  end
end

def build_importer(args)
  path = args[:path] or abort "Usage: rake import:wordpress[path/to/export.xml]"
  abort "File not found: #{path}" unless File.exist?(path)
  WordpressImporter.new(path, logger: Rails.logger)
end

def print_errors(results)
  errors = results.flat_map(&:errors)
  return if errors.empty?
  puts "\n#{errors.size} error(s):"
  errors.first(50).each { |e| puts "  - #{e}" }
end
