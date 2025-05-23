# frozen_string_literal: true

module Jobs
  class TranslatePosts < ::Jobs::Base
    cluster_concurrency 1
    sidekiq_options retry: false

    BATCH_SIZE = 50

    def execute(args)
      return unless SiteSetting.translator_enabled
      return unless SiteSetting.experimental_content_translation

      locales = SiteSetting.automatic_translation_target_languages.split("|")
      return if locales.blank?

      limit = args[:limit] || BATCH_SIZE

      locales.each do |locale|
        posts =
          Post
            .joins(
              "LEFT JOIN post_localizations pl ON pl.post_id = posts.id AND pl.locale = #{ActiveRecord::Base.connection.quote(locale)}",
            )
            .where(deleted_at: nil)
            .where("posts.user_id > 0")
            .where.not(raw: [nil, ""])
            .where.not(locale: nil)
            .where.not(locale: locale)
            .where("pl.id IS NULL")
            .limit(limit)

        next if posts.empty?

        posts.each do |post|
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

        DiscourseTranslator::VerboseLogger.log("Translated #{posts.size} posts to #{locale}")
      end
    end
  end
end
