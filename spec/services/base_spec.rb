# frozen_string_literal: true

require "rails_helper"

describe DiscourseTranslator::Base do
  class TestTranslator < DiscourseTranslator::Base
    SUPPORTED_LANG_MAPPING = { en: "en", ar: "ar", es_MX: "es-MX", pt: "pt" }
  end

  class EmptyTranslator < DiscourseTranslator::Base
  end

  describe ".language_supported?" do
    it "raises an error when the method is not implemented" do
      expect { EmptyTranslator.language_supported?("en") }.to raise_error(NotImplementedError)
    end

    it "returns false when the locale is not supported" do
      I18n.stubs(:locale).returns(:xx)
      expect(TestTranslator.language_supported?("en")).to eq(false)
    end

    it "returns true when the detected language is not the current locale" do
      I18n.locale = :pt
      expect(TestTranslator.language_supported?("en")).to eq(true)
      expect(TestTranslator.language_supported?("ar")).to eq(true)
      expect(TestTranslator.language_supported?("es-MX")).to eq(true)
    end

    it "returns false when the detected language is the detected locale" do
      I18n.locale = :pt
      expect(TestTranslator.language_supported?("pt")).to eq(false)
    end
  end

  describe ".text_for_detection" do
    fab!(:post)

    it "strips img tags" do
      post.cooked = "<img src='http://example.com/image.png' />"
      expect(DiscourseTranslator::Base.text_for_detection(post)).to eq("")
    end

    it "strips anchor tags" do
      post.cooked = "<a href='http://cat.com/image.png' />"
      expect(DiscourseTranslator::Base.text_for_detection(post)).to eq("")
    end

    it "truncates to DETECTION_CHAR_LIMIT of 1000" do
      post.cooked = "a" * 1001
      expect(DiscourseTranslator::Base.text_for_detection(post).length).to eq(1000)
    end

    it "returns the text if it's less than DETECTION_CHAR_LIMIT" do
      text = "a" * 999
      post.cooked = text
      expect(DiscourseTranslator::Base.text_for_detection(post)).to eq(text)
    end
  end

  describe ".text_for_translation" do
    fab!(:post)

    it "truncates to max_characters_per_translation" do
      post.cooked = "a" * (SiteSetting.max_characters_per_translation + 1)
      expect(DiscourseTranslator::Base.text_for_translation(post).length).to eq(
        SiteSetting.max_characters_per_translation,
      )
    end
  end
end
