# frozen_string_literal: true

module DiscourseTranslator
  module Validators
    class LanguageSwitcherSettingValidator
      def initialize(opts = {})
        @opts = opts
      end

      def valid_value?(val)
        return true if val == "f" || val == "false"
        SiteSetting.set_locale_from_cookie &&
          SiteSetting.automatic_translation_target_languages.present?
      end

      def error_message
        I18n.t("site_settings.errors.experimental_anon_language_switcher_requirements")
      end
    end
  end
end
