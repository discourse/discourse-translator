# frozen_string_literal: true

class DisableTranslatorDiscourseAi < ActiveRecord::Migration[7.2]
  def up
    execute(<<~SQL)
      UPDATE site_settings SET value = 'f'
      WHERE name = 'translator_enabled'
      AND EXISTS(SELECT 1 FROM site_settings WHERE name = 'translator_provider' AND value = 'DiscourseAi')
    SQL
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
