# frozen_string_literal: true

class CleanupAiTranslations < ActiveRecord::Migration[7.2]
  def up
    execute <<~SQL
      DELETE FROM discourse_translator_topic_translations
      WHERE translation LIKE 'To%'
      AND translation ILIKE '%translat%'
      AND LENGTH(translation) > 100;
    SQL
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
