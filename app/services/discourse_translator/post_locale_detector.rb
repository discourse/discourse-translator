# frozen_string_literal: true

module DiscourseTranslator
  class PostLocaleDetector
    def self.detect_locale(post)
      return if post.blank?

      translator = DiscourseTranslator::Provider::TranslatorProvider.get
      detected_locale = translator.detect!(post)
      post.update!(locale: detected_locale)
      detected_locale
    end
  end
end
