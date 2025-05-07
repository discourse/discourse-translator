# frozen_string_literal: true

module Jobs
  class DetectTranslateTopic < ::Jobs::Base
    def execute(args)
      return unless SiteSetting.translator_enabled
      return unless SiteSetting.experimental_content_translation
      return if args[:topic_id].blank?

      topic = Topic.find(args[:topic_id])
      if topic.blank? || topic.title.blank? || topic.deleted_at.present? || topic.user_id <= 0
        return
      end

      detected_locale = DiscourseTranslator::TopicLocaleDetector.detect_locale(topic)

      locales = SiteSetting.automatic_translation_target_languages.split("|")
      return if locales.blank?

      locales.each do |locale|
        next if locale == detected_locale

        begin
          DiscourseTranslator::TopicTranslator.translate(topic, locale)
        rescue => e
          Rails.logger.error(
            "Discourse Translator: Failed to translate topic #{topic.id} to #{locale}: #{e.message}",
          )
        end
      end
    end
  end
end
