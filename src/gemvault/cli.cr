require "option_parser"
require "../gemvault"

module Gemvault
  class CLI
    def self.run(arguments : Array(String), stdout : IO = STDOUT, stderr : IO = STDERR) : Int32
      data_dir = "./data"
      check_config = false
      immediate_output : String? = nil

      parser = OptionParser.new do |opts|
        opts.banner = <<-USAGE
        Gemvault #{VERSION} — RubyGems registry protocol implementation in Crystal

        Status: project skeleton; registry endpoints are not implemented.

        Usage: gemvault [options]
        USAGE
        opts.on("--data-dir PATH", "Data directory (default: ./data)") { |path| data_dir = path }
        opts.on("--check-config", "Validate startup arguments; do not start a registry") { check_config = true }
        opts.on("--version", "Print the version") { immediate_output = VERSION }
        opts.on("-h", "--help", "Show this help") { immediate_output = opts.to_s }
        opts.invalid_option do |flag|
          raise ArgumentError.new("unknown option: #{flag}")
        end
      end

      parser.parse(arguments)

      if output = immediate_output
        stdout.puts output
        return 0
      end

      config = Config.from_data_dir(data_dir).check!

      if check_config
        stdout.puts "Configuration arguments are valid (data_dir=#{config.data_dir})."
        stdout.puts "Registry service is not implemented yet."
      else
        stdout.puts parser
        stdout.puts "\nNo registry service is available in this project skeleton."
      end
      0
    rescue ex : ArgumentError | OptionParser::Exception
      stderr.puts "gemvault: #{ex.message}"
      1
    end
  end
end
