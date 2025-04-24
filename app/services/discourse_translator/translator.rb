# frozen_string_literal: true

module DiscourseTranslator
  # The canonical class for all your translation needs
  class Translator
    # this invokes the specific methods
    def translate(translatable, target_locale = I18n.locale)
      target_locale_sym = target_locale.to_s.sub("-", "_").to_sym

      case translatable.class.name
      when "Post", "Topic"
        DiscourseTranslator::Provider.TranslatorProvider.get.translate(
          translatable,
          target_locale_sym,
        )
      when "Category"
        CategoryTranslator.translate(translatable, target_locale)
      end
    end
  end
end
