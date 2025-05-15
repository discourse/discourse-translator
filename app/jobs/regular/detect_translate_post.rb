# frozen_string_literal: true

module Jobs
  class DetectTranslatePost < ::Jobs::Base
    def execute(args)
      return unless SiteSetting.translator_enabled
      return unless SiteSetting.experimental_content_translation
      return if args[:post_id].blank?

      post = Post.find_by(id: args[:post_id])
      return if post.blank? || post.raw.blank? || post.deleted_at.present? || post.user_id <= 0

      detected_locale = DiscourseTranslator::PostLocaleDetector.detect_locale(post)

      locales = SiteSetting.automatic_translation_target_languages.split("|")
      return if locales.blank?

      locales.each do |locale|
        next if locale == detected_locale

        begin
          DiscourseTranslator::PostTranslator.translate(post, locale)
        rescue FinalDestination::SSRFDetector::LookupFailedError
          # do nothing, there are too many sporadic lookup failures
        rescue => e
          Rails.logger.error(
            "Discourse Translator: Failed to translate post #{post.id} to #{locale}: #{e.message}",
          )
        end
      end
    end
  end
end
