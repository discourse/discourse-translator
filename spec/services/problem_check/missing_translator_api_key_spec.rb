# frozen_string_literal: true

RSpec.describe ProblemCheck::MissingTranslatorApiKey do
  subject(:check) { described_class.new }

  describe ".call" do
    before { SiteSetting.stubs(translator_enabled: enabled) }

    shared_examples "missing key checker" do |provider, key|
      context "when translator is #{provider}" do
        before { SiteSetting.translator = provider }

        it "when #{provider} is not provided" do
          SiteSetting.set(key, "")

          expect(check).to have_a_problem.with_priority("high").with_message(
            I18n.t(
              "dashboard.problem.missing_translator_api_key",
              locale: "en",
              provider:,
              key: I18n.t("site_settings.#{key}"),
              key_name: key,
            ),
          )
        end

        it "when #{provider} is provided" do
          SiteSetting.set(key, "foo")

          expect(check).to be_chill_about_it
        end
      end
    end

    context "when plugin is disabled" do
      let(:enabled) { false }

      it { expect(check).to be_chill_about_it }
    end

    context "when plugin is enabled" do
      let(:enabled) { true }

      include_examples "missing key checker", "Google", "translator_google_api_key"
      include_examples "missing key checker", "Microsoft", "translator_azure_subscription_key"
    end
  end
end
