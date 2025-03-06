# frozen_string_literal: true

module DiscourseAi
  class LanguageDetector
    PROMPT_TEXT = <<~TEXT
      You are a language expert. Determine the locale for a set of text.
      - the locale is a language identifier, such as "en" for English, "de" for German, etc
      - it may include a region identifier, such as "en-GB" for British English, or "zh-CN" for Simplified Chinese
      - only return the locale
      - do not write explanations
    TEXT

    def initialize(text)
      @text = text
    end

    def detect
      prompt =
        DiscourseAi::Completions::Prompt.new(
          PROMPT_TEXT,
          messages: [{ type: :user, content: @text, id: "user" }],
        )

      locale =
        DiscourseAi::Completions::Llm.proxy(SiteSetting.ai_helper_model).generate(
          prompt,
          user: Discourse.system_user,
          feature_name: "translator-language-detect",
        )
      locale.strip
    end
  end
end
