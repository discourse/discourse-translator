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
    it "returns the detected language" do
      locale = "de"
      DiscourseAi::Completions::Llm.with_prepared_responses(["de"]) do
        expect(DiscourseTranslator::DiscourseAi.detect!(post)).to eq locale
      end
    end
  end

  describe ".translate!" do
    before { post.set_detected_locale("de") }

    it "returns the translated text from the llm" do
      DiscourseAi::Completions::Llm.with_prepared_responses(["some translated text"]) do
        expect(DiscourseTranslator::DiscourseAi.translate!(post)).to eq "some translated text"
      end
    end

    it "sends the content for splitting and the split content for translation" do
      post.update(raw: "#{"a" * 3000} #{"b" * 3000}")
      DiscourseAi::Completions::Llm.with_prepared_responses(%w[lol wut]) do
        expect(DiscourseTranslator::DiscourseAi.translate!(post)).to eq "lolwut"
      end
    end
  end
end
