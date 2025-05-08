# frozen_string_literal: true

module Jobs
  class TopicsLocaleDetectionBackfill < ::Jobs::Scheduled
    every 5.minutes
    cluster_concurrency 1

    def execute(args)
      return unless SiteSetting.translator_enabled
      return unless SiteSetting.experimental_content_translation
      return if SiteSetting.automatic_translation_backfill_rate == 0

      limit = SiteSetting.automatic_translation_backfill_rate
      topics =
        Topic
          .where(locale: nil)
          .where(deleted_at: nil)
          .where("topics.user_id > 0")
          .order(updated_at: :desc)
          .limit(limit)
      return if topics.empty?

      topics.each do |topic|
        begin
          DiscourseTranslator::TopicLocaleDetector.detect_locale(topic)
        rescue FinalDestination::SSRFDetector::LookupFailedError
          # do nothing, there are too many sporadic lookup failures
        rescue => e
          Rails.logger.error(
            "Discourse Translator: Failed to detect topic #{topic.id}'s locale: #{e.message}",
          )
        end
      end

      DiscourseTranslator::VerboseLogger.log("Detected #{topics.size} topic locales")
    end
  end
end
