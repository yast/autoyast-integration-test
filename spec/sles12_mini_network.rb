require_relative "../helper/spec_helper.rb"

describe "SLES 12 first stage only," do
  it "if user -vagrant- has been created" do
    run_test_script("user.sh")
  end

  it "YaST2 packages are not installed" do
    run_test_script("no_yast2_packages.sh")
  end

  it "second stage was not executed" do
    run_test_script("no_second_stage.sh")
  end

  # bnc#944942
  it "network has been set up" do
    run_test_script("check_dns.sh")
  end

end
