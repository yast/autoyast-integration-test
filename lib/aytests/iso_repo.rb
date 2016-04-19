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
    # @return [Pathname]  Path to the local ISO.
    def get(uri)
      iso_path = File.join(@dir, URI(uri).host, URI(uri).path)
      iso_dir = File.dirname(iso_path)
      if uri.include?("*") || uri.include?("?")
        # We have wildcards in the uri. So we have to remove
        # old ISOs before because the name could have been changed
        # meanwhile.
        Dir.entries(iso_dir).each do |filename|
          path = File.join(iso_dir, filename)
          File.delete(path) unless File.directory?(path)
        end
      end
      if download_to(uri)
        # Returning the first found ISO in this directory
        filename = Dir.entries(iso_dir).find do |f| 
          File.file?(File.join(iso_dir, f)) && f.end_with?(".iso")
        end
        File.join( iso_dir, filename)
      else
        false
      end
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
