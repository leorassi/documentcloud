module DC
  module Embed
    class Document < Base
      class Config < Base::Config
        define_attributes do
          string  :container
          number  :page
          number  :note
          number  :maxheight,         output_as: :height
          number  :maxwidth,          output_as: :width
          number  :zoom
          boolean :notes,             output_as: :showAnnotations
          boolean :search
          boolean :sidebar
          boolean :text
          boolean :pdf
          boolean :responsive
          number  :responsive_offset, output_as: :responsiveOffset
        end
      end

      def self.config_keys
        Config.keys
      end

      def initialize(resource, embed_config={}, options={})
        # resource should be a wrapper object around a model
        # which plucks out relevant metadata
        # Consider ActiveModel::Serializers for this purpose.
        # N.B. we should be able to generate oembed codes for things that are
        # basically mocks of a document, not just for real documents
        [:id, :resource_url].each do |attribute|
          raise ArgumentError, "Embed resource must `respond_to?` an ':#{attribute}' attribute" unless resource.respond_to?(attribute)
        end
        @resource      = resource
        @strategy      = options[:strategy]      || :literal # or :oembed
        @dom_mechanism = options[:dom_mechanism] || :iframe  # or :direct
        config_options = (@dom_mechanism == :iframe ? {map_keys: false} : {map_keys: true}).merge(options)
        @embed_config  = Config.new(data: embed_config, options: config_options)

        @template_path = options[:template_path] || "#{Rails.root}/app/views/documents/_#{@dom_mechanism}_embed_code.html.erb"
        @template      = options[:template]

        @document   = ::Document.find @resource.id
      end

      def accessible?
        @document.public?
      end

      def template
        unless @template
          @template = ERB.new(File.read(@template_path))
          @template.location = @template_path
        end
        @template
      end

      def render(data, options)
        template.result(binding)
      end

      def code
        if @dom_mechanism == :direct
          [bootstrap_markup, content_markup].join("\n").squish
        else
          content_markup.squish
        end
      end

      def content_markup
        template_options = {
          resource_url: @resource.resource_url,
          document:     @document
        }

        if @dom_mechanism == :direct
          template_options[:default_container_id] = "DV-viewer-#{@resource.id}"
          template_options[:generate_default_container] = !@embed_config[:container].present? || @embed_config[:container] == '#' + template_options[:default_container_id]
          @embed_config[:container] ||= '#' + template_options[:default_container_id]
        end

        render(@embed_config.dump, template_options)
      end

      def bootstrap_markup
        # TODO: Investigate if we actually need to make this distinction [JR]
        @strategy == :oembed ? inline_loader : static_loader
      end

      def inline_loader
        <<-SCRIPT
        <script>
          #{ERB.new(File.read("#{Rails.root}/app/views/documents/embed_loader.js.erb")).result(binding)}
        </script>
        SCRIPT
      end

      def static_loader
        %(<script type="text/javascript" src="#{DC.asset_root(agnostic: true)}/viewer/loader.js"></script>)
      end

      # intended for use in the static deployment to s3.
      def self.static_loader(options={})
        template_path = "#{Rails.root}/app/views/documents/embed_loader.js.erb"
        ERB.new(File.read(template_path)).result(binding)
      end

      def as_json
        if @strategy == :oembed
          calculate_dimensions
          {
            type:          "rich",
            version:       "1.0",
            provider_name: "DocumentCloud",
            provider_url:  DC.server_root(force_ssl: true),
            cache_age:     300,
            height:        @dimensions[:height],
            width:         @dimensions[:width],
            html:          code,
          }
        else
          @resource.as_json.merge(html: code)
        end
      end

      def calculate_dimensions
        default_width = ::Page::IMAGE_SIZES['normal'].gsub(/x$/, '').to_i
        @dimensions = {
          height: @embed_config[:maxheight] || ((@embed_config[:maxwidth] || default_width) / @document.safe_aspect_ratio).round,
          width:  @embed_config[:maxwidth]  || (@embed_config[:maxheight] ? (@embed_config[:maxheight] * @document.safe_aspect_ratio).round : default_width)
        }
      end

    end
  end
end