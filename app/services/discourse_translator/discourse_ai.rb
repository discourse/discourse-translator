# frozen_string_literal: true

require_relative "base"
require "json"

module DiscourseTranslator
  class DiscourseAi < Base
    MAX_DETECT_LOCALE_TEXT_LENGTH = 1000
    def self.language_supported?(_)
      true
    end

    def self.detect(topic_or_post)
      return unless required_settings_enabled

      topic_or_post.custom_fields[DiscourseTranslator::DETECTED_LANG_CUSTOM_FIELD] ||= begin
        ::DiscourseAi::LanguageDetector.new(text_for_detection(topic_or_post)).detect
      end
    rescue => e
      e.message
      Rails.logger.warn("Failed to detect language: #{e}")
    end

    def self.translate(topic_or_post)
      return unless required_settings_enabled

      detected_lang = detect(topic_or_post)
      translated_text =
        from_custom_fields(topic_or_post) do
          ::DiscourseAi::Translator.new(text_for_translation(topic_or_post), I18n.locale).translate
        end

      [detected_lang, translated_text]
    end

    private

    def self.required_settings_enabled
      SiteSetting.translator_enabled && SiteSetting.translator == "DiscourseAi" &&
        SiteSetting.discourse_ai_enabled && SiteSetting.ai_helper_enabled
    end
  end
end
