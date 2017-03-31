require "aytests/vm"

module AYTests
  # Take screenshots of a VM
  #
  # This class updates a screenshot of a virtual machine.
  class VMObserver
    DEFAULT_INTERVAL = 30

    # @return [String] Virtual machine name
    attr_reader :name
    # @return [Symbol] virtual machine's provider (virtualbox or libvirt)
    attr_reader :provider
    # @return [Pathname] Screenshot path
    attr_reader :screenshot_path
    # @return [Integer] Time interval between screenshots
    attr_reader :interval

    # Constructor
    #
    # @param name [String] Virtual machine name
    # @param provider [Symbol] virtual machine's provider (virtualbox or libvirt)
    # @param screenshot_path [Pathname] Screenshot path
    # @param interval [Integer] Time interval between screenshots
    def initialize(name:, provider:, screenshot_path:, interval: DEFAULT_INTERVAL)
      @name = name
      @provider = provider.to_sym
      @screenshot_path = screenshot_path
      @interval = interval.to_i
    end

    # Start the observer loop
    def start
      loop do
        take_screenshot
        sleep interval
      end
    end

    # Take an screenshot
    #
    # @see AYTests::VM#screenshot
    def take_screenshot
      return unless vm
      vm.screenshot(screenshot_path)
    end

  private

    # Virtual machine
    #
    # @return [AYTests::VM,nil] Returns the virtual machine; nil if it does no exist.
    def vm
      return @vm if @vm
      @vm = AYTests::VM.new(name, provider)
    rescue StandardError
      # The machine does not exist yet
      nil
    end
  end
end
