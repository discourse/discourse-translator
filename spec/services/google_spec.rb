# frozen_string_literal: true

require "rails_helper"

RSpec.describe DiscourseTranslator::Provider::Google do
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

  describe ".translate_translatable!" do
    let(:post) { Fabricate(:post) }

    it "raises an error and warns admin on failure" do
      described_class.expects(:access_token).returns(api_key)
      described_class.expects(:detect).returns("__")

      stub_request(:post, DiscourseTranslator::Provider::Google::SUPPORT_URI).to_return(
        status: 400,
        body: {
          error: {
            code: "400",
            message: "API key not valid. Please pass a valid API key.",
          },
        }.to_json,
      )

      ProblemCheckTracker[:translator_error].no_problem!

      expect { described_class.translate(post) }.to raise_error(
        DiscourseTranslator::Provider::ProblemCheckedTranslationError,
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

      expect {
        described_class.translate(post)
      }.to raise_error DiscourseTranslator::Provider::TranslatorError
    end

    it "returns error with source and target locale when translation is not supported" do
      post.set_detected_locale("cat")
      I18n.stubs(:locale).returns(:dog)

      Excon.expects(:post).returns(
        mock_response.new(200, %{ { "data": { "languages": [ { "language": "kit" }] } } }),
      )

      expect { described_class.translate(post) }.to raise_error(
        I18n.t("translator.failed.post", source_locale: "cat", target_locale: "dog"),
      )
    end

    it "truncates text for translation to max_characters_per_translation setting" do
      SiteSetting.max_characters_per_translation = 50
      post.cooked = "a" * 100
      post.set_detected_locale("de")
      body = {
        q: post.cooked.truncate(SiteSetting.max_characters_per_translation, omission: nil),
        target: "en",
        key: api_key,
      }

      translated_text = "hur dur hur dur"
      stub_request(:post, DiscourseTranslator::Provider::Google::SUPPORT_URI).to_return(
        status: 200,
        body: %{ { "data": { "languages": [ { "language": "de" }] } } },
      )
      stub_request(:post, DiscourseTranslator::Provider::Google::TRANSLATE_URI).with(
        body: URI.encode_www_form(body),
        headers: {
          "Content-Type" => "application/x-www-form-urlencoded",
          "Referer" => "http://test.localhost",
        },
      ).to_return(
        status: 200,
        body: %{ { "data": { "translations": [ { "translatedText": "#{translated_text}" } ] } } },
      )

      expect(described_class.translate_translatable!(post)).to eq(translated_text)
    end
  end

  describe ".translate_text!" do
    it "translates plain text" do
      text = "ABCDEFG"
      body = { q: text, target: "ja", key: api_key }

      translated_text = "hur dur hur dur"
      stub_request(:post, DiscourseTranslator::Provider::Google::TRANSLATE_URI).with(
        body: URI.encode_www_form(body),
        headers: {
          "Content-Type" => "application/x-www-form-urlencoded",
          "Referer" => "http://test.localhost",
        },
      ).to_return(
        status: 200,
        body: %{ { "data": { "translations": [ { "translatedText": "#{translated_text}" } ] } } },
      )

      expect(described_class.translate_text!(text, :ja)).to eq(translated_text)
    end
  end
end
