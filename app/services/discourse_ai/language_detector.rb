# frozen_string_literal: true

module DiscourseAi
  class LanguageDetector
    PROMPT_TEXT = <<~TEXT
      You are a language expert and will determine the locale for user-written content.
      - the locale is a language identifier, such as "en" for English, "de" for German, or "zh-CN" for Simplified Chinese, etc.
      - use the vocabulary and grammar of content to determine the locale
      - do not use links or code to determine the locale
      - do not write explanations
      - only return the locale
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
