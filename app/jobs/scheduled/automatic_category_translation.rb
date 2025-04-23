# frozen_string_literal: true

module Jobs
  class AutomaticCategoryTranslation < ::Jobs::Scheduled
    every 12.hours
    cluster_concurrency 1

    def execute(args)
      return unless SiteSetting.translator_enabled
      return unless SiteSetting.experimental_category_translation

      locales = SiteSetting.automatic_translation_target_languages.split("|")
      return if locales.blank?

      Jobs.enqueue(:translate_categories)
    end
  end
end
