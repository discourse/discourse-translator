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

      def self.translate_translatable!(translatable, target_locale_sym = I18n.locale)
        if (translatable.class.name == "Post")
          translate_post!(translatable, target_locale_sym)
        elsif (translatable.class.name == "Topic")
          translate_topic!(translatable, target_locale_sym)
        end
      end

      def self.translate_post!(post, target_locale_sym = I18n.locale)
        validate_required_settings!

        text = text_for_translation(post, raw: true)
        chunks = DiscourseTranslator::ContentSplitter.split(text)
        translated =
          chunks
            .map { |chunk| ::DiscourseAi::PostTranslator.new(chunk, target_locale_sym).translate }
            .join("")
        DiscourseTranslator::TranslatedContentNormalizer.normalize(post, translated)
      end

      def self.translate_topic!(topic, target_locale_sym = I18n.locale)
        validate_required_settings!

        language = get_language_name(target_locale_sym)
        translated =
          ::DiscourseAi::TopicTranslator.new(text_for_translation(topic), language).translate
        DiscourseTranslator::TranslatedContentNormalizer.normalize(topic, translated)
      end

      def self.translate_text!(text, target_locale_sym = I18n.locale)
        validate_required_settings!

        language = get_language_name(target_locale_sym)
        ::DiscourseAi::ShortTextTranslator.new(text, language).translate
      end

      private

      def self.validate_required_settings!
        unless SiteSetting.translator_enabled && SiteSetting.translator_provider == "DiscourseAi" &&
                 SiteSetting.discourse_ai_enabled && SiteSetting.ai_helper_enabled
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
