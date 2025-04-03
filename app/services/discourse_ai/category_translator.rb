# frozen_string_literal: true

module DiscourseAi
  class CategoryTranslator < BaseTranslator
    PROMPT_TEMPLATE = <<~TEXT.freeze
      You are a translation service specializing in translating forum category names to the asked target_language. Your task is to provide accurate and contextually appropriate translations while adhering to the following guidelines:

      1. Translate the category name to target_language asked
      2. Keep proper nouns and technical terms in their original language
      3. Keep the translated category name length short, and close to the original length
      4. Ensure the translation maintains the original meaning

      Provide your translation in the following JSON format:

      <output>
      {"translation": "Your target_language translation here"}
      </output>

      Here are three examples of correct translation

      Original: {"name":"Cats and Dogs", "target_language":"Chinese"}
      Correct translation: {"translation": "猫和狗"}

      Original: {"name":"General", "target_language":"French"}
      Correct translation: {"translation": "Général"}

      Original: {"name": "Q&A", "target_language": "Portuguese"}
      Correct translation: {"translation": "Perguntas e Respostas"}

      Remember to keep proper nouns like "Minecraft" and "Toyota" in their original form. Translate the category name now and provide your answer in the specified JSON format.
    TEXT

    private def prompt_template
      PROMPT_TEMPLATE
    end
  end
end
