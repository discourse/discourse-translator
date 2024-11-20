# frozen_string_literal: true

require "rails_helper"

RSpec.describe DiscourseTranslator::LibreTranslate do
  let(:mock_response) { Struct.new(:status, :body) }

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
      SiteSetting.translator_libretranslate_endpoint = "http://localhost:5000"
      source = "en"
      target = :fr

      data = [{ code: "en" }, { code: "fr" }]

      Excon.expects(:get).returns(mock_response.new(200, data.to_json))
      expect(described_class.translate_supported?(source, target)).to be true
    end
  end
end
