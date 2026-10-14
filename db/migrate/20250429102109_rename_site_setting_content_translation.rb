# frozen_string_literal: true

class RenameSiteSettingContentTranslation < ActiveRecord::Migration[7.2]
  def up
    execute <<~SQL
      UPDATE site_settings
      SET name = 'experimental_content_translation'
      WHERE name = 'experimental_category_translation';
    SQL
  end

  def down
    execute <<~SQL
      UPDATE site_settings
      SET name = 'experimental_category_translation'
      WHERE name = 'experimental_content_translation';
    SQL
  end
end
