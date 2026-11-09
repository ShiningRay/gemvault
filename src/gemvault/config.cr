module Gemvault
  # Minimal startup configuration for the project skeleton.
  # YAML configuration and storage initialization belong to the first
  # implementation milestone; they are not simulated here.
  struct Config
    getter data_dir : Path

    def initialize(@data_dir : Path = Path["./data"])
    end

    def self.from_data_dir(value : String) : Config
      if value.blank? || value.includes?('\0')
        raise ArgumentError.new("data directory must be a non-empty path without NUL bytes")
      end

      new(data_dir: Path[value].expand)
    end

    def check! : self
      raise ArgumentError.new("data directory cannot be empty") if data_dir.to_s.blank?

      self
    end
  end
end
