# frozen_string_literal: true

module DiscourseTranslator
  module Validators
    class TranslatableLanguagesValidator
      def initialize(opts = {})
        @opts = opts
      end

      def valid_value?(val)
        return true if val.blank?

        SiteSetting.automatic_translation_backfill_maximum_translations_per_hour > 0
      end

      def error_message
        I18n.t("site_settings.errors.needs_nonzero_backfill")
      end
    end
  end
end
