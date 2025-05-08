# frozen_string_literal: true

module DiscourseTranslator
  class TopicLocaleDetector
    def self.detect_locale(topic)
      return if topic.blank?

      translator = DiscourseTranslator::Provider::TranslatorProvider.get
      detected_locale = translator.detect!(topic)
      locale = LocaleNormalizer.normalize_to_i18n(detected_locale)
      topic.update_column(:locale, locale)
      locale
    end
  end
end
