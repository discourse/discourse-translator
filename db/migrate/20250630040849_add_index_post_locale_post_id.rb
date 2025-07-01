# frozen_string_literal: true

class AddIndexPostLocalePostId < ActiveRecord::Migration[7.2]
  disable_ddl_transaction!

  def up
    # clean up invalid index if index creation timeout
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
