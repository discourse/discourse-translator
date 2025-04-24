# frozen_string_literal: true

module DiscourseTranslator
  class CategoryTranslator
    # unlike post and topics, categories do not have a detected locale
    # and will translate two fields, name and description

    def self.translate(category, target_locale = I18n.locale)
      return if category.blank? || target_locale.blank?

      # locale can come in various forms
      # standardize it to a _ symbol
      target_locale_sym = target_locale.to_s.sub("-", "_").to_sym

      translator = DiscourseTranslator::Provider::TranslatorProvider.get
      translated_name = translator.translate_text!(category.name, target_locale_sym)
      translated_description = translator.translate_text!(category.description, target_locale_sym)

      localization =
        CategoryLocalization.find_or_initialize_by(
          category_id: category.id,
          locale: target_locale_sym.to_s,
        )

      localization.name = translated_name
      localization.description = translated_description
      localization.save!
      localization
    end
  end
end
