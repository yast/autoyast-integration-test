require_relative "spec_helper"

describe "SLES 12 with all yast2 packages installed" do
  it "check profile" do
    run_test_script("check_schema.sh")
  end
end
