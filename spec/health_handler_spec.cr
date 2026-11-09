require "./spec_helper"

private def request(handler : HTTP::Handler, method : String, path : String) : HTTP::Client::Response
  server = HTTP::Server.new([handler])
  address = server.bind_unused_port
  spawn server.listen

  until server.listening?
    Fiber.yield
  end

  HTTP::Client.new(address.address, address.port) do |client|
    client.exec(method, path)
  end
ensure
  server.try(&.close)
end

describe Gemvault::HealthHandler do
  it "reports process liveness" do
    response = request(Gemvault::HealthHandler.new, "GET", "/health/live")

    response.status_code.should eq(200)
    response.content_type.should eq("application/json")
    response.body.should eq(%({"status":"ok","check":"process"}))
  end

  it "reports only the checks implemented by the skeleton" do
    response = request(Gemvault::HealthHandler.new, "GET", "/health/ready")

    response.status_code.should eq(200)
    response.body.should eq(%({"status":"ok","checks":{"configuration":"ok"}}))
  end

  it "returns headers without a body for HEAD" do
    response = request(Gemvault::HealthHandler.new, "HEAD", "/health/live")

    response.status_code.should eq(200)
    response.body.should be_empty
    response.headers["Content-Length"].to_i.should be > 0
  end

  it "does not claim that an unimplemented registry route exists" do
    response = request(Gemvault::HealthHandler.new, "GET", "/versions")

    response.status_code.should eq(404)
  end
end
