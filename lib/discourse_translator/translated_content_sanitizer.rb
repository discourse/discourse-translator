# frozen_string_literal: true

module DiscourseTranslator
  class TranslatedContentSanitizer
    def self.sanitize(model, content)
      case model.to_s
      when "Topic"
        return ERB::Util.html_escape(content) unless SiteSetting.title_fancy_entities?
        Topic.fancy_title(content)
      when "Post"
        PrettyText.cleanup(content, {})
      else
        # raise an error if the model is not supported
        raise ArgumentError.new("Model not supported")
      end
    end
  end
end
