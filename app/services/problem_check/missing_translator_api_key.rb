# frozen_string_literal: true

class ProblemCheck::MissingTranslatorApiKey < ProblemCheck
  self.priority = "high"

  def call
    return no_problem unless SiteSetting.translator_enabled
    name = api_key_site_setting_name
    return no_problem if name.nil?
    return problem if SiteSetting.get(name).blank?

    no_problem
  end

  private

  def translation_data
    { provider: SiteSetting.translator, key: I18n.t("site_settings.#{api_key_site_setting_name}") }
  end

  def api_key_site_setting_name
    case SiteSetting.translator
    when "Google"
      "translator_google_api_key"
    when "Microsoft"
      "translator_azure_subscription_key"
    end
  end
end
