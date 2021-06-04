# frozen_string_literal: true

class BbsExporter
  # Persists all the data for an export.
  class ArchiveBuilder
    attr_reader :current_export

    delegate :options, to: :current_export

    def initialize(current_export:)
      @current_export = current_export
    end

    # Write a record with the given type
    def write(model_name:, data:)
      file_for(model_name).add(data)
    end

    # Clone a repository's Git repository to the staging dir
    def clone_repo(repository)
      git.clone(
        url:    repo_clone_url(repository),
        target: repo_path(repository)
      )
    end

    # Put all of the data into a tar file and dispose of temporary files.
    def create_tar(path)
      files.values.each { |file| file.close }
      write_json_file("urls.json", UrlTemplates.new.templates)
      write_json_file("schema.json", {version: "1.2.0"})
      Archiver.pack(File.expand_path(path), staging_dir)
      FileUtils.remove_entry_secure staging_dir
    end

    # Returns true if anything was written to the archive.
    def used?
      files.any?
    end

    # Write a hash to a JSON file
    #
    # @param [String] path the path to the file to be written
    # @param [Hash] contents the Hash to be converted to JSON and written to
    #   file
    def write_json_file(path, contents)
      File.open(File.join(staging_dir, path), "w") do |file|
        file.write(JSON.pretty_generate(contents))
      end
    end

    # Determines whether or not a model has been exported. Used for caching.
    #
    # @param [String] model_name the type of model to check
    # @param [String] url the url of the model to check
    # @return [Boolean]
    def seen?(model_name, url)
      !!(seen_record[model_name] && seen_record[model_name][url])
    end

    # Indicates that a model has been exported. Used for caching.
    #
    # @param [String] model_name the type of model to cache
    # @param [String] url the url of the model to cache
    def seen(model_name, url)
      seen_record[model_name] ||= {}
      seen_record[model_name][url] = true
    end

    # The path where repositories are written to disk
    #
    # @param [Hash] repository the repository that will be written to disk
    # @return [String] the path where this repository's git repository will be written
    #   to disk
    def repo_path(repository)
      "#{staging_dir}/repositories/#{repository["project"]["key"] + "/" + repository["slug"]}.git"
    end

    def save_attachment(attachment_data, *path)
      target = File.join(staging_dir, "attachments", *path)
      FileUtils.mkdir_p(File.dirname(target))
      File.write(target, attachment_data, mode: "wb")
    end

    def staging_dir
      current_export.staging_dir
    end

    private

    def git
      @git ||= Git.new(ssl_verify: options[:ssl_verify])
    end

    def bitbucket_server
      current_export.bitbucket_server
    end

    def repo_clone_url(repository, user: bitbucket_server.authenticated_user)
      link = repository["links"]["clone"].detect do |clone_link|
        break clone_link["href"] if clone_link["name"] == "http"
      end

      return unless link

      uri = Addressable::URI.parse(link)
      uri.user = user

      uri.to_s
    end

    def seen_record
      @seen_record ||= {}
    end

    def file_for(model_name)
      files[model_name]
    end

    def files
      @files ||= Hash.new { |h, k| h[k] = SerializedModelWriter.new(staging_dir, k) }
    end
  end
end
