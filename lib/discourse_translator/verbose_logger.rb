# frozen_string_literal: true

module DiscourseTranslator
  class VerboseLogger
    def self.log(message)
      if SiteSetting.discourse_translator_verbose_logs
        Rails.logger.warn("DiscourseTranslator: #{message}")
      end
    end
  end
end
