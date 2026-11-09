require "./spec_helper"

describe Gemvault do
  it "has a development version" do
    Gemvault::VERSION.should eq("0.1.0")
  end
end
