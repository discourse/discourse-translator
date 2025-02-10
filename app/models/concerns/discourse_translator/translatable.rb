# frozen_string_literal: true

module DiscourseTranslator
  module Translatable
    extend ActiveSupport::Concern

    prepended do
      has_many :translations,
               class_name: "DiscourseTranslator::#{name}Translation",
               dependent: :destroy
      has_one :content_locale, class_name: "DiscourseTranslator::#{name}Locale", dependent: :destroy
    end

    def set_detected_locale(locale)
      # locales should be "en-US" instead of "en_US" per https://www.rfc-editor.org/rfc/rfc5646#section-2.1
      locale = locale.to_s.gsub("_", "-")
      (content_locale || build_content_locale).update!(detected_locale: locale)
    end

    def set_translation(locale, text)
      locale = locale.to_s.gsub("_", "-")
      translations.find_or_initialize_by(locale: locale).update!(translation: text)
    end

    def translation_for(locale)
      translations.find_by(locale: locale)&.translation
    end

    def detected_locale
      content_locale&.detected_locale
    end

    private

    def clear_translations
      return if !SiteSetting.translator_enabled

      translations.delete_all
      content_locale&.destroy
    end
  end
end
