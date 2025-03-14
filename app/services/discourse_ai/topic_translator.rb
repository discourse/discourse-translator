# frozen_string_literal: true

module DiscourseAi
  class TopicTranslator < BaseTranslator
    PROMPT_TEMPLATE = <<~TEXT.freeze
      Translate this topic title to "%{target_language}"
      - Keep the original language when it is a proper noun or technical term
      - The translation should be around the same length as the original
      TEXT

    private def prompt_template
      PROMPT_TEMPLATE
    end
  end
end
