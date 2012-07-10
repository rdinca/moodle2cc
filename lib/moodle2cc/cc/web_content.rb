module Moodle2CC::CC
  class WebContent
    include CCHelper
    include Resource

    attr_accessor :body

    def initialize(mod)
      super
      @body = convert_file_path_tokens(mod.alltext)
    end

    def create_resource_node(resources_node)
      href = File.join(WIKI_FOLDER, "#{file_slug(@title)}.html")
      resources_node.resource(
        :type => WEBCONTENT,
        :identifier => identifier,
        :href => href
      ) do |resource_node|
        resource_node.file(:href => href)
      end
    end

    def create_files(export_dir)
      create_html(export_dir)
    end

    def create_html(export_dir)
      template = File.expand_path('../templates/wiki_content.html.erb', __FILE__)
      path = File.join(export_dir, 'wiki_content', "#{file_slug(title)}.html")
      FileUtils.mkdir_p(File.dirname(path))
      File.open(path, 'w') do |file|
        erb = ERB.new(File.read(template))
        file.write(erb.result(binding))
      end
    end

    def create_module_meta_item_elements(item_node)
      item_node.content_type 'WikiPage'
      item_node.identifierref @identifier
    end
  end
end
