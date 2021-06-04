# frozen_string_literal: true

require "bbs_exporter/time_helpers"

class BbsExporter
  class BaseSerializer
    include ActiveModel::Validations

    extend Forwardable
    include TimeHelpers

    def initialize(options = {})
      @model_url_service = options.fetch(:model_url_service) do
        ModelUrlService.new
      end
    end

    attr_reader :model_url_service
    def_delegator :model_url_service, :url_for_model

    # Serialize a given model into a hash that fits GitHub's gh-migrator schema
    #
    # @param [Hash] bbs_model the Bitbucket Server model to be serialized
    # @return [Hash]
    # @example
    #   bbs_project = BitbucketServer.project('kylemacey', 'repo-contrib-graph')
    #   BbsExporter::RepositorySerializer.new.serialize(bbs_project)
    def serialize(bbs_model)
      self.bbs_model = bbs_model
      validate!

      to_gh_hash
    end

    # Implements the serialization for the model
    #
    # @return [Hash]
    def to_gh_hash
      raise NotImplementedError, :to_gh_hash
    end

    private

    attr_accessor :bbs_model

    def format_timestamp(timestamp, date = false)
      return if timestamp.nil?
      time = Time.parse(timestamp).utc
      (date ? time.at_midnight : time).xmlschema
    end
  end
end
