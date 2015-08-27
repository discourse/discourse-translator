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

    def self.access_token
      raise "Not Implemented"
    end

    def self.translation_locale(current_user)
      if current_user && SiteSetting.allow_user_locale && !current_user.locale.empty?
        current_user.locale
      else
        SiteSetting.default_locale
      end
    end
  end
end
