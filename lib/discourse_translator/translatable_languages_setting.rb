# frozen_string_literal: true

module DiscourseTranslator
  class TranslatableLanguagesSetting < LocaleSiteSetting
    def self.printable_values
      values.map { |v| v[:value] }
    end

    @lock = Mutex.new
  end
end
