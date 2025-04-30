# frozen_string_literal: true

module Jobs
  class DetectPostsLocale < ::Jobs::Base
    cluster_concurrency 1
    BATCH_SIZE = 50

    def execute(args)
      return unless SiteSetting.translator_enabled
      return unless SiteSetting.experimental_content_translation

      posts =
        Post
          .where(locale: nil)
          .where(deleted_at: nil)
          .where("posts.user_id > 0")
          .where.not(raw: [nil, ""])
          .order(id: :desc)
          .limit(BATCH_SIZE)
      return if posts.empty?

      posts.each do |post|
        begin
          DiscourseTranslator::PostLocaleDetector.detect_locale(post)
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
