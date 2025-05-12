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
        end

        true
      end

      def error_message
        return I18n.t("translator.discourse_ai.not_installed") if !defined?(::DiscourseAi)
      end
    end
  end
end
