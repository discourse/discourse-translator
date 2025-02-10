# frozen_string_literal: true

class MoveTranslationsCustomFieldsToTable < ActiveRecord::Migration[7.2]
  BATCH_SIZE = 1000

  def up
    migrate_custom_fields("topic")
    migrate_custom_fields("post")
  end

  def down
    execute "TRUNCATE discourse_translator_topic_locales"
    execute "TRUNCATE discourse_translator_topic_translations"
    execute "TRUNCATE discourse_translator_post_locales"
    execute "TRUNCATE discourse_translator_post_translations"
  end

  private

  def migrate_custom_fields(model)
    bounds = DB.query_single(<<~SQL, model:)
      SELECT
        COALESCE(MIN(id), 0) as min_id,
        COALESCE(MAX(id), 0) as max_id
      FROM #{model}_custom_fields
      WHERE name IN ('post_detected_lang', 'translated_text')
    SQL

    start_id = bounds[0]
    max_id = bounds[1]

    while start_id < max_id
      DB.exec(<<~SQL, model:, start_id:, end_id: start_id + BATCH_SIZE)
        WITH to_detect AS (
          SELECT #{model}_id, value
          FROM #{model}_custom_fields
          WHERE name = 'post_detected_lang'
          AND length(value) <= 20
          AND id >= :start_id
          AND id < :end_id
          ORDER BY id
        ),
        do_detect AS (
          INSERT INTO discourse_translator_#{model}_locales (#{model}_id, detected_locale, created_at, updated_at)
          SELECT #{model}_id, value, NOW(), NOW()
          FROM to_detect
        ),
        to_translate AS (
          SELECT #{model}_id, value::jsonb, created_at, updated_at
          FROM #{model}_custom_fields
          WHERE name = 'translated_text'
          AND value LIKE '{%}'
          AND id >= :start_id
          AND id < :end_id
          ORDER BY id
        ),
        do_translate AS (
          INSERT INTO discourse_translator_#{model}_translations (#{model}_id, locale, translation, created_at, updated_at)
          SELECT b.#{model}_id, jb.key as locale, jb.value as translation, b.created_at, b.updated_at
          FROM to_translate b, jsonb_each_text(b.value) jb
          WHERE LENGTH(jb.key) <= 20
        )
        SELECT 1
      SQL
      start_id += BATCH_SIZE
    end
  end
end
