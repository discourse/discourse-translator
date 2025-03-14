# frozen_string_literal: true

module DiscourseAi
  class PostTranslator < BaseTranslator
    PROMPT_TEMPLATE = <<~TEXT.freeze
      Translate this content to "%{target_language}". You must:
      1. Translate the content accurately while preserving any Markdown, HTML elements, or newlines
      2. Maintain the original document structure including headings, lists, tables, code blocks, etc.
      3. Preserve all links, images, and other media references without translation
      4. Handle code snippets appropriately - don't translate variable names, functions, or syntax within code blocks (```), but translate comments
      5. When encountering technical terminology, provide the accepted target language term if it exists, or transliterate if no equivalent exists, with the original term in parentheses
      6. For ambiguous terms or phrases, choose the most contextually appropriate translation
      7. Do not add any content besides the translation
      8. The translation must not have other languages other than the original and the target language
      9. You are being consumed via an API, only EVER return the translated text, do not return any other information
    TEXT

    private def prompt_template
      PROMPT_TEMPLATE
    end
  end
end
