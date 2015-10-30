require_relative "spec_helper"

describe "SLES 12 TFTP server " do
  it "checks, tftp is running correctly" do
    run_test_script("tftp.sh")
  end

  # bug 870998
  it "checks, if host is in /etc/hosts" do
    run_test_script("host.sh")
  end

  # bug 925381
  it "checks, whether unsupported YaST modules are reported" do
    run_test_script("unsupported_modules.sh")
  end
end
