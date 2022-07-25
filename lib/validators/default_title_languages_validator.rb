# frozen_string_literal: true

class DefaultTitleLanguagesValidator
  def initialize(opts = {})
    @opts = opts
  end

  def valid_value?(val)
    languages = val.split('|')
    return true unless languages.any?
    (languages - supported_languages).empty?
  end

  def supported_languages
    DiscourseTranslator.current_service::SUPPORTED_LANG_MAPPING.keys.map(&:to_s)
  end

  def error_message
    I18n.t("site_settings.errors.translator_language_not_supported")
  end
end
