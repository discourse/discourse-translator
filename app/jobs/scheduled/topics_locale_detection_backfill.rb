# frozen_string_literal: true

module Jobs
  class TopicsLocaleDetectionBackfill < ::Jobs::Scheduled
    every 5.minutes
    sidekiq_options retry: false
    cluster_concurrency 1

    def execute(args)
      return unless SiteSetting.translator_enabled
      return unless SiteSetting.experimental_content_translation
      limit = SiteSetting.automatic_translation_backfill_rate
      return if limit == 0

      topics = Topic.where(locale: nil).where(deleted_at: nil).where("topics.user_id > 0")

      if SiteSetting.automatic_translation_backfill_limit_to_public_content
        public_categories = Category.where(read_restricted: false).pluck(:id)
        topics = topics.where(category_id: public_categories)
      end

      if SiteSetting.automatic_translation_backfill_max_age_days > 0
        topics =
          topics.where(
            "topics.created_at > ?",
            SiteSetting.automatic_translation_backfill_max_age_days.days.ago,
          )
      end

      topics = topics.order(updated_at: :desc).limit(limit)
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
