# frozen_string_literal: true

module Jobs
  class TopicTranslationBackfill < ::Jobs::Scheduled
    every 5.minutes
    cluster_concurrency 1

    def execute(args)
      return unless SiteSetting.translator_enabled
      return unless SiteSetting.experimental_content_translation

      return if SiteSetting.experimental_content_localization_supported_locales.blank?
      return if SiteSetting.automatic_translation_backfill_rate == 0

      Jobs.enqueue(:translate_topics, limit: SiteSetting.automatic_translation_backfill_rate)
    end
  end
end
