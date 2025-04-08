# frozen_string_literal: true

module DiscourseTranslator
  class TranslatedContentNormalizer
    def self.normalize(translatable, content)
      case translatable.class.name
      when "Post"
        PrettyText.cook(content)
      when "Topic"
        PrettyText.cleanup(content, {})
      when "Category"
        content
      when "Tag"
        content
      end
    end
  end
end
