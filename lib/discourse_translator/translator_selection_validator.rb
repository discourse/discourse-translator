# frozen_string_literal: true

module DiscourseTranslator
  class TranslatorSelectionValidator
    def initialize(opts = {})
      @opts = opts
    end

    def valid_value?(val)
      return true if val.blank?

      if val == "DiscourseAi"
        return false if !defined?(DiscourseAutomation)
        return false if !SiteSetting.ai_helper_enabled
      end

      true
    end

    def error_message
      return I18n.t("translator.discourse_ai.not_installed") if !defined?(DiscourseAutomation)

      I18n.t("translator.discourse_ai.ai_helper_required") if !SiteSetting.ai_helper_enabled
    end
  end
end
