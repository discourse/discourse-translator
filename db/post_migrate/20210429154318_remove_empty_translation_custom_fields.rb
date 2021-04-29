# frozen_string_literal: true

class RemoveEmptyTranslationCustomFields < ActiveRecord::Migration[6.1]
  def up
    execute <<~SQL
      DELETE FROM post_custom_fields
      WHERE name = 'post_detected_lang' AND value IS NULL
    SQL

    execute <<~SQL
      DELETE FROM post_custom_fields
      WHERE name = 'translated_text' AND value = '{}'
    SQL
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
