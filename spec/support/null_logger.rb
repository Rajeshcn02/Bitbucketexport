# frozen_string_literal: true

class NullLogger < Logger
  def initialize(*args)
  end

  def add(*args, &block)
  end

  def model_url_service(model, opts = {})
  end
end
