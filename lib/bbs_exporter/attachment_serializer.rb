# frozen_string_literal: true

class BbsExporter
  class AttachmentSerializer < BaseSerializer
    def to_gh_hash
      {
        :type               => type,
        :url                => url,
        parent_type.to_sym  => parent_model_url,
        :user               => user_url,
        :asset_name         => asset_name,
        :asset_content_type => asset_content_type,
        :asset_url          => asset_url,
        :created_date       => created_date_formatted
      }
    end

    private

    def type
      "attachment"
    end

    def url
      bbs_model[:url]
    end

    def parent_type
      bbs_model[:parent_type]
    end

    def parent_model
      bbs_model[:parent_model]
    end

    def user
      bbs_model[:user]
    end

    def asset_name
      bbs_model[:asset_name]
    end

    def asset_content_type
      bbs_model[:asset_content_type]
    end

    def asset_url
      bbs_model[:asset_url]
    end

    def created_date
      bbs_model[:created_date]
    end

    def user_url
      url_for_model(user, type: "user")
    end

    def parent_model_url
      url_for_model(parent_model, type: parent_type)
    end

    def created_date_formatted
      format_long_timestamp(created_date)
    end
  end
end
