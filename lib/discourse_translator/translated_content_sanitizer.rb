# frozen_string_literal: true

module DiscourseTranslator
  class TranslatedContentSanitizer
    def self.sanitize(content)
      PrettyText.cleanup(content, {})
    end
  end
end
