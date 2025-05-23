# frozen_string_literal: true

class CleanupAmazonTranslations < ActiveRecord::Migration[7.2]
  def up
    provider =
      DB.query_single("SELECT value FROM site_settings WHERE name = 'translator_provider'").first
    if provider == "Amazon"
      execute <<~SQL
        DELETE FROM discourse_translator_post_translations
        WHERE translation LIKE '{:translated_text%'
      SQL

      execute <<~SQL
        DELETE FROM discourse_translator_topic_translations
        WHERE translation LIKE '{:translated_text%'
      SQL
    end
  end

  def down
  end
end
