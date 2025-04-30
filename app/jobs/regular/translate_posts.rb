# frozen_string_literal: true

module Jobs
  class TranslatePosts < ::Jobs::Base
    cluster_concurrency 1
    BATCH_SIZE = 50

    def execute(args)
      return unless SiteSetting.translator_enabled
      return unless SiteSetting.experimental_content_translation

      locales = SiteSetting.automatic_translation_target_languages.split("|")
      return if locales.blank?

      # keeping this query simple by just getting any post with a missing localization
      posts =
        Post
          .left_joins(:post_localizations)
          .where(deleted_at: nil)
          .where("posts.user_id > 0")
          .where.not(raw: [nil, ""])
          .group("posts.id")
          .having(
            "COUNT(DISTINCT CASE WHEN post_localizations.locale IN (?) THEN post_localizations.locale END) < ?",
            locales,
            locales.size,
          )
          .order(updated_at: :desc)
          .limit(BATCH_SIZE)

      return if posts.empty?

      posts.each do |post|
        locales.each do |locale|
          next if post.locale == locale
          next if post.has_localization?(locale)

          begin
            DiscourseTranslator::PostTranslator.translate(post, locale)
          rescue => e
            Rails.logger.error(
              "Discourse Translator: Failed to translate post #{post.id} to #{locale}: #{e.message}",
            )
          end
        end
      end

      DiscourseTranslator::VerboseLogger.log(
        "Translated #{posts.size} posts to #{locales.join(", ")}",
      )
    end
  end
end
