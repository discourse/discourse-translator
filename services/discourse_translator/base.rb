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

    def self.translate(object, target_language = I18n.locale)
      raise "Not Implemented"
    end

    def self.detect(object)
      raise "Not Implemented"
    end

    def self.access_token
      raise "Not Implemented"
    end

    def self.from_custom_fields(object, language)
      translated_custom_field = object.custom_fields[DiscourseTranslator::TRANSLATED_CUSTOM_FIELD] || {}
      translated_text = translated_custom_field[language]

      if translated_text.nil?
        translated_text = yield

        object.custom_fields[DiscourseTranslator::TRANSLATED_CUSTOM_FIELD] =
          translated_custom_field.merge("#{language}" => translated_text)

        object.save!
      end

      translated_text
    end

    def self.get_text(object, max_length = nil)
      case object.class.name
      when "Post"
        text = object.cooked
        text = text.truncate(max_length, omission: nil) if max_length
        text
      when "Topic"
        object.title
      else
        nil
      end
    end

    def self.get_custom_field(object)
      case object.class.name
      when "Post"
        DiscourseTranslator::DETECTED_LANG_CUSTOM_FIELD
      when "Topic"
        DiscourseTranslator::DETECTED_TITLE_LANG_CUSTOM_FIELD
      else
        nil
      end
    end
  end
end
