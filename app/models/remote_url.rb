require 'cgi'

class RemoteUrl < ActiveRecord::Base

  self.establish_connection(ANALYTICS_DB)

  DOCUMENT_CLOUD_URL = /^https?:\/\/(www\.)?documentcloud.org/

  named_scope :aggregated, {
    :select => 'sum(hits) AS hits, document_id, url',
    :group => 'document_id, url'
  }

  named_scope :by_document, {
    :select => 'sum(hits) AS hits, document_id',
    :group => 'document_id'
  }

  def self.record_hits_on_documents(doc_id, url, hits)
    url = url.mb_chars[0...255].to_s
    row = self.find_or_create_by_document_id_and_url_and_date_recorded(doc_id, url, Time.now.utc.to_date)
    row.update_attributes :hits => row.hits + hits
    
    # Increment the document's total hits.
    doc = Document.find_by_id(doc_id)
    doc.update_attributes(:hit_count => doc.hit_count + hits) if doc
  end

  def self.record_hits_on_searches(query, url, hits)
    url   = url.mb_chars[0...255].to_s
    query = CGI::unescape(query)
    row   = self.find_or_create_by_search_query_and_url_and_date_recorded(query, url, Time.now.utc.to_date)
    row.update_attributes :hits => row.hits + hits
  end

  def self.record_hits_on_notes(note_id, url, hits)
    url = url.mb_chars[0...255].to_s
    row = self.find_or_create_by_note_id_and_url_and_date_recorded(note_id, url, Time.now.utc.to_date)
    row.update_attributes :hits => row.hits + hits
  end

  # Using the recorded remote URL hits, correctly set detected remote urls
  # for all listed document ids. This method is only ever run within a
  # background job.
  def self.populate_detected_document_ids(doc_ids)
    urls = self.aggregated.all(:conditions => {:document_id => doc_ids})
    top  = urls.inject({}) do |memo, url|
      if DOCUMENT_CLOUD_URL =~ url.url
        memo
      else
        id = url.document_id
        memo[id] = url if !memo[id] || memo[id].hits < url.hits
        memo
      end
    end
    Document.find_each(:conditions => {:id => top.keys}) do |doc|
      doc.detected_remote_url = top[doc.id].url
      doc.save if doc.changed?
    end
  end

  def self.top_documents(days=7, options={})
    hit_documents = self.by_document.all({
      :conditions => ['date_recorded > ?', days.days.ago],
      :having => ['sum(hits) > 0'],
      :order => 'hits desc'
    }.merge(options))
    docs = Document.find_all_by_id(hit_documents.map {|u| u.document_id }).inject({}) do |memo, doc|
      memo[doc.id] = doc
      memo
    end
    hit_documents.select {|url| !!docs[url.document_id] }.map do |url|
      url_attrs = url.attributes
      url_attrs[:url] = docs[url.document_id].published_url
      url_attrs[:id] = "#{url.document_id}:#{url_attrs[:url]}"
      first_hit = RemoteUrl.first(:select => 'created_at',
                                  :conditions => {:document_id => url['document_id']},
                                  :order => 'created_at ASC')
      url_attrs[:first_recorded_date] = first_hit[:created_at].strftime "%a %b %d, %Y"
      docs[url.document_id].admin_attributes.merge(url_attrs)
    end
  end
  
  def self.top_searches(days=7, options={})
    
  end
  
  def self.top_notes(days=7, options={})
    
  end

end