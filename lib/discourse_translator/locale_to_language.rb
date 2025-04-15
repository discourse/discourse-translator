# frozen_string_literal: true

module DiscourseTranslator
  class LocaleToLanguage
    def self.get_language(locale)
      LocaleSiteSetting.values.find { |v| v[:value] == locale.to_s.sub("-", "_") }&.[](:name)
    end
  end
end
