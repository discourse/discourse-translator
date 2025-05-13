# frozen_string_literal: true

RSpec.describe DiscourseTranslator::Provider::Microsoft do
  before do
    SiteSetting.translator_enabled = true
    SiteSetting.translator_azure_subscription_key = "e1bba646088021aaf1ef972a48"
  end
  after { Discourse.redis.del(described_class.cache_key) }

  def translate_endpoint(to: I18n.locale)
    uri = URI(described_class.translate_endpoint)
    default_query = described_class.default_query.merge("textType" => "html")
    default_query = default_query.merge("to" => to) if to
    uri.query = URI.encode_www_form(default_query)
    uri.to_s
  end

  def stub_translate_request(source_text, target_locale, translated_text)
    stub_request(:post, translate_endpoint(to: target_locale)).with(
      { body: [{ "Text" => source_text }].to_json },
    ).to_return(status: 200, body: [{ "translations" => [{ "text" => translated_text }] }].to_json)
  end

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
          DiscourseTranslator::Provider::ProblemCheckedTranslationError,
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
        SiteSetting.translator_azure_subscription_key = ""
        expect { described_class.detect(post) }.to raise_error(
          DiscourseTranslator::Provider::ProblemCheckedTranslationError,
          I18n.t("translator.microsoft.missing_key"),
        )
      end
    end
  end

  describe ".translate_post!" do
    fab!(:post) { Fabricate(:post, raw: "rawraw rawrawraw", cooked: "coocoo coococooo") }

    before do
      post.set_detected_locale("en")
      I18n.locale = :de
    end

    it "translates post with raw" do
      translated_text = "some text"
      target_locale = "de"
      stub_translate_request(post.raw, target_locale, translated_text)

      expect(described_class.translate_post!(post, :de, { raw: true })).to eq(translated_text)
    end

    it "translates post with cooked" do
      translated_text = "some text"
      target_locale = "de"
      stub_translate_request(post.cooked, target_locale, translated_text)

      expect(described_class.translate_post!(post, :de, { cooked: true })).to eq(translated_text)
    end

    it "translates post with raw when unspecified" do
      translated_text = "some text"
      target_locale = "de"
      stub_translate_request(post.raw, target_locale, translated_text)

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
      translated_text = "some text"
      target_locale = "de"
      stub_translate_request(topic.title, target_locale, translated_text)

      expect(described_class.translate_topic!(topic, :de)).to eq(translated_text)
    end
  end

  describe ".translate_text!" do
    it "translates text" do
      I18n.locale = :es

      text = "ABCDEFG"
      translated_text = "some text"
      stub_translate_request(text, "es", translated_text)

      expect(described_class.translate_text!(text)).to eq(translated_text)
    end
  end
end
