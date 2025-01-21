# frozen_string_literal: true

module ::DiscourseTranslator
  class TranslatedPostSerializer < PostSerializer
    attributes :is_translated

    def is_translated
      language = @options[:lang]
      translated = object.custom_fields[::DiscourseTranslator::TRANSLATED_CUSTOM_FIELD]
      !(language.blank? || translated.blank? || translated[language].blank?)
    end

    def cooked
      language = @options[:lang]
      translated = object.custom_fields[::DiscourseTranslator::TRANSLATED_CUSTOM_FIELD]
      is_translated ? translated[language] : super
    end
  end
end
