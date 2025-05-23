# frozen_string_literal: true

require "rails_helper"

describe ::DiscourseTranslator::Validators::TranslatorSelectionValidator do
  fab!(:llm_model)

  describe "#valid_value?" do
    context "when value is blank" do
      it "returns true" do
        expect(described_class.new.valid_value?(nil)).to eq(true)
        expect(described_class.new.valid_value?("")).to eq(true)
      end
    end

    context "when value is 'DiscourseAi'" do
      context "when DiscourseAi is not defined" do
        it "returns false" do
          hide_const("DiscourseAi")
          expect(described_class.new.valid_value?("DiscourseAi")).to eq(false)
        end
      end

      context "when DiscourseAi is defined" do
        it "returns true" do
          DiscourseAi::Completions::Llm.with_prepared_responses(["OK"]) do
            SiteSetting.ai_translation_model = "custom:#{llm_model.id}"
          end
          expect(described_class.new.valid_value?("DiscourseAi")).to eq(true)
        end
      end
    end

    context "when value is not 'DiscourseAi'" do
      it "returns true" do
        expect(described_class.new.valid_value?("googly")).to eq(true)
        expect(described_class.new.valid_value?("poopy")).to eq(true)
      end
    end
  end

  describe "#error_message" do
    context "when DiscourseAi is not defined" do
      it "returns the not_installed error message" do
        hide_const("DiscourseAi")
        expect(described_class.new.error_message).to eq(
          I18n.t("translator.discourse_ai.not_installed"),
        )
      end
    end

    context "when DiscourseAi is defined" do
      it "returns nil" do
        DiscourseAi::Completions::Llm.with_prepared_responses(["OK"]) do
          SiteSetting.ai_translation_model = "custom:#{llm_model.id}"
        end
        expect(described_class.new.error_message).to be_nil
      end
    end
  end
end
