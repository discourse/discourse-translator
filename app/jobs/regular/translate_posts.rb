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

      sql = <<~SQL
        SELECT DISTINCT posts.*
        FROM posts
        CROSS JOIN unnest(ARRAY[#{locales.map { |l| ActiveRecord::Base.connection.quote(l) }.join(",")}]) AS target_locale(locale)
        WHERE
          posts.deleted_at IS NULL
          AND posts.user_id > 0
          AND posts.raw IS NOT NULL AND posts.raw <> ''
          AND posts.locale IS NOT NULL
          AND target_locale.locale != posts.locale
          AND NOT EXISTS (
            SELECT 1 FROM post_localizations
            WHERE post_localizations.post_id = posts.id
              AND post_localizations.locale = target_locale.locale
          )
      SQL

      posts = Post.find_by_sql(sql)

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
