# frozen_string_literal: true

require "rails_helper"

describe DiscourseTranslator::DiscourseAi do
  fab!(:post)

  before do
    Fabricate(:fake_model).tap do |fake_llm|
      SiteSetting.public_send("ai_helper_model=", "custom:#{fake_llm.id}")
    end
    SiteSetting.ai_helper_enabled = true
    SiteSetting.translator_enabled = true
    SiteSetting.translator = "DiscourseAi"
  end

  describe ".language_supported?" do
    it "returns true for any language" do
      expect(described_class.language_supported?("any-language")).to eq(true)
    end
  end

  describe ".detect" do
    it "stores the detected language in a custom field" do
      locale = "de"
      DiscourseAi::Completions::Llm.with_prepared_responses(["<language>de</language>"]) do
        DiscourseTranslator::DiscourseAi.detect(post)
        post.save_custom_fields
      end

      expect(post.custom_fields[DiscourseTranslator::DETECTED_LANG_CUSTOM_FIELD]).to eq locale
    end
  end

  describe ".translate" do
    before do
      post.custom_fields[DiscourseTranslator::DETECTED_LANG_CUSTOM_FIELD] = "de"
      post.save_custom_fields
    end

    it "translates the post and returns [locale, translated_text]" do
      DiscourseAi::Completions::Llm.with_prepared_responses(
        ["<translation>some translated text</translation>"],
      ) do
        locale, translated_text = DiscourseTranslator::DiscourseAi.translate(post)
        expect(locale).to eq "de"
        expect(translated_text).to eq "some translated text"
      end
    end
  end
end
