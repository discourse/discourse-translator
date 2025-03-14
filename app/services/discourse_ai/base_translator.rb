# frozen_string_literal: true

module DiscourseAi
  class BaseTranslator
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
      prompt_template % { target_language: target_language }
    end

    def prompt_template
      raise NotImplementedError
    end
  end
end
