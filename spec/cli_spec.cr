require "./spec_helper"
require "../src/gemvault/cli"

describe Gemvault::CLI do
  it "prints help without claiming a registry is running" do
    output = IO::Memory.new

    status = Gemvault::CLI.run(["--help"], output)

    status.should eq(0)
    output.to_s.should contain("not implemented")
  end

  it "validates an absolute data directory without creating it" do
    output = IO::Memory.new

    status = Gemvault::CLI.run(["--check-config", "--data-dir", "./tmp/test-data"], output)

    status.should eq(0)
    output.to_s.should contain("Configuration arguments are valid")
    output.to_s.should contain("not implemented")
  end

  it "rejects a blank data directory" do
    error = IO::Memory.new

    status = Gemvault::CLI.run(["--check-config", "--data-dir", " "], STDERR, error)

    status.should eq(1)
    error.to_s.should contain("data directory")
  end

  it "fails fast for unknown options" do
    error = IO::Memory.new

    status = Gemvault::CLI.run(["--not-an-option"], STDERR, error)

    status.should eq(1)
    error.to_s.should contain("unknown option")
  end
end
