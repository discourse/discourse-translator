# frozen_string_literal: true

RSpec.describe DiscourseTranslator::Provider::Yandex do
  fab!(:post)

  def detect_endpoint(text)
    described_class.expects(:access_token).returns("12345")
    URI(described_class::DETECT_URI)
      .tap { |uri| uri.query = URI.encode_www_form({ "key" => "12345", "text" => text }) }
      .to_s
  end

  def translate_endpoint(text, source_lang, target_lang)
    described_class.expects(:access_token).returns("12345")
    URI(described_class::TRANSLATE_URI)
      .tap do |uri|
        uri.query =
          URI.encode_www_form(
            {
              "key" => "12345",
              "text" => text,
              "lang" => "#{source_lang}-#{target_lang}",
              "format" => "html",
            },
          )
      end
      .to_s
  end

  describe ".access_token" do
    describe "when set" do
      api_key = "12345"
      before { SiteSetting.translator_yandex_api_key = api_key }

      it "should return back translator_yandex_api_key" do
        expect(described_class.access_token).to eq(api_key)
      end
    end
  end

  describe ".detect!" do
    it "gets the detected language" do
      detected_lang = "en"
      stub_request(:post, detect_endpoint(post.raw)).to_return(
        status: 200,
        body: { lang: "#{detected_lang}" }.to_json,
      )
      expect(described_class.detect!(post)).to eq(detected_lang)
    end
  end

  describe ".translate_post" do
    it "translates the post" do
      translated_text = "translated text"
      described_class.expects(:detect).at_least_once.returns("de")

      stub_request(:post, translate_endpoint(post.raw, "de", I18n.locale)).to_return(
        status: 200,
        body: { "text" => [translated_text] }.to_json,
      )

      translation = described_class.translate_post!(post)
      expect(translation).to eq(translated_text)
    end
  end
end
