# frozen_string_literal: true

module DiscourseTranslator
  module PostExtension
    extend ActiveSupport::Concern

    prepended { before_update :clear_translator_custom_fields, if: :raw_changed? }

    private

    def clear_translator_custom_fields
      return if !SiteSetting.translator_enabled

      self.custom_fields.delete(DiscourseTranslator::DETECTED_LANG_CUSTOM_FIELD)
      self.custom_fields.delete(DiscourseTranslator::TRANSLATED_CUSTOM_FIELD)
    end
  end
end
