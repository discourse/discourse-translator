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
    SiteSetting.translator_provider = "DiscourseAi"
  end

  describe ".language_supported?" do
    it "returns true when detected language is different from i18n locale" do
      I18n.stubs(:locale).returns(:xx)
      expect(described_class.language_supported?("any-language")).to eq(true)
    end

    it "returns false when detected language is same base language as i18n locale" do
      I18n.stubs(:locale).returns(:en_GB)
      expect(described_class.language_supported?("en")).to eq(false)
    end
  end

  describe ".detect!" do
    it "stores the detected language" do
      locale = "de"
      DiscourseAi::Completions::Llm.with_prepared_responses(["<language>de</language>"]) do
        DiscourseTranslator::DiscourseAi.detect!(post)
      end

      expect(post.detected_locale).to eq locale
    end
  end

  describe ".translate" do
    before { post.set_detected_locale("de") }

    it "translates the post and returns [locale, translated_text]" do
      DiscourseAi::Completions::Llm.with_prepared_responses(
        ["<output>some translated text</output>"],
      ) do
        locale, translated_text = DiscourseTranslator::DiscourseAi.translate(post)
        expect(locale).to eq "de"
        expect(translated_text).to eq "some translated text"
      end
    end
  end
end
