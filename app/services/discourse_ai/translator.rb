# frozen_string_literal: true

module DiscourseAi
  class Translator
    PROMPT_TEMPLATE = <<~TEXT.freeze
      You are an expert translator specializing in converting Markdown content from any source language to target locale "%{target_language}". Your task is to:
      1. Translate the content accurately while preserving all Markdown formatting elements
      2. Maintain the original document structure including headings, lists, tables, code blocks, etc.
      3. Preserve all links, images, and other media references without translation
      4. Handle code snippets appropriately - don't translate variable names, functions, or syntax within code blocks (```), but translate comments
      5. When encountering technical terminology, provide the accepted target language term if it exists, or transliterate if no equivalent exists, with the original term in parentheses
      6. For ambiguous terms or phrases, choose the most contextually appropriate translation
      7. You are being consumed via an API, only EVER return the translated text, do not return any other information
    TEXT

    def initialize(text, target_language)
      @text = text
      @target_language = target_language
    end

    def translate
      prompt =
        DiscourseAi::Completions::Prompt.new(
          build_prompt(@target_language),
          messages: [{ type: :user, content: "#{@text}", id: "user" }],
        )

      DiscourseAi::Completions::Llm.proxy(SiteSetting.ai_helper_model).generate(
        prompt,
        user: Discourse.system_user,
        feature_name: "translator-translate",
      )
    end

    private

    def build_prompt(target_language)
      PROMPT_TEMPLATE % { target_language: target_language }
    end
  end
end
