# frozen_string_literal: true

module Jobs
  class AutomaticTranslationBackfill < ::Jobs::Scheduled
    every 5.minutes

    BACKFILL_LOCK_KEY = "discourse_translator_backfill_lock"

    def execute(args = nil)
      return unless SiteSetting.translator_enabled
      return unless should_backfill?
      return unless secure_backfill_lock

      begin
        process_batch
      ensure
        Discourse.redis.del(BACKFILL_LOCK_KEY)
      end
    end

    def fetch_untranslated_model_ids(model = Post, limit = 100, target_locales = backfill_locales)
      m = model.name.downcase
      DB.query_single(<<~SQL, target_locales: target_locales, limit: limit)
        SELECT m.id
        FROM #{m}s m
        LEFT JOIN discourse_translator_#{m}_locales dl ON dl.#{m}_id = m.id
        LEFT JOIN LATERAL (
          SELECT array_agg(DISTINCT locale)::text[] as locales
          FROM discourse_translator_#{m}_translations dt
          WHERE dt.#{m}_id = m.id
        ) translations ON true
        WHERE NOT (
          ARRAY[:target_locales]::text[] <@
            (COALESCE(
              array_cat(
                ARRAY[COALESCE(dl.detected_locale, '')]::text[],
                COALESCE(translations.locales, ARRAY[]::text[])
              ),
              ARRAY[]::text[]
            ))
        )
        ORDER BY m.id DESC
        LIMIT :limit
      SQL
    end

    private

    def should_backfill?
      return false if SiteSetting.automatic_translation_target_languages.blank?
      return false if SiteSetting.automatic_translation_backfill_maximum_translations_per_hour == 0
      true
    end

    def secure_backfill_lock
      Discourse.redis.set(BACKFILL_LOCK_KEY, "1", ex: 5.minutes.to_i, nx: true)
    end

    def translations_per_run
      [
        (SiteSetting.automatic_translation_backfill_maximum_translations_per_hour / 12) /
          backfill_locales.size,
        1,
      ].max
    end

    def backfill_locales
      @backfill_locales ||= SiteSetting.automatic_translation_target_languages.split("|")
    end

    def translator
      @translator_klass ||= "DiscourseTranslator::#{SiteSetting.translator}".constantize
    end

    def translate_records(type, record_ids)
      record_ids.each do |id|
        record = type.find(id)
        backfill_locales.each do |target_locale|
          begin
            translator.translate(record, target_locale.to_sym)
          rescue => e
            # continue with other locales even if one fails
            Rails.logger.warn(
              "Failed to machine-translate #{type.name}##{id} to #{target_locale}: #{e.message}\n#{e.backtrace.join("\n")}",
            )
            next
          end
        end
      end
    end

    def process_batch
      models_translated = [Post, Topic].size
      translations_per_model = [translations_per_run / models_translated, 1].max
      topic_ids = fetch_untranslated_model_ids(Topic, translations_per_model)
      translations_per_model = translations_per_run - topic_ids.size
      post_ids = fetch_untranslated_model_ids(Post, translations_per_model)
      return if topic_ids.empty? && post_ids.empty?

      translate_records(Topic, topic_ids)
      translate_records(Post, post_ids)
    end
  end
end
