# frozen_string_literal: true

module DiscourseTranslator
  extend ActiveSupport::Concern

  class TranslatorError < ::StandardError; end

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

    def self.translate(post)
      raise "Not Implemented"
    end

    def self.detect(post)
      raise "Not Implemented"
    end

    def self.access_token
      raise "Not Implemented"
    end

    def self.from_custom_fields(post)
      post_translated_custom_field = post.custom_fields[DiscourseTranslator::TRANSLATED_CUSTOM_FIELD] || {}
      translated_text = post_translated_custom_field[I18n.locale]

      if translated_text.nil?
        translated_text = yield

        post.custom_fields[DiscourseTranslator::TRANSLATED_CUSTOM_FIELD] =
          post_translated_custom_field.merge(I18n.locale => translated_text)

        post.save!
      end

      translated_text
    end
  end
end
