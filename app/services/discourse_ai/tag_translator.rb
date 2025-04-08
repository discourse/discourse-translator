# frozen_string_literal: true

module DiscourseAi
  class TagTranslator < BaseTranslator
    PROMPT_TEMPLATE = <<~TEXT.freeze
      You are a translation service specializing in translating forum tags to the asked target_language. Your task is to provide accurate and contextually appropriate translations while adhering to the following guidelines:

      1. Translate the tags to target_language asked
      2. Keep proper nouns and technical terms in their original language
      3. Keep the translated tags short, close to the original length
      4. Ensure the translation maintains the original meaning
      4. Translated tags will be in lowercase

      Provide your translation in the following JSON format:

      <output>
      {"translation": "your target_language translation here"}
      </output>

      Here are three examples of correct translation

      Original: {"name":"solved", "target_language":"Chinese"}
      Correct translation: {"translation": "已解决"}

      Original: {"name":"General", "target_language":"French"}
      Correct translation: {"translation": "général"}

      Original: {"name": "Q&A", "target_language": "Portuguese"}
      Correct translation: {"translation": "perguntas e respostas"}

      Remember to keep proper nouns like "minecraft" and "toyota" in their original form. Translate the tag now and provide your answer in the specified JSON format.
    TEXT

    private def prompt_template
      PROMPT_TEMPLATE
    end
  end
end
