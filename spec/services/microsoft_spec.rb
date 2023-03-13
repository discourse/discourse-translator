# frozen_string_literal: true

require "rails_helper"

RSpec.describe DiscourseTranslator::Microsoft do
  after { Discourse.redis.del(described_class.cache_key) }

  describe ".detect" do
    let(:post) { Fabricate(:post) }
    let(:detected_lang) { "en" }

    def detect_endpoint
      uri = URI(described_class.detect_endpoint)
      uri.query = URI.encode_www_form(described_class.default_query)
      uri.to_s
    end

    before { SiteSetting.translator_azure_subscription_key = "e1bba646088021aaf1ef972a48" }

    shared_examples "language detected" do
      it "stores detected language in a custom field" do
        described_class.detect(post)

        expect(post.custom_fields[::DiscourseTranslator::DETECTED_LANG_CUSTOM_FIELD]).to eq(
          detected_lang,
        )
      end
    end

    context "with a custom endpoint" do
      before do
        SiteSetting.translator_azure_custom_domain = "translator19191"

        stub_request(:post, detect_endpoint).to_return(
          status: 200,
          body: [{ "language" => detected_lang }].to_json,
        )
      end

      include_examples "language detected"
    end

    context "without a custom endpoint" do
      before do
        stub_request(:post, detect_endpoint).to_return(
          status: 200,
          body: [{ "language" => detected_lang }].to_json,
        )
      end

      include_examples "language detected"
    end
  end

  describe ".translate" do
    let(:post) { Fabricate(:post) }

    def translate_endpoint
      uri = URI(described_class.translate_endpoint)
      uri.query =
        URI.encode_www_form(
          described_class.default_query.merge(
            "from" => "en",
            "to" => I18n.locale,
            "textType" => "html",
          ),
        )

      uri.to_s
    end

    before do
      post.custom_fields = { DiscourseTranslator::DETECTED_LANG_CUSTOM_FIELD => "en" }
      post.save_custom_fields
      SiteSetting.translator_azure_subscription_key = "e1bba646088021aaf1ef972a48"
    end

    shared_examples "post translated" do
      it "translates post" do
        I18n.locale = "de"

        stub_request(:post, translate_endpoint).to_return(
          status: 200,
          body: [{ "translations" => [{ "text" => "some de text" }] }].to_json,
        )

        expect(described_class.translate(post)).to eq(["en", "some de text"])
      end
    end

    context "with a custom endpoint" do
      before { SiteSetting.translator_azure_custom_domain = "translator19191" }

      include_examples "post translated"
    end

    context "without a custom endpoint" do
      include_examples "post translated"

      it "returns stored translation if post has already been translated" do
        I18n.locale = "en"

        post.custom_fields = {
          DiscourseTranslator::DETECTED_LANG_CUSTOM_FIELD => "tr",
          DiscourseTranslator::TRANSLATED_CUSTOM_FIELD => {
            "en" => "some english text",
          },
        }

        post.save_custom_fields

        expect(described_class.translate(post)).to eq(["tr", "some english text"])
      end

      it "raises an error if detected language of the post is not supported" do
        post.custom_fields = { DiscourseTranslator::DETECTED_LANG_CUSTOM_FIELD => "donkey" }
        post.save_custom_fields

        expect { described_class.translate(post) }.to raise_error(
          DiscourseTranslator::TranslatorError,
          I18n.t("translator.failed"),
        )
      end

      it "raises an error if the post is too long to be translated" do
        post.update_columns(cooked: "*" * (DiscourseTranslator::Microsoft::LENGTH_LIMIT + 1))

        expect { described_class.translate(post) }.to raise_error(
          DiscourseTranslator::TranslatorError,
          I18n.t("translator.too_long"),
        )
      end

      it "raises an error on failure" do
        stub_request(
          :post,
          "https://api.cognitive.microsofttranslator.com/translate?api-version=3.0&from=en&textType=html&to=en",
        ).with(
          body: "[{\"Text\":\"\\u003cp\\u003eHello world\\u003c/p\\u003e\"}]",
          headers: {
            "Ocp-Apim-Subscription-Key" => SiteSetting.translator_azure_subscription_key,
            "Content-Type" => "application/json",
          },
        ).to_return(
          status: 400,
          body: {
            error: "something went wrong",
            error_description: "you passed in a wrong param",
          }.to_json,
        )

        expect { described_class.translate(post) }.to raise_error(
          DiscourseTranslator::TranslatorError,
        )
      end
    end
  end
end
