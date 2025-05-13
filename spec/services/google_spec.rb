# frozen_string_literal: true

describe DiscourseTranslator::Provider::Google do
  let(:api_key) { "12345" }
  let(:mock_response) { Struct.new(:status, :body) }

  before do
    SiteSetting.translator_enabled = true
    SiteSetting.translator_google_api_key = api_key
  end

  def stub_translate_request(text, target_locale, translated_text)
    stub_request(:post, DiscourseTranslator::Provider::Google::TRANSLATE_URI).with(
      body: URI.encode_www_form({ q: text, target: target_locale, key: api_key }),
      headers: {
        "Content-Type" => "application/x-www-form-urlencoded",
        "Referer" => "http://test.localhost",
      },
    ).to_return(
      status: 200,
      body: %{ { "data": { "translations": [ { "translatedText": "#{translated_text}" } ] } } },
    )
  end

  describe ".access_token" do
    describe "when set" do
      it "should return back translator_google_api_key" do
        expect(described_class.access_token).to eq(api_key)
      end
    end
  end

  describe ".detect" do
    fab!(:post)

    it "should store the detected language in a custom field" do
      detected_lang = "en"
      described_class.expects(:access_token).returns(api_key)
      Excon
        .expects(:post)
        .returns(
          mock_response.new(
            200,
            %{ { "data": { "detections": [ [ { "language": "#{detected_lang}", "isReliable": false, "confidence": 0.18397073 } ] ] } } },
          ),
        )
        .once

      expect(described_class.detect(post)).to eq(detected_lang)
      expect(post.detected_locale).to eq(detected_lang)
    end

    it "should truncate string to 1000 characters" do
      length = 2000
      post.raw = rand(36**length).to_s(36)
      detected_lang = "en"

      request_url = "#{DiscourseTranslator::Provider::Google::DETECT_URI}"
      body = {
        q:
          post.raw.truncate(
            DiscourseTranslator::Provider::Google::DETECTION_CHAR_LIMIT,
            omission: nil,
          ),
        key: api_key,
      }

      Excon
        .expects(:post)
        .with(
          request_url,
          body: URI.encode_www_form(body),
          headers: {
            "Content-Type" => "application/x-www-form-urlencoded",
            "Referer" => "http://test.localhost",
          },
        )
        .returns(
          mock_response.new(
            200,
            %{ { "data": { "detections": [ [ { "language": "#{detected_lang}", "isReliable": false, "confidence": 0.18397073 } ] ] } } },
          ),
        )
        .once

      expect(described_class.detect(post)).to eq(detected_lang)
    end
  end

  describe ".translate_supported?" do
    let(:topic) { Fabricate(:topic, title: "This title is in english") }

    it "equates source language to target" do
      source = "en"
      target = "fr"
      stub_request(:post, DiscourseTranslator::Provider::Google::SUPPORT_URI).to_return(
        status: 200,
        body: %{ { "data": { "languages": [ { "language": "#{source}" }] } } },
      )
      expect(described_class.translate_supported?(source, target)).to be true
    end

    it "checks again without -* when the source language is not supported" do
      source = "en"
      target = "fr"
      stub_request(:post, DiscourseTranslator::Provider::Google::SUPPORT_URI).to_return(
        status: 200,
        body: %{ { "data": { "languages": [ { "language": "#{source}" }] } } },
      )

      expect(described_class.translate_supported?("en-GB", target)).to be true
    end
  end

  describe ".translate_post!" do
    fab!(:post) { Fabricate(:post, raw: "rawraw rawrawraw", cooked: "coocoo coococooo") }

    before do
      post.set_detected_locale("en")
      I18n.locale = :de
    end

    it "translates post with raw" do
      translated_text = "translated raw"
      stub_translate_request(post.raw, "de", translated_text)

      expect(described_class.translate_post!(post, :de, { raw: true })).to eq(translated_text)
    end

    it "translates post with cooked" do
      translated_text = "translated cooked"
      stub_translate_request(post.cooked, "de", translated_text)

      expect(described_class.translate_post!(post, :de, { cooked: true })).to eq(translated_text)
    end

    it "translates post with raw when unspecified" do
      translated_text = "translated raw"
      stub_translate_request(post.raw, "de", translated_text)

      expect(described_class.translate_post!(post, :de)).to eq(translated_text)
    end
  end

  describe ".translate_topic!" do
    fab!(:topic)

    before do
      topic.set_detected_locale("en")
      I18n.locale = :de
    end

    it "translates topic's title" do
      translated_text = "translated title"
      stub_translate_request(topic.title, "de", translated_text)

      expect(described_class.translate_topic!(topic, :de)).to eq(translated_text)
    end
  end

  describe ".translate_text!" do
    it "translates plain text" do
      text = "ABCDEFG"
      target_locale = "ja"
      translated_text = "あいうえお"
      stub_translate_request(text, target_locale, translated_text)

      expect(described_class.translate_text!(text, :ja)).to eq(translated_text)
    end
  end
end
