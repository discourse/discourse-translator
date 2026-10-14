# frozen_string_literal: true

describe DiscourseTranslator::Provider::Amazon do
  def new_translate_client
    client = Aws::Translate::Client.new(stub_responses: true)
    Aws::Translate::Client.stubs(:new).returns(client)
    client
  end

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
    let(:text) { described_class.truncate(post.cooked) }
    let(:detected_lang) { "en" }

    it "should store the detected language" do
      client = new_translate_client
      client.stub_responses(
        :translate_text,
        {
          translated_text: "translated text",
          source_language_code: detected_lang,
          target_language_code: "de",
        },
      )

      expect(described_class.detect(post)).to eq(detected_lang)

      expect(post.detected_locale).to eq(detected_lang)
    end

    it "should fail graciously when the cooked translated text is blank" do
      post.raw = ""
      expect(described_class.detect(post)).to be_nil
    end
  end

  describe ".translate_post!" do
    fab!(:post) { Fabricate(:post, raw: "rawraw rawrawraw", cooked: "coocoo coococooo") }

    before do
      post.set_detected_locale("en")
      I18n.locale = :de
    end

    it "translates post with raw" do
      client = new_translate_client
      client.stub_responses(
        :translate_text,
        {
          translated_text: "translated text",
          source_language_code: "en",
          target_language_code: "de",
        },
      )

      expect(described_class.translate_post!(post, :de, { raw: true })).to eq("translated text")
    end

    it "translates post with cooked" do
      client = new_translate_client
      client.stub_responses(
        :translate_text,
        {
          translated_text: "translated text",
          source_language_code: "en",
          target_language_code: "de",
        },
      )

      expect(described_class.translate_post!(post, :de, { cooked: true })).to eq("translated text")
    end

    it "translates post with raw when unspecified" do
      client = new_translate_client
      client.stub_responses(
        :translate_text,
        {
          translated_text: "translated text",
          source_language_code: "en",
          target_language_code: "de",
        },
      )

      expect(described_class.translate_post!(post, :de)).to eq("translated text")
    end
  end

  describe ".translate_topic!" do
    fab!(:topic)

    before do
      topic.set_detected_locale("en")
      I18n.locale = :de
    end

    it "translates topic's title" do
      client = new_translate_client
      client.stub_responses(
        :translate_text,
        {
          translated_text: "translated text",
          source_language_code: "en",
          target_language_code: "de",
        },
      )

      expect(described_class.translate_topic!(topic, :de)).to eq("translated text")
    end
  end

  describe ".translate_text!" do
    before { I18n.locale = :es }

    it "translates the text" do
      client = new_translate_client
      client.stub_responses(
        :translate_text,
        {
          translated_text: "translated text",
          source_language_code: "en",
          target_language_code: "es",
        },
      )

      expect(described_class.translate_text!("derp")).to eq("translated text")
    end
  end
end
