# frozen_string_literal: true

module ArchiveHelpers
  def file_list_from_archive(archive_path)
    read_tar(archive_path) do |tar_reader|
      tar_reader.map do |entry|
        entry.header.name
      end
    end
  end

  def read_file_from_archive(archive_path, file_path)
    read_tar(archive_path) do |tar_reader|
      tar_reader.each do |entry|
        return entry.read if entry.header.name == file_path
      end
    end
  end

  def read_tar(archive_path)
    File.open(archive_path, "rb") do |file|
      Zlib::GzipReader.wrap(file) do |zlib|
        Gem::Package::TarReader.new(zlib) do |tar_reader|
          return yield(tar_reader)
        end
      end
    end
  end
end
