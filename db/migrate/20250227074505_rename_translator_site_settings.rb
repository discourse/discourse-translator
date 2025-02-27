# frozen_string_literal: true

class RenameTranslatorSiteSettings < ActiveRecord::Migration[7.0]
  def up
    execute <<~SQL
      UPDATE site_settings
      SET name = 'translator_provider'
      WHERE name = 'translator';

      UPDATE site_settings
      SET name = 'experimental_inline_translation'
      WHERE name = 'experimental_topic_translation';
    SQL
  end

  def down
    execute <<~SQL
      UPDATE site_settings
      SET name = 'translator'
      WHERE name = 'translator_provider';

      UPDATE site_settings
      SET name = 'experimental_topic_translation'
      WHERE name = 'experimental_inline_translation';
    SQL
  end
end
