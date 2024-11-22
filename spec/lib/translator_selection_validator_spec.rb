# frozen_string_literal: true

require "rails_helper"

describe ::DiscourseTranslator::TranslatorSelectionValidator do
  subject { described_class.new }

  fab!(:llm_model) { Fabricate(:llm_model) }

  describe "#valid_value?" do
    context "when value is blank" do
      it "returns true" do
        expect(subject.valid_value?(nil)).to eq(true)
        expect(subject.valid_value?("")).to eq(true)
      end
    end

    context "when value is 'DiscourseAi'" do
      context "when DiscourseAutomation is not defined" do
        it "returns false" do
          hide_const("DiscourseAutomation")
          expect(subject.valid_value?("DiscourseAi")).to eq(false)
        end
      end

      context "when DiscourseAutomation is defined but ai_helper_enabled is false" do
        it "returns false" do
          SiteSetting.ai_helper_enabled = false
          expect(subject.valid_value?("DiscourseAi")).to eq(false)
        end
      end

      context "when DiscourseAutomation is defined and ai_helper_enabled is true" do
        it "returns true" do
          DiscourseAi::Completions::Llm.with_prepared_responses(["OK"]) do
            SiteSetting.ai_helper_model = "custom:#{llm_model.id}"
            SiteSetting.ai_helper_enabled = true
          end
          expect(subject.valid_value?("DiscourseAi")).to eq(true)
        end
      end
    end

    context "when value is not 'DiscourseAi'" do
      it "returns true" do
        expect(subject.valid_value?("googly")).to eq(true)
        expect(subject.valid_value?("poopy")).to eq(true)
      end
    end
  end

  describe "#error_message" do
    context "when DiscourseAutomation is not defined" do
      it "returns the not_installed error message" do
        hide_const("DiscourseAutomation")
        expect(subject.error_message).to eq(I18n.t("translator.discourse_ai.not_installed"))
      end
    end

    context "when DiscourseAutomation is defined but ai_helper_enabled is false" do
      it "returns the ai_helper_required error message" do
        SiteSetting.ai_helper_enabled = false
        expect(subject.error_message).to eq(I18n.t("translator.discourse_ai.ai_helper_required"))
      end
    end

    context "when DiscourseAutomation is defined and ai_helper_enabled is true" do
      it "returns nil" do
        DiscourseAi::Completions::Llm.with_prepared_responses(["OK"]) do
          SiteSetting.ai_helper_model = "custom:#{llm_model.id}"
          SiteSetting.ai_helper_enabled = true
        end
        expect(subject.error_message).to be_nil
      end
    end
  end
end
