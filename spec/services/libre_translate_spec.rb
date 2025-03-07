# frozen_string_literal: true

require "rails_helper"

RSpec.describe DiscourseTranslator::LibreTranslate do
  let(:mock_response) { Struct.new(:status, :body) }
  let(:api_key) { "12345" }

  before { SiteSetting.translator_libretranslate_endpoint = "http://localhost:5000" }

  describe ".access_token" do
    describe "when set" do
      api_key = "12345"
      before { SiteSetting.translator_libretranslate_api_key = api_key }
      it "should return back translator_libretranslate_api_key" do
        expect(described_class.access_token).to eq(api_key)
      end
    end
  end

  describe ".translate_supported?" do
    it "should equate source language to target" do
      source = "en"
      target = :fr

      data = [{ code: "en" }, { code: "fr" }]

      Excon.expects(:get).returns(mock_response.new(200, data.to_json))
      expect(described_class.translate_supported?(source, target)).to be true
    end
  end

  describe ".translate" do
    fab!(:post)

    before do
      SiteSetting.translator_libretranslate_api_key = api_key
      Excon
        .expects(:get)
        .with(SiteSetting.translator_libretranslate_endpoint + "/languages")
        .returns(mock_response.new(200, [{ code: "de" }, { code: "en" }].to_json))
    end

    it "truncates text for translation to max_characters_per_translation setting" do
      SiteSetting.max_characters_per_translation = 50
      post.set_detected_locale("de")
      body = { q: post.raw, source: "de", target: "en", format: "html", api_key: api_key }

      translated_text = "hur dur hur dur"
      # https://publicapi.dev/libre-translate-api
      Excon
        .expects(:post)
        .with(
          SiteSetting.translator_libretranslate_endpoint + "/translate",
          body: URI.encode_www_form(body),
          headers: {
            "Content-Type" => "application/x-www-form-urlencoded",
          },
        )
        .returns(mock_response.new(200, %{ { "translatedText": "#{translated_text}"} }))
        .once

      expect(described_class.translate(post)).to eq(["de", translated_text])
    end
  end
end
