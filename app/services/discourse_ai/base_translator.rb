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
          prompt_template,
          messages: [{ type: :user, content: formatted_content, id: "user" }],
        )

      response =
        DiscourseAi::Completions::Llm.proxy(SiteSetting.ai_helper_model).generate(
          prompt,
          user: Discourse.system_user,
          feature_name: "translator-translate",
          extra_model_params: response_format,
        )

      JSON.parse(response)&.dig("translation")
    end

    def formatted_content
      { content: @text, target_language: @target_language }.to_json
    end

    def response_format
      {
        response_format: {
          type: "json_schema",
          json_schema: {
            name: "reply",
            schema: {
              type: "object",
              properties: {
                translation: {
                  type: "string",
                },
              },
              required: ["translation"],
              additionalProperties: false,
            },
            strict: true,
          },
        },
      }
    end

    private

    def prompt_template
      raise NotImplementedError
    end
  end
end
