# frozen_string_literal: true

require "rails_helper"

describe DiscourseAi::BaseTranslator do
  before do
    Fabricate(:fake_model).tap do |fake_llm|
      SiteSetting.public_send("ai_helper_model=", "custom:#{fake_llm.id}")
    end
    SiteSetting.ai_helper_enabled = true
  end

  describe ".translate" do
    let(:text_to_translate) { "cats are great" }
    let(:target_language) { "de" }
    let(:llm_response) { "{\"translation\":\"hur dur hur dur!\"}" }

    it "creates the correct prompt" do
      post_translator = DiscourseAi::PostTranslator.new(text_to_translate, target_language)
      allow(DiscourseAi::Completions::Prompt).to receive(:new).with(
        DiscourseAi::PostTranslator::PROMPT_TEMPLATE,
        messages: [{ type: :user, content: post_translator.formatted_content, id: "user" }],
      ).and_call_original

      DiscourseAi::Completions::Llm.with_prepared_responses([llm_response]) do
        post_translator.translate
      end
    end

    it "sends the translation prompt to the selected ai helper model" do
      mock_prompt = instance_double(DiscourseAi::Completions::Prompt)
      mock_llm = instance_double(DiscourseAi::Completions::Llm)
      post_translator = DiscourseAi::PostTranslator.new(text_to_translate, target_language)

      allow(DiscourseAi::Completions::Prompt).to receive(:new).and_return(mock_prompt)
      allow(DiscourseAi::Completions::Llm).to receive(:proxy).with(
        SiteSetting.ai_helper_model,
      ).and_return(mock_llm)
      allow(mock_llm).to receive(:generate).with(
        mock_prompt,
        user: Discourse.system_user,
        feature_name: "translator-translate",
        extra_model_params: post_translator.response_format,
      ).and_return(llm_response)

      post_translator.translate
    end

    it "returns the translation from the llm's response" do
      DiscourseAi::Completions::Llm.with_prepared_responses([llm_response]) do
        expect(
          DiscourseAi::PostTranslator.new(text_to_translate, target_language).translate,
        ).to eq "hur dur hur dur!"
      end
    end
  end
end
