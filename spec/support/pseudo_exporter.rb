# frozen_string_literal: true

class PseudoExporter
  attr_accessor :model

  def initialize(model:, bitbucket_server:)
    self.model = model
    @bitbucket_server = bitbucket_server
  end

  def current_export
    @current_export ||= BbsExporter.new(
      bitbucket_server: @bitbucket_server
    )
  end
end

class PseudoModel < Hash
end
