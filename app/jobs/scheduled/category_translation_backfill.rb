# frozen_string_literal: true

module Jobs
  class CategoryTranslationBackfill < ::Jobs::Scheduled
    every 12.hours
    cluster_concurrency 1

    def execute(args)
      return unless SiteSetting.translator_enabled
      return unless SiteSetting.experimental_content_translation

      return if SiteSetting.experimental_content_localization_supported_locales.blank?

      Jobs.enqueue(:translate_categories)
    end
  end
end
