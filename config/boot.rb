ENV['BUNDLE_GEMFILE'] ||= File.expand_path('../Gemfile', __dir__)

require "bundler/setup" # Set up gems listed in the Gemfile.

# Requires must come AFTER bundler/setup so Bundler can route to the
# Gemfile-pinned version rather than a pre-activated stdlib default gem.
require "logger"
require "yaml"
require "psych"

# This patch allows legacy Rails YAML aliases to work in Ruby 3.2
module Psych
  class << self
    alias_method :original_load, :load
    def load(yaml, *args, **kwargs)
      original_load(yaml, *args, aliases: true, **kwargs)
    rescue ArgumentError
      original_load(yaml, *args, **kwargs)
    end
  end
end

require "bootsnap/setup" # Speed up boot time by caching expensive operations.
