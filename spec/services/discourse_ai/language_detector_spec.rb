# frozen_string_literal: true

require "rails_helper"

describe DiscourseAi::LanguageDetector do
  before do
    Fabricate(:fake_model).tap do |fake_llm|
      SiteSetting.public_send("ai_helper_model=", "custom:#{fake_llm.id}")
    end
    SiteSetting.ai_helper_enabled = true
  end

  describe ".detect" do
    let(:locale_detector) { described_class.new("meow") }
    let(:llm_response) { "{\"translation\":\"hur dur hur dur!\"}" }

    it "creates the correct prompt" do
      allow(DiscourseAi::Completions::Prompt).to receive(:new).with(
        DiscourseAi::LanguageDetector::PROMPT_TEXT,
        messages: [{ type: :user, content: "meow", id: "user" }],
      ).and_call_original

      DiscourseAi::Completions::Llm.with_prepared_responses([llm_response]) do
        locale_detector.detect
      end
    end

    it "sends the language detection prompt to the ai helper model" do
      mock_prompt = instance_double(DiscourseAi::Completions::Prompt)
      mock_llm = instance_double(DiscourseAi::Completions::Llm)

      allow(DiscourseAi::Completions::Prompt).to receive(:new).and_return(mock_prompt)
      allow(DiscourseAi::Completions::Llm).to receive(:proxy).with(
        SiteSetting.ai_helper_model,
      ).and_return(mock_llm)
      allow(mock_llm).to receive(:generate).with(
        mock_prompt,
        user: Discourse.system_user,
        feature_name: "translator-language-detect",
        extra_model_params: locale_detector.response_format,
      ).and_return(llm_response)

      locale_detector.detect
    end

    it "returns the language from the llm's response in the language tag" do
      DiscourseAi::Completions::Llm.with_prepared_responses([llm_response]) do
        locale_detector.detect
      end
    end
  end
end
