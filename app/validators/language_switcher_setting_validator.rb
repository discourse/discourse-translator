# frozen_string_literal: true

class LanguageSwitcherSettingValidator
  def initialize(opts = {})
    @opts = opts
  end

  def valid_value?(val)
    return true if val == "f"
    SiteSetting.set_locale_from_cookie
  end

  def error_message
    I18n.t("site_settings.errors.set_locale_cookie_requirements")
  end
end
