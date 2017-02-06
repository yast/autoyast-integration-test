require "uri"

module AYTests
  # Responsible for providing access to ISO images.
  # If the image is not available in the repository directory,
  # it will be downloaded.
  class IsoRepo
    attr_reader :dir

    # Initializes the repository
    #
    # @param [Pathname] Directory to use
    def self.init(dir)
      FileUtils.mkdir_p(dir) unless dir.directory?
      @repo = IsoRepo.new(dir)
    end

    # Convenience method to retrieve an ISO
    #
    # It relies in IsoRepo#get.
    #
    # @see get
    def self.get(uri)
      raise "Repository was not initialized (use IsoRepo.init)" if @repo.nil?
      @repo.get(uri)
    end

    # Constructor
    def initialize(dir)
      @dir = dir
    end

    # Returns a local path to an ISO
    #
    # If the ISO is not downloaded yet, tries to download it.
    #
    # @param [String] uri URI
    # @return [Pathname] Path to the local ISO.
    def get(uri)
      iso_path = File.join(@dir, URI(uri).host, URI(uri).path)
      iso_dir = File.dirname(iso_path)
      return false unless download_to(uri)

      iso_files = Dir.glob(File.join(iso_dir, "*"))
      # Get the newest file and...
      filename = iso_files.sort_by { |f| File.mtime(f) }.reverse.first
      # ... remove the rest of files
      (iso_files - [filename]).each { |f| File.delete(f) } unless iso_files.empty?
      filename
    end

    # Download an ISO
    #
    # @return [true, false] true if the ISO was downloaded successfully;
    #                       false otherwise.
    def download_to(uri)
      Dir.chdir(@dir) do
        system("wget -r -l1 --no-clobber --progress=dot:giga"\
          " -A \'#{File.basename(uri)}\' #{File.dirname(uri)}")
      end
    end
  end
end
