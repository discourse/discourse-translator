module DiscourseTranslator
  extend ActiveSupport::Concern

  class TranslatorError < ::StandardError; end;

  class Base
    def self.key_prefix
      "#{PLUGIN_NAME}:".freeze
    end

    def self.access_token_key
      raise "Not Implemented"
    end

    def self.cache_key
      "#{key_prefix}#{access_token_key}"
    end

    def self.translate(text, opts)
      raise "Not Implemented"
    end

    def self.detect(post)
      raise "Not Implemented"
    end

    def self.access_token
      raise "Not Implemented"
    end
  end
end
