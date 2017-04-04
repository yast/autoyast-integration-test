module AYTests
  # A module which includes a logger method just for convenience.
  module Helpers
    # Return the logger object for AYTests
    #
    # @return [Logger] Logger object.
    def log
      AYTests.logger
    end
  end
end
