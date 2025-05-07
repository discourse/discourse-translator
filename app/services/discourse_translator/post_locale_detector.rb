# frozen_string_literal: true

module DiscourseTranslator
  class PostLocaleDetector
    def self.detect_locale(post)
      return if post.blank?

      translator = DiscourseTranslator::Provider::TranslatorProvider.get
      detected_locale = translator.detect!(post)
      locale = LocaleNormalizer.normalize_to_i18n(detected_locale)
      post.update!(locale:)
      locale
    end
  end
end
