# frozen_string_literal: true

module DiscourseTranslator
  class DiscourseAi < Base
    MAX_DETECT_LOCALE_TEXT_LENGTH = 1000
    def self.language_supported?(detected_lang)
      locale_without_region = I18n.locale.to_s.split("_").first
      detected_lang != locale_without_region
    end

    def self.detect!(topic_or_post)
      unless required_settings_enabled
        raise TranslatorError.new(
                I18n.t(
                  "translator.discourse_ai.ai_helper_required",
                  { base_url: Discourse.base_url },
                ),
              )
      end

      ::DiscourseAi::LanguageDetector.new(text_for_detection(topic_or_post)).detect
    end

    def self.translate!(translatable, target_locale_sym = I18n.locale)
      unless required_settings_enabled
        raise TranslatorError.new(
                I18n.t(
                  "translator.discourse_ai.ai_helper_required",
                  { base_url: Discourse.base_url },
                ),
              )
      end

      text = text_for_translation(translatable)
      chunks = DiscourseTranslator::ContentSplitter.split(text)
      chunks
        .map { |chunk| ::DiscourseAi::Translator.new(chunk, target_locale_sym).translate }
        .join("")
    end

    private

    def self.required_settings_enabled
      SiteSetting.translator_enabled && SiteSetting.translator_provider == "DiscourseAi" &&
        SiteSetting.discourse_ai_enabled && SiteSetting.ai_helper_enabled
    end
  end
end
