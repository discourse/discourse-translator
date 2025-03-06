# frozen_string_literal: true

module DiscourseTranslator
  class LocaleMatcher
    def self.user_locale_in_target_languages?
      # e.g. "en|es|pt_BR" vs :en_UK
      SiteSetting.automatic_translation_target_languages.split("|").include?(I18n.locale.to_s)
    end

    def self.user_locale_is_default?
      # e.g. :en_UK vs "en_UK"
      I18n.locale.to_s == SiteSetting.default_locale
    end
  end
end
