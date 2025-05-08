# frozen_string_literal: true

module DiscourseTranslator
  class TopicTranslator
    def self.translate(topic, target_locale = I18n.locale)
      return if topic.blank? || target_locale.blank? || topic.locale == target_locale.to_s

      target_locale_sym = target_locale.to_s.sub("-", "_").to_sym

      translator = DiscourseTranslator::Provider::TranslatorProvider.get
      translated_title = translator.translate_topic!(topic, target_locale_sym)

      localization =
        TopicLocalization.find_or_initialize_by(topic_id: topic.id, locale: target_locale_sym.to_s)

      localization.title = translated_title
      localization.fancy_title = Topic.fancy_title(translated_title)
      localization.localizer_user_id = Discourse.system_user.id
      localization.save!
      localization
    end
  end
end
