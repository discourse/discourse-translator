# frozen_string_literal: true

module DiscourseAi
  class Translator
    PROMPT_TEMPLATE = <<~TEXT.freeze
      You are a highly skilled linguist and web programmer, with expertise in many languages, and very well versed in HTML.
      Your task is to identify the language of the text I provide and accurately translate it into this language locale "%{target_language}" while preserving the meaning, tone, and nuance of the original text.
      The text will contain html tags, which must absolutely be preserved in the translation.
      Maintain proper grammar, spelling, and punctuation in the translated version.
      Wrap the translated text in a <translation> tag.
    TEXT

    def initialize(text, target_language)
      @text = text
      @target_language = target_language
    end

    def translate
      prompt =
        DiscourseAi::Completions::Prompt.new(
          build_prompt(@target_language),
          messages: [{ type: :user, content: @text, id: "user" }],
        )

      llm_translation =
        DiscourseAi::Completions::Llm.proxy(SiteSetting.ai_helper_model).generate(
          prompt,
          user: Discourse.system_user,
          feature_name: "translator-translate",
        )

      (Nokogiri::HTML5.fragment(llm_translation).at("translation")&.inner_html || llm_translation)
    end

    private

    def build_prompt(target_language)
      PROMPT_TEMPLATE % { target_language: target_language }
    end
  end
end
