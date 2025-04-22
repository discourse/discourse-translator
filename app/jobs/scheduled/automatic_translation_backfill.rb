# frozen_string_literal: true

module Jobs
  class AutomaticTranslationBackfill < ::Jobs::Scheduled
    every 5.minutes
    cluster_concurrency 1

    def execute(args = nil)
      return unless SiteSetting.translator_enabled
      return unless should_backfill?

      process_batch
    end

    def fetch_untranslated_model_ids(model, content_column, limit, target_locale)
      m = model.name.downcase

      # Query selects every model (post/topic) *except* those who are **both**
      # already locale detected and translated
      DB.query_single(<<~SQL, target_locale: target_locale, limit: limit)
        SELECT * FROM
        (
          ( -- every post / topic
            SELECT m.id
            FROM #{model.table_name} m
            #{limit_to_public_clause(model)}
            WHERE m.deleted_at IS NULL
              AND m.#{content_column} != ''
              AND m.user_id > 0
              #{max_age_clause}
            ORDER BY m.updated_at DESC
          )
          EXCEPT
          (
            ( -- locale detected
              SELECT
                #{m}_id
              FROM
                discourse_translator_#{m}_locales
              WHERE
                detected_locale = :target_locale
            )
            INTERSECT
            ( -- translated
              SELECT #{m}_id
              FROM discourse_translator_#{m}_translations
              WHERE
                locale = :target_locale
            )
          )
        ) AS subquery
        LIMIT :limit
      SQL
    end

    private

    def should_backfill?
      return false if SiteSetting.automatic_translation_target_languages.blank?
      return false if SiteSetting.automatic_translation_backfill_rate == 0
      true
    end

    def backfill_locales
      @backfill_locales ||=
        SiteSetting.automatic_translation_target_languages.split("|").map { |l| l.gsub("_", "-") }
    end

    def translator
      @translator_klass ||=
        "DiscourseTranslator::Provider::#{SiteSetting.translator_provider}".constantize
    end

    def translate_records(type, record_ids, target_locale)
      record_ids.each do |id|
        record = type.find(id)
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

    def process_batch
      records_to_translate = SiteSetting.automatic_translation_backfill_rate
      backfill_locales.each_with_index do |target_locale, i|
        topic_ids =
          fetch_untranslated_model_ids(Topic, "title", records_to_translate, target_locale)
        post_ids = fetch_untranslated_model_ids(Post, "raw", records_to_translate, target_locale)

        next if topic_ids.empty? && post_ids.empty?

        DiscourseTranslator::VerboseLogger.log(
          "Translating #{topic_ids.size} topics and #{post_ids.size} posts to #{target_locale}",
        )

        translate_records(Topic, topic_ids, target_locale)
        translate_records(Post, post_ids, target_locale)
      end
    end

    def max_age_clause
      return "" if SiteSetting.automatic_translation_backfill_max_age_days <= 0

      "AND m.created_at > NOW() - INTERVAL '#{SiteSetting.automatic_translation_backfill_max_age_days} days'"
    end

    def limit_to_public_clause(model)
      return "" if !SiteSetting.automatic_translation_backfill_limit_to_public_content

      public_categories = Category.where(read_restricted: false).pluck(:id).join(", ")
      if model == Post
        limit_to_public_clause = <<~SQL
          INNER JOIN topics t
          ON m.topic_id = t.id
          AND t.archetype = 'regular'
          AND t.category_id IN (#{public_categories})
        SQL
      elsif model == Topic
        limit_to_public_clause = <<~SQL
          INNER JOIN categories c
          ON m.category_id = c.id
          AND c.id IN (#{public_categories})
        SQL
      end

      limit_to_public_clause
    end
  end
end
