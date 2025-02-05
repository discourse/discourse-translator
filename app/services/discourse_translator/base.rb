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

    def self.translate(topic_or_post)
      return if text_for_translation(topic_or_post).blank?
      detected_lang = detect(topic_or_post)

      return detected_lang, get_text(topic_or_post) if (detected_lang&.to_s.eql? I18n.locale.to_s)
      unless translate_supported?(detected_lang, I18n.locale)
        raise TranslatorError.new(
                I18n.t(
                  "translator.failed",
                  source_locale: detected_lang,
                  target_locale: I18n.locale,
                ),
              )
      end

      translated_text = translate!(topic_or_post)

      [detected_lang, translated_text]
    end

    def self.translate!(post)
      raise "Not Implemented"
    end

    # Returns the stored detected locale of a post or topic.
    # If the locale does not exist yet, it will be detected first via the API then stored.
    # @param topic_or_post [Post|Topic]
    def self.detect(topic_or_post)
      return if text_for_detection(topic_or_post).blank?
      get_detected_locale(topic_or_post) || detect!(topic_or_post)
    end

    def self.detect!(post)
      raise "Not Implemented"
    end

    def self.access_token
      raise "Not Implemented"
    end

    def self.get_translation(topic_or_post)
      translated_custom_field =
        topic_or_post.custom_fields[DiscourseTranslator::TRANSLATED_CUSTOM_FIELD] || {}
      translated_custom_field[I18n.locale]
    end

    def self.save_translation(topic_or_post)
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

    def self.get_detected_locale(topic_or_post)
      topic_or_post.custom_fields[DiscourseTranslator::DETECTED_LANG_CUSTOM_FIELD]
    end

    def self.save_detected_locale(topic_or_post)
      detected_locale = yield
      topic_or_post.custom_fields[DiscourseTranslator::DETECTED_LANG_CUSTOM_FIELD] = detected_locale

      if !topic_or_post.custom_fields_clean?
        topic_or_post.save_custom_fields
        topic_or_post.publish_change_to_clients!(:revised) if topic_or_post.class.name == "Post"
      end

      detected_locale
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

    def self.translate_supported?(detected_lang, target_lang)
      true
    end

    private

    def self.strip_tags_for_detection(detection_text)
      html_doc = Nokogiri::HTML::DocumentFragment.parse(detection_text)
      html_doc.css("img", "aside.quote", "div.lightbox-wrapper", "a.mention,a.lightbox").remove
      html_doc.to_html
    end

    def self.text_for_detection(topic_or_post)
      strip_tags_for_detection(get_text(topic_or_post)).truncate(
        DETECTION_CHAR_LIMIT,
        omission: nil,
      )
    end

    def self.text_for_translation(topic_or_post)
      get_text(topic_or_post).truncate(SiteSetting.max_characters_per_translation, omission: nil)
    end
  end
end
