# frozen_string_literal: true

RSpec.describe ProblemCheck::MicrosoftAzureKey do
  subject(:check) { described_class.new }

  describe ".call" do
    before { SiteSetting.stubs(translator_enabled: enabled) }

    context "when plugin is disabled" do
      let(:enabled) { false }

      it { expect(check).to be_chill_about_it }
    end

    context "when plugin is enabled" do
      let(:enabled) { true }

      it "when translator is not Microsoft" do
        SiteSetting.translator = "Google"

        expect(check).to be_chill_about_it
      end

      context "when translator is microsoft" do
        it "when Azure key is not provided" do
          SiteSetting.translator_azure_subscription_key = ""

          expect(check).to have_a_problem.with_priority("high").with_message(
            I18n.t("dashboard.problem.microsoft_azure_key"),
          )
        end

        it "when Azure key is provided" do
          SiteSetting.translator_azure_subscription_key = "foo"

          expect(check).to be_chill_about_it
        end
      end
    end
  end
end
