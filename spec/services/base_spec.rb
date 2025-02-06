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

    it "strips @ mention anchor tags" do
      post.cooked = "<a class='mention' href='/u/cat' >cat</a>"
      expect(DiscourseTranslator::Base.text_for_detection(post)).to eq("")
    end

    it "strips lightbox anchor tags" do
      post.cooked = "<a class='lightbox' href='http://cloudfront.net/image.png' />"
      expect(DiscourseTranslator::Base.text_for_detection(post)).to eq("")
    end

    it "strips lightboxes" do
      post.cooked = "<div class='lightbox-wrapper' />"
      expect(DiscourseTranslator::Base.text_for_detection(post)).to eq("")
    end

    it "strips quotes" do
      post.cooked = "<aside class='quote'>多言語トピック</aside>"
      expect(DiscourseTranslator::Base.text_for_detection(post)).to eq("")
    end

    it "leaves other anchor tags alone" do
      cooked = <<~HTML
        <p>
          <a href="http://cat.com/image.png"></a>
          <a class="derp" href="http://cat.com/image.png"></a>
        </p>
      HTML
      post.cooked = cooked
      expect(DiscourseTranslator::Base.text_for_detection(post)).to eq(cooked)
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

    it "strips text before truncation" do
      post.cooked = "<img src='http://example.com/image.png' />" + "a" * 1000
      expect(DiscourseTranslator::Base.text_for_detection(post)).to eq("a" * 1000)
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

  describe ".detect" do
    fab!(:post)

    it "returns nil when text is blank" do
      post.cooked = ""
      expect(TestTranslator.detect(post)).to be_nil
    end

    it "returns cached detection if available" do
      TestTranslator.save_detected_locale(post) { "en" }

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

    it "returns nil when text is blank" do
      post.cooked = ""
      expect(TestTranslator.translate(post)).to be_nil
    end

    it "returns original text when detected language matches current locale" do
      TestTranslator.save_detected_locale(post) { I18n.locale.to_s }
      post.cooked = "hello"

      expect(TestTranslator.translate(post)).to eq(%w[en hello])
    end

    it "returns cached translation if available" do
      TestTranslator.save_detected_locale(post) { "es" }
      TestTranslator.save_translation(post) { "hello" }

      expect(TestTranslator.translate(post)).to eq(%w[es hello])
    end

    it "raises error when translation not supported" do
      TestTranslator.save_detected_locale(post) { "xx" }
      TestTranslator.expects(:translate_supported?).with("xx", :en).returns(false)

      expect { TestTranslator.translate(post) }.to raise_error(DiscourseTranslator::TranslatorError)
    end

    it "performs translation when needed" do
      TestTranslator.save_detected_locale(post) { "es" }
      TestTranslator.expects(:translate!).returns("hello")

      expect(TestTranslator.translate(post)).to eq(%w[es hello])
    end
  end
end
