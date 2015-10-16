module AYTests
  class IsoRepo
    def self.init(dir)
      @repo = IsoRepo.new(dir)
    end

    def self.get(uri)
      raise "Repository was not initialized (use IsoRepo.init)" if @repo.nil?
      @repo.get(uri)
    end

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
      iso_path = @dir.join(File.basename(uri))
      if iso_path.exist?
        iso_path
      elsif download_to(uri, iso_path)
        iso_path
      else
        false
      end
    end

    # Download an ISO
    #
    # @return [true, false] +true+ if the ISO was downloaded successfully;
    #                       +false+ otherwise.
    def download_to(uri, iso_path)
      system("wget --no-clobber --progress=dot:giga -O #{iso_path} #{uri}")
    end
  end
end
