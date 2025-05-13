# frozen_string_literal: true

module DiscourseTranslator
  module Provider
    class DiscourseAi < BaseProvider
      MAX_DETECT_LOCALE_TEXT_LENGTH = 1000
      def self.language_supported?(detected_lang)
        locale_without_region = I18n.locale.to_s.split("_").first
        detected_lang != locale_without_region
      end

      def self.detect!(topic_or_post)
        validate_required_settings!

        ::DiscourseAi::LanguageDetector.new(text_for_detection(topic_or_post)).detect
      end

      def self.translate_post!(post, target_locale_sym = I18n.locale, opts = {})
        validate_required_settings!

        raw = opts.key?(:raw) ? opts[:raw] : !opts[:cooked]
        text = text_for_translation(post, raw:)
        chunks = DiscourseTranslator::ContentSplitter.split(text)
        chunks
          .map { |chunk| ::DiscourseAi::PostTranslator.new(chunk, target_locale_sym).translate }
          .join("")
      end

      def self.translate_topic!(topic, target_locale_sym = I18n.locale)
        validate_required_settings!

        language = get_language_name(target_locale_sym)
        ::DiscourseAi::TopicTranslator.new(text_for_translation(topic), language).translate
      end

      def self.translate_text!(text, target_locale_sym = I18n.locale)
        validate_required_settings!

        language = get_language_name(target_locale_sym)
        ::DiscourseAi::ShortTextTranslator.new(text, language).translate
      end

      private

      def self.validate_required_settings!
        unless SiteSetting.translator_enabled && SiteSetting.translator_provider == "DiscourseAi" &&
                 SiteSetting.discourse_ai_enabled
          raise TranslatorError.new(
                  I18n.t(
                    "translator.discourse_ai.ai_helper_required",
                    { base_url: Discourse.base_url },
                  ),
                )
        end
      end

      def self.get_language_name(target_locale_sym)
        LocaleSiteSetting.language_names.dig(target_locale_sym.to_s, "name") ||
          "locale \"#{target_locale_sym}\""
      end
    end
  end
end
