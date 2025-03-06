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
    it "creates the correct prompt" do
      allow(DiscourseAi::Completions::Prompt).to receive(:new).with(
        DiscourseAi::LanguageDetector::PROMPT_TEXT,
        messages: [{ type: :user, content: "meow", id: "user" }],
      ).and_call_original

      described_class.new("meow").detect
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
      )

      described_class.new("meow").detect
    end

    it "returns the language from the llm's response in the language tag" do
      DiscourseAi::Completions::Llm.with_prepared_responses(["de"]) do
        expect(described_class.new("meow").detect).to eq "de"
      end
    end
  end
end
