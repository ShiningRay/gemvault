require "http/server"

require "./gemvault/version"
require "./gemvault/config"
require "./gemvault/health_handler"

# Gemvault is intended to implement RubyGems registry protocols.
#
# The registry endpoints are intentionally not exposed until their protocol
# and security contracts are implemented.
module Gemvault
end
