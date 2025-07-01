# frozen_string_literal: true

class ClearDupesAddIndexToPostLocale < ActiveRecord::Migration[7.2]
  disable_ddl_transaction!

  def up
    execute <<~SQL
      DELETE FROM discourse_translator_post_locales
      WHERE id IN (
        SELECT id
        FROM (
          SELECT id,
                 ROW_NUMBER() OVER (
                   PARTITION BY post_id
                   ORDER BY created_at DESC, id DESC
                 ) AS rnum
          FROM discourse_translator_post_locales
        ) t
        WHERE t.rnum > 1
      )
    SQL

    execute <<~SQL
      DROP INDEX IF EXISTS index_discourse_translator_post_locales_on_post_id
    SQL

    execute <<~SQL
      CREATE UNIQUE INDEX CONCURRENTLY index_discourse_translator_post_locales_on_post_id
      ON discourse_translator_post_locales (post_id)
    SQL
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
