# frozen_string_literal: true

require "rails_helper"

RSpec.describe DiscourseTranslator::Microsoft do
  before { SiteSetting.translator_enabled = true }
  after { Discourse.redis.del(described_class.cache_key) }

  describe ".detect" do
    let(:post) { Fabricate(:post) }
    let(:detected_lang) { "en" }

    def detect_endpoint
      uri = URI(described_class.detect_endpoint)
      uri.query = URI.encode_www_form(described_class.default_query)
      uri.to_s
    end

    context "with azure key" do
      before { SiteSetting.translator_azure_subscription_key = "e1bba646088021aaf1ef972a48" }

      shared_examples "language detected" do
        it "stores detected language" do
          described_class.detect(post)

          expect(post.detected_locale).to eq(detected_lang)
        end
      end

      context "with a custom endpoint" do
        before do
          SiteSetting.translator_azure_custom_subdomain = "translator19191"

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

      it "raise a error and trigger a problemcheck when the server returns a error" do
        stub_request(:post, detect_endpoint).to_return(
          status: 429,
          body: {
            "error" => {
              "code" => 429_001,
              "message" =>
                "The server rejected the request because the client has exceeded request limits.",
            },
          }.to_json,
        )

        ProblemCheckTracker[:translator_error].no_problem!

        expect { described_class.detect(post) }.to raise_error(
          DiscourseTranslator::ProblemCheckedTranslationError,
        )

        expect(AdminNotice.problem.last.message).to eq(
          I18n.t(
            "dashboard.problem.translator_error",
            locale: "en",
            provider: "Microsoft",
            code: 429_001,
            message:
              "The server rejected the request because the client has exceeded request limits.",
          ),
        )
      end

      it "clean up errors on the admin dashboard when OK" do
        stub_request(:post, detect_endpoint).to_return(
          status: 200,
          body: [{ "language" => detected_lang }].to_json,
        )

        ProblemCheckTracker[:translator_error].problem!(
          details: {
            provider: "Microsoft",
            code: 429_001,
            message: "example",
          },
        )

        described_class.detect(post)

        expect(AdminNotice.problem.last&.identifier).not_to eq("translator_error")
      end
    end

    context "without azure key" do
      it "raise a MicrosoftNoAzureKeyError" do
        expect { described_class.detect(post) }.to raise_error(
          DiscourseTranslator::ProblemCheckedTranslationError,
          I18n.t("translator.microsoft.missing_key"),
        )
      end
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
      post.set_detected_locale("en")
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
      before { SiteSetting.translator_azure_custom_subdomain = "translator19191" }

      include_examples "post translated"
    end

    context "without a custom endpoint" do
      include_examples "post translated"

      it "returns stored translation if post has already been translated" do
        I18n.locale = "en"

        post.set_detected_locale("tr")
        post.set_translation("en", "some english text")

        expect(described_class.translate(post)).to eq(["tr", "some english text"])
      end

      it "raises an error if detected language of the post is not supported" do
        post.set_detected_locale("donkey")

        expect { described_class.translate(post) }.to raise_error(
          DiscourseTranslator::TranslatorError,
          I18n.t("translator.failed.post", source_locale: "donkey", target_locale: I18n.locale),
        )
      end

      it "raises an error if the post is too long to be translated" do
        I18n.locale = "ja"
        SiteSetting.max_characters_per_translation = 100_000
        post.update_columns(cooked: "*" * (DiscourseTranslator::Microsoft::LENGTH_LIMIT + 1))

        expect { described_class.translate(post) }.to raise_error(
          DiscourseTranslator::TranslatorError,
          I18n.t("translator.too_long"),
        )
      end

      it "raises an error on failure" do
        I18n.locale = "ja"
        stub_request(
          :post,
          "https://api.cognitive.microsofttranslator.com/translate?api-version=3.0&from=en&textType=html&to=ja",
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
