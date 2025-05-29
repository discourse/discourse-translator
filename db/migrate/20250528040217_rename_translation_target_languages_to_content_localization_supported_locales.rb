# frozen_string_literal: true

class RenameTranslationTargetLanguagesToContentLocalizationSupportedLocales < ActiveRecord::Migration[
  7.2
]
  def up
    setting_exists =
      DB.query_single(
        "SELECT 1 FROM site_settings WHERE name = 'experimental_content_localization_supported_locales' LIMIT 1",
      ).present?

    if setting_exists
      execute "DELETE FROM site_settings WHERE name = 'automatic_translation_target_languages'"
    else
      execute "UPDATE site_settings SET name = 'experimental_content_localization_supported_locales' WHERE name = 'automatic_translation_target_languages'"
    end
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
