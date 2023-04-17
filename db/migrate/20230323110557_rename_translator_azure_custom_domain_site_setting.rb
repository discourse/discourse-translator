# frozen_string_literal: true

class RenameTranslatorAzureCustomDomainSiteSetting < ActiveRecord::Migration[7.0]
  def up
    execute "UPDATE site_settings SET name = 'translator_azure_custom_subdomain' WHERE name = 'translator_azure_custom_domain'"
  end

  def down
    execute "UPDATE site_settings SET name = 'translator_azure_custom_domain' WHERE name =  'translator_azure_custom_subdomain'"
  end
end
