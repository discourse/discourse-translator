# frozen_string_literal: true

module Jobs
  class TranslateTopics < ::Jobs::Base
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
        topics =
          Topic
            .joins(
              "LEFT JOIN topic_localizations tl ON tl.topic_id = topics.id AND tl.locale = #{ActiveRecord::Base.connection.quote(locale)}",
            )
            .where(deleted_at: nil)
            .where("topics.user_id > 0")
            .where.not(locale: nil)
            .where.not(locale: locale)
            .where("tl.id IS NULL")

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

        next if topics.empty?

        topics.each do |topic|
          begin
            DiscourseTranslator::TopicTranslator.translate(topic, locale)
          rescue FinalDestination::SSRFDetector::LookupFailedError
            # do nothing, there are too many sporadic lookup failures
          rescue => e
            Rails.logger.error(
              "Discourse Translator: Failed to translate topic #{topic.id} to #{locale}: #{e.message}",
            )
          end
        end

        DiscourseTranslator::VerboseLogger.log("Translated #{topics.size} topics to #{locale}")
      end
    end
  end
end
