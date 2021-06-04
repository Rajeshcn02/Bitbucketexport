# frozen_string_literal: true

class BbsExporter
  # Serializes Users from Bitbucket Server's Users.
  class UserSerializer < BaseSerializer
    validates_presence_of :login, :name

    def to_gh_hash
      {
        type:        type,
        url:         url,
        login:       login,
        name:        name,
        emails:      emails,
        created_at:  created_at
      }
    end

    private

    def type
      "user"
    end

    def url
      url_for_model(bbs_model)
    end

    def login
      bbs_model["slug"]
    end

    def name
      bbs_model["displayName"]
    end

    def email_address
      bbs_model["emailAddress"]
    end

    def emails
      if email_address
        [
          {
            "address" => email_address,
            "primary" => true
          }
        ]
      else
        []
      end
    end

    def created_at
      generate_created_at
    end
  end
end
