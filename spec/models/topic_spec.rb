# frozen_string_literal: true

require "rails_helper"

RSpec.describe Topic do
  describe "translator custom fields" do
    fab!(:topic) do
      Fabricate(
        :topic,
        title: "this is a sample title",
        custom_fields: {
          ::DiscourseTranslator::DETECTED_LANG_CUSTOM_FIELD => "en",
          ::DiscourseTranslator::TRANSLATED_CUSTOM_FIELD => {
            "en" => "lol",
          },
        },
      )
    end

    before { SiteSetting.translator_enabled = true }

    after { SiteSetting.translator_enabled = false }

    it "should reset custom fields when topic title has been updated" do
      topic.update!(title: "this is an updated title")

      expect(topic.custom_fields[::DiscourseTranslator::DETECTED_LANG_CUSTOM_FIELD]).to be_nil

      expect(topic.custom_fields[::DiscourseTranslator::TRANSLATED_CUSTOM_FIELD]).to be_nil
    end
  end
end
