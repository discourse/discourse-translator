# frozen_string_literal: true

module DiscourseAi
  class LanguageDetector
    PROMPT_TEXT = <<~TEXT
      I want you to act as a language expert, determining the locale for a set of text.
      The locale is a language identifier, such as "en" for English, "de" for German, etc,
      and can also include a region identifier, such as "en-GB" for British English, or "zh-Hans" for Simplified Chinese.
      I will provide you with text, and you will determine the locale of the text.
      Include your locale between <language></language> XML tags.
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

      response =
        DiscourseAi::Completions::Llm.proxy(SiteSetting.ai_helper_model).generate(
          prompt,
          user: Discourse.system_user,
          feature_name: "translator-language-detect",
        )

      (Nokogiri::HTML5.fragment(response).at("language")&.text || response)
    end
  end
end
