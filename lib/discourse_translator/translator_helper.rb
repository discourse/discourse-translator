# frozen_string_literal: true

module DiscourseTranslator
  module TranslatorHelper
    def self.translated_value(original_value, model, scope)
      return original_value if !SiteSetting.experimental_topic_translation
      return original_value if scope.request.params["show"] == "original"

      translated = model.custom_fields[TRANSLATED_CUSTOM_FIELD]
      return original_value if (translated.blank? || translated[I18n.locale].blank?)

      translated[I18n.locale]
    end
  end
end
