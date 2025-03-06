# frozen_string_literal: true

module DiscourseTranslator
  extend ActiveSupport::Concern

  class TranslatorError < ::StandardError
  end

  class ProblemCheckedTranslationError < TranslatorError
  end

  class Base
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

    # Returns the stored translation of a post or topic.
    # If the translation does not exist yet, it will be translated first via the API then stored.
    # If the detected language is the same as the target language, the original text will be returned.
    # @param translatable [Post|Topic]
    def self.translate(translatable, target_locale_sym = I18n.locale)
      return if text_for_translation(translatable).blank?
      detected_lang = detect(translatable)

      if translatable.locale_matches?(target_locale_sym)
        return detected_lang, get_untranslated(translatable)
      end

      translation = translatable.translation_for(target_locale_sym)
      return detected_lang, translation if translation.present?

      unless translate_supported?(detected_lang, target_locale_sym)
        raise TranslatorError.new(
                I18n.t(
                  "translator.failed",
                  source_locale: detected_lang,
                  target_locale: target_locale_sym,
                ),
              )
      end

      translated = translate!(translatable, target_locale_sym)
      save_translation(translatable, target_locale_sym) { translated }
      [detected_lang, translated]
    end

    # Subclasses must implement this method to translate the text of a
    # post or topic and return only the translated text.
    # Subclasses should use text_for_translation
    # @param translatable [Post|Topic]
    # @param target_locale_sym [Symbol]
    # @return [String]
    def self.translate!(translatable, target_locale_sym = I18n.locale)
      raise "Not Implemented"
    end

    # Returns the stored detected locale of a post or topic.
    # If the locale does not exist yet, it will be detected first via the API then stored.
    # @param translatable [Post|Topic]
    def self.detect(translatable)
      return if text_for_detection(translatable).blank?
      get_detected_locale(translatable) ||
        save_detected_locale(translatable) { detect!(translatable) }
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

    def self.save_translation(translatable, target_locale_sym = I18n.locale)
      begin
        translation = yield
      rescue Timeout::Error
        raise TranslatorError.new(I18n.t("translator.api_timeout"))
      end
      translatable.set_translation(target_locale_sym, translation)
      translation
    end

    def self.get_detected_locale(translatable)
      translatable.detected_locale
    end

    def self.save_detected_locale(translatable)
      # sometimes we may have a user post that is just an emoji
      # in that case, we will just indicate the post is in the default locale
      detected_locale = yield.presence || SiteSetting.default_locale
      translatable.set_detected_locale(detected_locale)

      detected_locale
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

    def self.strip_tags_for_detection(detection_text)
      html_doc = Nokogiri::HTML::DocumentFragment.parse(detection_text)
      html_doc.css("img", "aside.quote", "div.lightbox-wrapper", "a.mention,a.lightbox").remove
      html_doc.to_html
    end

    def self.text_for_detection(translatable)
      strip_tags_for_detection(get_untranslated(translatable)).truncate(
        DETECTION_CHAR_LIMIT,
        omission: nil,
      )
    end

    def self.text_for_translation(translatable)
      max_char = SiteSetting.max_characters_per_translation
      get_untranslated(translatable).truncate(max_char, omission: nil)
    end

    def self.get_untranslated(translatable)
      case translatable.class.name
      when "Post"
        translatable.cooked
      when "Topic"
        translatable.title
      end
    end
  end
end
