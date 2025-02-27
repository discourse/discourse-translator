# frozen_string_literal: true

require_relative "base"
require "json"

module DiscourseTranslator
  class DiscourseAi < Base
    MAX_DETECT_LOCALE_TEXT_LENGTH = 1000
    def self.language_supported?(detected_lang)
      locale_without_region = I18n.locale.to_s.split("_").first
      detected_lang != locale_without_region
    end

    def self.detect!(topic_or_post)
      return unless required_settings_enabled

      save_detected_locale(topic_or_post) do
        ::DiscourseAi::LanguageDetector.new(text_for_detection(topic_or_post)).detect
      end
    end

    def self.translate!(translatable, target_locale_sym = I18n.locale)
      return unless required_settings_enabled
      save_translation(translatable, target_locale_sym) do
        ::DiscourseAi::Translator.new(
          text_for_translation(translatable),
          target_locale_sym,
        ).translate
      end
    end

    private

    def self.required_settings_enabled
      SiteSetting.translator_enabled && SiteSetting.translator_provider == "DiscourseAi" &&
        SiteSetting.discourse_ai_enabled && SiteSetting.ai_helper_enabled
    end
  end
end
