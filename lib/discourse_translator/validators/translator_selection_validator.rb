# frozen_string_literal: true

module DiscourseTranslator
  module Validators
    class TranslatorSelectionValidator
      def initialize(opts = {})
        @opts = opts
      end

      def valid_value?(val)
        return true if val.blank?

        if val == "DiscourseAi"
          return false if !defined?(::DiscourseAi)
          return false if !SiteSetting.ai_helper_enabled
        end

        true
      end

      def error_message
        return I18n.t("translator.discourse_ai.not_installed") if !defined?(::DiscourseAi)

        if !SiteSetting.ai_helper_enabled
          I18n.t("translator.discourse_ai.ai_helper_required", { base_url: Discourse.base_url })
        end
      end
    end
  end
end
