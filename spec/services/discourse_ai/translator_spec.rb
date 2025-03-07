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
      You are an expert translator specializing in converting Markdown content from any source language to target locale "de". Your task is to:
      1. Translate the content accurately while preserving all Markdown formatting elements
      2. Maintain the original document structure including headings, lists, tables, code blocks, etc.
      3. Preserve all links, images, and other media references without translation
      4. Handle code snippets appropriately - don't translate variable names, functions, or syntax within code blocks (```), but translate comments
      5. When encountering technical terminology, provide the accepted target language term if it exists, or transliterate if no equivalent exists, with the original term in parentheses
      6. For ambiguous terms or phrases, choose the most contextually appropriate translation
      7. You are being consumed via an API, only EVER return the translated text, do not return any other information
        TEXT
        messages: [{ type: :user, content: "cats are great", id: "user" }],
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

    it "returns the translation from the llm's response" do
      DiscourseAi::Completions::Llm.with_prepared_responses(["hur dur hur dur!"]) do
        expect(
          described_class.new(text_to_translate, target_language).translate,
        ).to eq "hur dur hur dur!"
      end
    end
  end
end
