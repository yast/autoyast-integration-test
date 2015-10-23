require_relative "spec_helper"

describe "SLES 12 HTTP server " do
  it "checks, apache2 and firewall is running correctly" do
    run_test_script("http.sh")
  end
end
