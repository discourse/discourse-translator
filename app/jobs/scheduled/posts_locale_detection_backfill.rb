# frozen_string_literal: true

module Jobs
  class PostsLocaleDetectionBackfill < ::Jobs::Scheduled
    every 5.minutes
    cluster_concurrency 1

    def execute(args)
      return unless SiteSetting.translator_enabled
      return unless SiteSetting.experimental_content_translation
      return if SiteSetting.automatic_translation_backfill_rate == 0

      limit = SiteSetting.automatic_translation_backfill_rate
      posts =
        Post
          .where(locale: nil)
          .where(deleted_at: nil)
          .where("posts.user_id > 0")
          .where.not(raw: [nil, ""])
          .order(updated_at: :desc)
          .limit(limit)
      return if posts.empty?

      posts.each do |post|
        begin
          DiscourseTranslator::PostLocaleDetector.detect_locale(post)
        rescue FinalDestination::SSRFDetector::LookupFailedError
          # do nothing, there are too many sporadic lookup failures
        rescue => e
          Rails.logger.error(
            "Discourse Translator: Failed to detect post #{post.id}'s locale: #{e.message}",
          )
        end
      end

      DiscourseTranslator::VerboseLogger.log("Detected #{posts.size} post locales")
    end
  end
end
