# frozen_string_literal: true

module DiscourseTranslator
  module TopicExtension
    extend ActiveSupport::Concern

    prepended { before_update :clear_translations, if: :title_changed? }

    private

    def clear_translations
      return if !SiteSetting.translator_enabled

      self.custom_fields.delete(DiscourseTranslator::DETECTED_LANG_CUSTOM_FIELD)
      self.custom_fields.delete(DiscourseTranslator::TRANSLATED_CUSTOM_FIELD)
    end
  end
end
