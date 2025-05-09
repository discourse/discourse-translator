# frozen_string_literal: true

module DiscourseTranslator
  module Provider
    extend ActiveSupport::Concern

    class TranslatorError < ::StandardError
    end

    class ProblemCheckedTranslationError < TranslatorError
    end

    class BaseProvider
      DETECTION_CHAR_LIMIT = 1000

      def self.key_prefix
        "#{PLUGIN_NAME}:".freeze
      end

      def self.access_token_key
        raise "Not Implemented"
      end

      def self.cache_key
        "#{key_prefix}#{access_token_key}"
      end

      # Translates and saves it into a PostTranslation/TopicTranslation
      # If the detected language is the same as the target language, the original text will be returned.
      # @param translatable [Post|Topic]
      # @return [Array] the detected language and the translated text
      def self.translate(translatable, target_locale_sym = I18n.locale)
        detected_lang = detect(translatable)

        if translatable.locale_matches?(target_locale_sym)
          return detected_lang, get_untranslated(translatable)
        end

        translation = translatable.translation_for(target_locale_sym)
        return detected_lang, translation if translation.present?

        unless translate_supported?(detected_lang, target_locale_sym)
          raise TranslatorError.new(
                  I18n.t(
                    "translator.failed.#{translatable.class.name.downcase}",
                    source_locale: detected_lang,
                    target_locale: target_locale_sym,
                  ),
                )
        end

        begin
          begin
            translated =
              case translatable.class.name
              when "Post"
                translate_post!(translatable, target_locale_sym, { cooked: true })
              when "Topic"
                translate_topic!(translatable, target_locale_sym)
              end
          end
        rescue => e
          raise I18n.t(
                  "translator.failed.#{translatable.class.name.downcase}",
                  source_locale: detected_lang,
                  target_locale: target_locale_sym,
                )
        end

        translatable.set_translation(target_locale_sym, translated)
        [detected_lang, translated]
      end

      def self.translate_text!(text, target_locale_sym = I18n.locale)
        raise "Not Implemented"
      end

      def self.translate_post!(post, target_locale_sym = I18n.locale, opts = {})
        raise "Not Implemented"
      end

      def self.translate_topic!(topic, target_locale_sym = I18n.locale)
        raise "Not Implemented"
      end

      # Returns the stored detected locale of a post or topic.
      # If the locale does not exist yet, it will be detected first via the API then stored.
      # @param translatable [Post|Topic]
      def self.detect(translatable)
        return if text_for_detection(translatable).blank?
        translatable.detected_locale || translatable.set_detected_locale(detect!(translatable))
      end

      # Subclasses must implement this method to detect the text of a post or topic
      # and return only the detected locale.
      # Subclasses should use text_for_detection
      # @param translatable [Post|Topic]
      # @return [String]
      def self.detect!(translatable)
        raise "Not Implemented"
      end

      def self.access_token
        raise "Not Implemented"
      end

      def self.language_supported?(detected_lang)
        raise NotImplementedError unless self.const_defined?(:SUPPORTED_LANG_MAPPING)
        supported_lang = const_get(:SUPPORTED_LANG_MAPPING)
        return false if supported_lang[I18n.locale].nil?
        detected_lang != supported_lang[I18n.locale]
      end

      def self.translate_supported?(detected_lang, target_lang)
        true
      end

      private

      def self.text_for_detection(translatable)
        text = get_untranslated(translatable, raw: true)

        if translatable.class.name == "Topic"
          # due to topics having short titles,
          # we need to add the first post to the detection text
          first_post = get_untranslated(translatable.first_post, raw: true)
          text = text + " " + first_post if first_post
        end

        text.truncate(DETECTION_CHAR_LIMIT, omission: nil)
      end

      def self.text_for_translation(translatable, raw: false)
        max_char = SiteSetting.max_characters_per_translation
        get_untranslated(translatable, raw:).truncate(max_char, omission: nil)
      end

      def self.get_untranslated(translatable, raw: false)
        case translatable.class.name
        when "Post"
          raw ? translatable.raw : translatable.cooked
        when "Topic"
          translatable.title
        end
      end
    end
  end
end
