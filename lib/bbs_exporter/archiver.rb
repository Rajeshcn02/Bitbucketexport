# frozen_string_literal: true

class BbsExporter
  class Archiver
    class << self
      # Creates a gzip-compressed tar archive of a directory.
      #
      # @param archive_path Path of the archive to write.
      # @param source_path Path of the directory to archive.
      def pack(archive_path, source_path)
        write_tar(archive_path) do |tar_writer|
          each_path(source_path) do |path|
            add_from_path(tar_writer, path)
          end
        end
      end

      private

      def write_tar(archive_path)
        File.open(archive_path, "wb") do |file|
          Zlib::GzipWriter.wrap(file) do |zlib|
            Gem::Package::TarWriter.new(zlib) do |tar_writer|
              yield(tar_writer)
            end
          end
        end
      end

      def each_path(source_path)
        Dir.chdir(source_path) do
          Dir["**/*"].each do |path|
            yield(path)
          end
        end
      end

      def add_from_path(tar_writer, path)
        stat = File.stat(path)

        if stat.directory?
          tar_writer.mkdir(path, stat.mode)
        elsif stat.file?
          tar_writer.add_file_simple(path, stat.mode, stat.size) do |tar_io|
            File.open(path) do |file|
              IO.copy_stream(file, tar_io)
            end
          end
        end
      end
    end
  end
end
