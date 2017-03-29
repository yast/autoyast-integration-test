require "forwardable"

module AYTests
  # This class allows to query and modify virtual machines attributes.
  # The communication with the virtual machines is implemented in
  # separated classes (LibvirtVM and VirtualboxVM).
  class VM
    extend Forwardable

    def_delegators :@driver, :mac, :mac=, :boot_order, :boot_order=, :stop,
      :backup, :restore!, :running?, :screenshot

    attr_reader :driver, :name

    # Constructor
    #
    # @param [String]        name     Virtual machine name
    # @param [String,Symbol] provider Virtual machine provider
    def initialize(name, provider)
      driver_class = "#{provider.capitalize}VM"
      @name = name
      require "aytests/#{provider}_vm"
      @driver = AYTests.const_get(driver_class).new(name)
    end

    # Update virtual machine attributes and saves the new definition
    #
    # This is just a convenience method to save some keystrokes.
    #
    # @param [Hash] attrs Attributes and values to save
    # @see #save
    def update(attrs)
      attrs.each do |meth, value|
        send("#{meth}=", value)
      end
      @driver.save
    end
  end
end
