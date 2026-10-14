# frozen_string_literal: true

class HyphenateTranslatorLocales < ActiveRecord::Migration[7.2]
  BATCH_SIZE = 1000

  def up
    normalize_table("discourse_translator_topic_translations", "locale")
    normalize_table("discourse_translator_post_translations", "locale")
    normalize_table("discourse_translator_topic_locales", "detected_locale")
    normalize_table("discourse_translator_post_locales", "detected_locale")
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end

  private

  def normalize_table(table_name, column)
    start_id = 0
    loop do
      result = DB.query_single(<<~SQL, start_id: start_id, batch_size: BATCH_SIZE)
        WITH batch AS (
          SELECT id
          FROM #{table_name}
          WHERE #{column} LIKE '%\\_%' ESCAPE '\\'
          AND id > :start_id
          ORDER BY id
          LIMIT :batch_size
        )
        UPDATE #{table_name}
        SET #{column} = REGEXP_REPLACE(#{column}, '_', '-')
        WHERE id IN (SELECT id FROM batch)
        RETURNING id
      SQL

      break if result.empty?
      start_id = result.max
    end
  end
end
