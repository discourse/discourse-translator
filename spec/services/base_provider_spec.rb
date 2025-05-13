# frozen_string_literal: true

require "rails_helper"

describe DiscourseTranslator::Provider::BaseProvider do
  class TestTranslator < DiscourseTranslator::Provider::BaseProvider
    SUPPORTED_LANG_MAPPING = { en: "en", ar: "ar", es_MX: "es-MX", pt: "pt" }
  end

  class EmptyTranslator < DiscourseTranslator::Provider::BaseProvider
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
    fab!(:topic) { Fabricate(:topic, title: "it is a fine day") }
    fab!(:post) { Fabricate(:post, topic:) }

    it "truncates to DETECTION_CHAR_LIMIT of 1000" do
      post.raw = "a" * 1001
      expect(DiscourseTranslator::Provider::BaseProvider.text_for_detection(post).length).to eq(
        1000,
      )
    end

    it "returns the text if it's less than DETECTION_CHAR_LIMIT" do
      text = "a" * 999
      post.raw = text
      expect(DiscourseTranslator::Provider::BaseProvider.text_for_detection(post)).to eq(text)
    end

    it "appends some text from the first post for topics" do
      topic.first_post.raw = "a" * 999
      expected = (topic.title + " " + topic.first_post.raw).truncate(1000)
      expect(DiscourseTranslator::Provider::BaseProvider.text_for_detection(topic)).to eq(expected)
    end
  end

  describe ".text_for_translation" do
    fab!(:post)

    it "truncates to max_characters_per_translation" do
      post.cooked = "a" * (SiteSetting.max_characters_per_translation + 1)
      expect(DiscourseTranslator::Provider::BaseProvider.text_for_translation(post).length).to eq(
        SiteSetting.max_characters_per_translation,
      )
    end

    it "uses raw if required" do
      post.raw = "a" * (SiteSetting.max_characters_per_translation + 1)
      expect(
        DiscourseTranslator::Provider::BaseProvider.text_for_translation(post, raw: true).length,
      ).to eq(SiteSetting.max_characters_per_translation)
    end
  end

  describe ".detect" do
    fab!(:post)

    it "returns nil when text is blank" do
      post.raw = ""
      expect(TestTranslator.detect(post)).to be_nil
    end

    it "returns cached detection if available" do
      post.set_detected_locale("en")

      TestTranslator.expects(:detect!).never
      expect(TestTranslator.detect(post)).to eq("en")
    end

    it "performs detection if no cached result" do
      TestTranslator.expects(:detect!).with(post).returns("es")

      expect(TestTranslator.detect(post)).to eq("es")
    end
  end

  describe ".translate" do
    fab!(:post)

    it "returns original text when detected language matches current locale" do
      post.set_detected_locale(I18n.locale.to_s)
      post.cooked = "hello"

      expect(TestTranslator.translate(post)).to eq(%w[en hello])
    end

    it "returns cached translation if available" do
      post.set_detected_locale("es")
      post.set_translation(I18n.locale, "hello")

      expect(TestTranslator.translate(post)).to eq(%w[es hello])
    end

    it "raises error when translation not supported" do
      post.set_detected_locale("xx")
      TestTranslator.expects(:translate_supported?).with("xx", :en).returns(false)

      expect { TestTranslator.translate(post) }.to raise_error(
        DiscourseTranslator::Provider::TranslatorError,
      )
    end
  end
end
