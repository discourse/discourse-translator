# frozen_string_literal: true

module DiscourseAi
  class Translator
    PROMPT_TEMPLATE = <<~TEXT.freeze
      You are a highly skilled linguist of many languages and have expert knowledge in HTML.
      Your task is to identify the language of the text I provide and accurately translate it into this language locale "%{target_language}" while preserving the meaning, tone, and nuance of the original text.
      The text may or may not contain html tags. If they do, preserve them.
      Maintain proper grammar, spelling, and punctuation in the translated version.
      You will find the text between <input></input> XML tags.
      Include your translation between <output></output> XML tags.
      Do not write explanations.
    TEXT

    def initialize(text, target_language)
      @text = text
      @target_language = target_language
    end

    def translate
      prompt =
        DiscourseAi::Completions::Prompt.new(
          build_prompt(@target_language),
          messages: [{ type: :user, content: "<input>#{@text}</input>", id: "user" }],
        )

      llm_translation =
        DiscourseAi::Completions::Llm.proxy(SiteSetting.ai_helper_model).generate(
          prompt,
          user: Discourse.system_user,
          feature_name: "translator-translate",
        )

      (Nokogiri::HTML5.fragment(llm_translation).at("output")&.inner_html || "").strip
    end

    private

    def build_prompt(target_language)
      PROMPT_TEMPLATE % { target_language: target_language }
    end
  end
end
