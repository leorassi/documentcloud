module DC
  module Import

    # The EntityExtractor takes in a raw RDF file from OpenCalais, pulls out
    # all of the whitelisted entities we're interested in, and attaches them
    # to the document.
    class EntityExtractor

      OVER_CALAIS_QPS = '<h1>403 Developer Over Qps</h1>'

      MAX_TEXT_SIZE = CalaisFetcher::MAX_TEXT_SIZE

      def initialize
        super
        @entities = {}
      end

      # Public API: Pass in a document, either with full_text or rdf already
      # attached.
      def extract(document, text)
        @entities = {}
        chunks = CalaisFetcher.new.fetch_rdf(text)
        chunks.each_with_index do |chunk, i|
          next if chunk.blank?
          extract_information(document, chunk) if document.calais_id.blank?
          extract_entities(document, chunk, i)
        end
        document.entities = @entities.values
        document.save
      end


      private

      # Pull out all of the standard, top-level entities, and add it to our
      # document if it hasn't already been set.
      def extract_information(document, calais)
        info_elements = calais.raw.env.body.doc.info
        document.title = info_elements.docTitle unless document.titled?
        document.language ||= 'en' # TODO: Convert calais.language into an ISO language code.
        document.publication_date ||= info_elements.docDate
        document.calais_id = info_elements.calaisRequestID.match(/[^\/]+$/)[0] # Match string of characters after the last forward slash to the end of the url to get calais id. example: http://d.opencalais.com/comphash-1/7f9f8e5d-782c-357a-b6f3-7a5321f92e13
      end

      # Extract the entities that Calais discovers in the document, along with
      # the positions where they occur.
      def extract_entities(document, calais, chunk_number)
        offset = chunk_number * MAX_TEXT_SIZE
        calais.entities.each do |entity|
          kind = Entity.normalize_kind(entity[:type])
          value = entity[:name]
          next unless kind && value
          value = Entity.normalize_value(value)
          next if kind == :phone && Validators::PHONE !~ value
          next if kind == :email && Validators::EMAIL !~ value
          occurrences = entity[:matches].map do |instance|
            Occurrence.new(instance[:offset] + offset, instance[:length])
          end
          model = Entity.new(
            :value        => value,
            :kind         => kind.to_s,
            :relevance    => entity[:score],
            :document     => document,
            :occurrences  => Occurrence.to_csv(occurrences),
            :calais_id    => File.basename(entity[:guid]) # Match string of characters after the last forward slash to the end of the url to get calais id. example: http://d.opencalais.com/comphash-1/7f9f8e5d-782c-357a-b6f3-7a5321f92e13
          )
          if previous = @entities[model.calais_id]
            previous.merge(model)
          else
            @entities[model.calais_id] = model
          end
        end
      end

    end

  end
end
