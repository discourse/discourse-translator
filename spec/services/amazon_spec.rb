# frozen_string_literal: true

require "rails_helper"

RSpec.describe DiscourseTranslator::Provider::Amazon do
  let(:mock_response) { Struct.new(:status, :body) }

  describe ".truncate" do
    it "truncates text to 10000 bytes" do
      text = "こんにちは" * (described_class::MAX_BYTES / 5)
      truncated = described_class.truncate(text)

      expect(truncated.bytesize).to be <= described_class::MAX_BYTES
      expect(truncated.valid_encoding?).to eq(true)
      expect(truncated[-1]).to eq "に"
    end
  end

  describe ".detect" do
    let(:post) { Fabricate(:post) }
    let!(:client) { Aws::Translate::Client.new(stub_responses: true) }
    let(:text) { described_class.truncate(post.cooked) }
    let(:detected_lang) { "en" }

    before do
      client.stub_responses(
        :translate_text,
        {
          translated_text: "Probando traducciones",
          source_language_code: "en",
          target_language_code: "es",
        },
      )
      Aws::Translate::Client.stubs(:new).returns(client)
    end

    it "should store the detected language in a custom field" do
      expect(described_class.detect(post)).to eq(detected_lang)

      expect(post.detected_locale).to eq(detected_lang)
    end

    it "should fail graciously when the cooked translated text is blank" do
      post.raw = ""
      expect(described_class.detect(post)).to be_nil
    end
  end

  describe ".translate" do
    let(:post) { Fabricate(:post) }
    let!(:client) { Aws::Translate::Client.new(stub_responses: true) }

    before do
      client.stub_responses(
        :translate_text,
        "UnsupportedLanguagePairException",
        {
          translated_text: "Probando traducciones",
          source_language_code: "en",
          target_language_code: "es",
        },
      )
      described_class.stubs(:client).returns(client)
      post.set_detected_locale("en")
      I18n.stubs(:locale).returns(:es)
    end

    it "raises an error when trying to translate an unsupported language" do
      expect { described_class.translate(post) }.to raise_error(
        I18n.t("translator.failed.post", source_locale: "en", target_locale: "es"),
      )
    end
  end
end
