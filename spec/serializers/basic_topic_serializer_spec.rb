# frozen_string_literal: true

require "rails_helper"

describe BasicTopicSerializer do
  let!(:guardian) { Guardian.new(user) }
  let!(:original_title) { "FUS ROH DAAHHH" }
  let!(:jap_title) { "フス・ロ・ダ・ア" }

  describe "#fancy_title" do
    fab!(:user) { Fabricate(:user, locale: "ja") }
    fab!(:topic)

    before do
      topic.title = original_title
      SiteSetting.experimental_topic_translation = true
      I18n.locale = "ja"
    end

    def serialize_topic(guardian_user: user, params: {})
      env = { "action_dispatch.request.parameters" => params, "REQUEST_METHOD" => "GET" }
      request = ActionDispatch::Request.new(env)
      guardian = Guardian.new(guardian_user, request)
      BasicTopicSerializer.new(topic, scope: guardian)
    end

    it "returns original fancy_title when experimental_topic_translation is disabled" do
      SiteSetting.experimental_topic_translation = false
      topic.custom_fields[DiscourseTranslator::TRANSLATED_CUSTOM_FIELD] = { "ja" => jap_title }

      expect(serialize_topic.fancy_title).to eq(original_title)
    end

    it "returns original fancy_title when show_original param is present" do
      topic.custom_fields[DiscourseTranslator::TRANSLATED_CUSTOM_FIELD] = { "ja" => jap_title }
      expect(serialize_topic(params: { "show" => "original" }).fancy_title).to eq(original_title)
    end

    it "returns original fancy_title when no translation exists" do
      expect(serialize_topic.fancy_title).to eq(original_title)
    end

    it "returns original fancy_title when translation is blank for current locale" do
      topic.custom_fields[DiscourseTranslator::TRANSLATED_CUSTOM_FIELD] = { "ja" => "" }
      expect(serialize_topic.fancy_title).to eq(original_title)
    end

    it "returns translated title when translation exists for current locale" do
      topic.custom_fields[DiscourseTranslator::TRANSLATED_CUSTOM_FIELD] = { "ja" => jap_title }
      expect(serialize_topic.fancy_title).to eq(jap_title)
    end
  end
end
