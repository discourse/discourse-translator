# frozen_string_literal: true

require "rails_helper"

describe DiscourseAi::Translator do
  before do
    Fabricate(:fake_model).tap do |fake_llm|
      SiteSetting.public_send("ai_helper_model=", "custom:#{fake_llm.id}")
    end
    SiteSetting.ai_helper_enabled = true
  end

  describe ".translate" do
    let(:text_to_translate) { "cats are great" }
    let(:target_language) { "de" }

    it "creates the correct prompt" do
      allow(DiscourseAi::Completions::Prompt).to receive(:new).with(
        <<~TEXT,
          You are a highly skilled linguist of many languages and have expert knowledge in HTML.
          Your task is to identify the language of the text I provide and accurately translate it into this language locale "de" while preserving the meaning, tone, and nuance of the original text.
          The text may or may not contain html tags. If they do, preserve them.
          Maintain proper grammar, spelling, and punctuation in the translated version.
          You will find the text between <input></input> XML tags.
          Include your translation between <output></output> XML tags.
          Do not write explanations.
        TEXT
        messages: [{ type: :user, content: "<input>cats are great</input>", id: "user" }],
      ).and_call_original

      described_class.new(text_to_translate, target_language).translate
    end

    it "sends the translation prompt to the selected ai helper model" do
      mock_prompt = instance_double(DiscourseAi::Completions::Prompt)
      mock_llm = instance_double(DiscourseAi::Completions::Llm)

      allow(DiscourseAi::Completions::Prompt).to receive(:new).and_return(mock_prompt)
      allow(DiscourseAi::Completions::Llm).to receive(:proxy).with(
        SiteSetting.ai_helper_model,
      ).and_return(mock_llm)
      allow(mock_llm).to receive(:generate).with(
        mock_prompt,
        user: Discourse.system_user,
        feature_name: "translator-translate",
      )

      described_class.new(text_to_translate, target_language).translate
    end

    it "returns the translation from the llm's response in the translation tag" do
      DiscourseAi::Completions::Llm.with_prepared_responses(
        ["<output>hur dur hur dur!</output>"],
      ) do
        expect(
          described_class.new(text_to_translate, target_language).translate,
        ).to eq "hur dur hur dur!"
      end
    end

    it "returns an empty string if the translation tag is not present" do
      DiscourseAi::Completions::Llm.with_prepared_responses(["raw response."]) do
        expect(described_class.new(text_to_translate, target_language).translate).to eq ""
      end
    end
  end
end
