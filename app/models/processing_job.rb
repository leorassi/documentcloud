# A ProcessingJob is the record of an active job on CloudCrowd.
class ProcessingJob < ActiveRecord::Base

  belongs_to :account
  belongs_to :document

  validates :cloud_crowd_id, :presence=>true
  #validates :action, :presence => true

  attr_accessor :remote_job
  
  scope :incomplete, ->{ where :complete => false }
  
  def self.endpoint
    "#{DC::CONFIG['cloud_crowd_server']}/jobs"
  end
  
  # A serializer which outputs the attributes needed
  # to post to CloudCrowd.
  class CloudCrowdSerializer < ActiveModel::Serializer
    attributes :action, :inputs, :options, :callback_url
    
    def options; object.options; end
    
    # inputs should always be an array of documents.
    def inputs; [object.document_id]; end
    
    def callback_url
      case object.action
      when "update_access"
        "#{DC.server_root(:ssl => false)}/import/update_access"
      when /(large_)?document_import/
        "#{DC.server_root(:ssl => false)}/import/cloud_crowd"
      else
        ""
      end
    end
  end

  def queue
    # take advantage of ActiveRecord's error system.
    errors.clear
    errors.add(:cloud_crowd_id, "This job has already been queued") && (return false) unless new_record?
    errors.add(:document, "must be locked as unavailable to queue") && (return false) unless document.unavailable? 
    errors.add(:document, "is already being processed")             && (return false) unless document.has_no_running_jobs?

    # Contact CloudCrowd to start the job, and get back its id.
    @response   = RestClient.post(ProcessingJob.endpoint, {:job => CloudCrowdSerializer.new(self).to_json})
    @remote_job = JSON.parse @response.body
    self.cloud_crowd_id = @remote_job['id']

    # We've collected all the info we need, so
    save # it
  end
  
  # We'll save options as a JSON string, so we need to 
  # cast it into a string when options are assigned.
  #
  # WARNING: if you monkey around with the contents of options
  # after it's assigned changes to the options won't be saved.
  def options=(opts)
    @parsed_options = opts
    write_attribute :options, @parsed_options.to_json
  end
  
  def options
    @parsed_options ||= JSON.parse(read_attribute :options)
  end

  # Return the JSON-ready Job status.
  def status
    (@remote_job || fetch_job).merge(attributes)
  end

  # Fetch the current status of the job from CloudCrowd.
  def fetch_job
    JSON.parse(RestClient.get(url).body)
  end

  # The URL of the Job on CloudCrowd.
  def url
    "#{ProcessingJob.endpoint}/#{cloud_crowd_id}"
  end

  # The default JSON of a processing job is just enough to get it polling for
  # updates again.
  def as_json(opts={})
    { 'id'      => id,
      'title'   => title,
      'status'  => 'loading'
    }
  end

end
