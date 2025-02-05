# frozen_string_literal: true

class MoveTranslationsCustomFieldsToTable < ActiveRecord::Migration[7.2] # frozen_string_literal: true
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
    start_id = 0
    loop do
      last_id = DB.query_single(<<~SQL, model:, start_id:, limit: BATCH_SIZE)
        WITH to_insert AS (
          SELECT id, #{model}_id, value
          FROM #{model}_custom_fields
          WHERE name = 'post_detected_lang'
          AND id > :start_id
          ORDER BY id
          LIMIT :limit
        ),
        do_insert AS (
          INSERT INTO discourse_translator_#{model}_locales (#{model}_id, detected_locale, created_at, updated_at)
          SELECT #{model}_id, value, NOW(), NOW()
          FROM to_insert
        ),
        to_translate AS (
          SELECT id, #{model}_id, value::jsonb, created_at, updated_at
          FROM #{model}_custom_fields
          WHERE id > :start_id
          AND name = 'translated_text'
          AND value LIKE '{%}'
          ORDER BY id
          LIMIT :limit
        ),
        do_translate AS (
          INSERT INTO discourse_translator_#{model}_translations (#{model}_id, locale, translation, created_at, updated_at)
          SELECT b.#{model}_id, jb.key as locale, jb.value as translation, b.created_at, b.updated_at
          FROM to_translate b, jsonb_each_text(b.value) jb
          WHERE LENGTH(jb.key) <= 20
        ),
        max_value AS (SELECT COALESCE(GREATEST((SELECT MAX(id) FROM to_insert), (SELECT MAX(id) FROM to_translate) ), -1) as max_id)
        SELECT max_id FROM max_value
      SQL
      start_id = last_id.last
      break if start_id == -1
    end
  end
end
