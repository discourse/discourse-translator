# frozen_string_literal: true

module Jobs
  class TranslateCategories < ::Jobs::Base
    cluster_concurrency 1
    sidekiq_options retry: false

    BATCH_SIZE = 50

    def execute(args)
      return unless SiteSetting.translator_enabled
      return unless SiteSetting.experimental_content_translation

      locales = SiteSetting.automatic_translation_target_languages.split("|")
      return if locales.blank?

      cat_id = args[:from_category_id] || Category.order(:id).first&.id
      last_id = nil

      # we're just gonna take all categories and keep it simple
      # instead of checking in the db which ones are absent
      categories = Category.where("id >= ?", cat_id).order(:id).limit(BATCH_SIZE)
      return if categories.empty?

      categories.each do |category|
        if SiteSetting.automatic_translation_backfill_limit_to_public_content &&
             category.read_restricted?
          last_id = category.id
          next
        end

        CategoryLocalization.transaction do
          locales.each do |locale|
            next if CategoryLocalization.exists?(category_id: category.id, locale: locale)
            begin
              DiscourseTranslator::CategoryTranslator.translate(category, locale)
            rescue FinalDestination::SSRFDetector::LookupFailedError
              # do nothing, there are too many sporadic lookup failures
            rescue => e
              Rails.logger.error(
                "Discourse Translator: Failed to translate category #{category.id} to #{locale}: #{e.message}",
              )
            end
          end
        end
        last_id = category.id
      end

      # from batch if needed
      if categories.size == BATCH_SIZE
        Jobs.enqueue_in(10.seconds, :translate_categories, from_category_id: last_id + 1)
      end
    end
  end
end
