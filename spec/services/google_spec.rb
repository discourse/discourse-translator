# frozen_string_literal: true

require "rails_helper"

RSpec.describe DiscourseTranslator::Google do
  let(:api_key) { "12345" }
  before do
    SiteSetting.translator_enabled = true
    SiteSetting.translator_google_api_key = api_key
  end
  let(:mock_response) { Struct.new(:status, :body) }

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

      2.times do
        expect(post.custom_fields[::DiscourseTranslator::DETECTED_LANG_CUSTOM_FIELD]).to eq(
          detected_lang,
        )
      end
    end

    it "should truncate string to 1000 characters" do
      length = 2000
      post.cooked = rand(36**length).to_s(36)
      detected_lang = "en"

      request_url = "#{DiscourseTranslator::Google::DETECT_URI}"
      body = {
        q: post.cooked.truncate(DiscourseTranslator::Google::DETECTION_CHAR_LIMIT, omission: nil),
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

    it "strips img tags from detection text" do
      post.cooked = "there are some words <img src='http://example.com/image.jpg'> to be said"
      detected_lang = "en"

      request_url = "#{DiscourseTranslator::Google::DETECT_URI}"
      body = { q: "there are some words  to be said", key: api_key }

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
    it "should equate source language to target" do
      source = "en"
      target = "fr"
      Excon.expects(:post).returns(
        mock_response.new(200, %{ { "data": { "languages": [ { "language": "#{source}" }] } } }),
      )
      expect(described_class.translate_supported?(source, target)).to be true
    end

    it "should pass through strings already in target language" do
      lang = I18n.locale
      described_class.expects(:detect).returns(lang)
      expect(described_class.translate(topic)).to eq([lang, "This title is in english"])
    end
  end

  describe ".translate" do
    let(:post) { Fabricate(:post) }

    it "raise an error and warns admin on failure" do
      described_class.expects(:access_token).returns(api_key)
      described_class.expects(:detect).returns("__")

      Excon.expects(:post).returns(
        mock_response.new(
          400,
          {
            error: {
              code: "400",
              message: "API key not valid. Please pass a valid API key.",
            },
          }.to_json,
        ),
      )

      ProblemCheckTracker[:translator_error].no_problem!

      expect { described_class.translate(post) }.to raise_error(
        DiscourseTranslator::ProblemCheckedTranslationError,
      )

      expect(AdminNotice.problem.last.message).to eq(
        I18n.t(
          "dashboard.problem.translator_error",
          locale: "en",
          provider: "Google",
          code: 400,
          message: "API key not valid. Please pass a valid API key.",
        ),
      )
    end

    it "raises an error when the response is not JSON" do
      described_class.expects(:access_token).returns(api_key)
      described_class.expects(:detect).returns("__")

      Excon.expects(:post).returns(mock_response.new(413, "<html><body>some html</body></html>"))

      expect { described_class.translate(post) }.to raise_error DiscourseTranslator::TranslatorError
    end

    it "truncates text for translation to max_characters_per_translation setting" do
      SiteSetting.max_characters_per_translation = 50
      post.cooked = "a" * 100
      post.custom_fields[DiscourseTranslator::DETECTED_LANG_CUSTOM_FIELD] = "de"
      post.save_custom_fields
      body = {
        q: post.cooked.truncate(SiteSetting.max_characters_per_translation, omission: nil),
        source: "de",
        target: "en",
        key: api_key,
      }

      translated_text = "hur dur hur dur"
      Excon
        .expects(:post)
        .with(
          DiscourseTranslator::Google::TRANSLATE_URI,
          body: URI.encode_www_form(body),
          headers: {
            "Content-Type" => "application/x-www-form-urlencoded",
            "Referer" => "http://test.localhost",
          },
        )
        .returns(
          mock_response.new(
            200,
            %{ { "data": { "translations": [ { "translatedText": "#{translated_text}" } ] } } },
          ),
        )
        .once
      Excon.expects(:post).returns(
        mock_response.new(200, %{ { "data": { "languages": [ { "language": "de" }] } } }),
      )

      expect(described_class.translate(post)).to eq(["de", translated_text])
    end
  end
end
