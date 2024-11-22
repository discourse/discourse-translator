# frozen_string_literal: true

module DiscourseTranslator
  extend ActiveSupport::Concern

  class TranslatorError < ::StandardError
  end

  class ProblemCheckedTranslationError < TranslatorError
  end

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

    def self.from_custom_fields(topic_or_post)
      translated_custom_field =
        topic_or_post.custom_fields[DiscourseTranslator::TRANSLATED_CUSTOM_FIELD] || {}
      translated_text = translated_custom_field[I18n.locale]

      if translated_text.nil?
        translated_text = yield

        topic_or_post.custom_fields[
          DiscourseTranslator::TRANSLATED_CUSTOM_FIELD
        ] = translated_custom_field.merge(I18n.locale => translated_text)

        topic_or_post.save!
      end

      translated_text
    end

    def self.get_text(topic_or_post)
      case topic_or_post.class.name
      when "Post"
        topic_or_post.cooked
      when "Topic"
        topic_or_post.title
      end
    end

    def self.language_supported?(detected_lang)
      raise NotImplementedError unless self.const_defined?(:SUPPORTED_LANG_MAPPING)
      supported_lang = const_get(:SUPPORTED_LANG_MAPPING)
      return false if supported_lang[I18n.locale].nil?
      detected_lang != supported_lang[I18n.locale]
    end
  end
end
