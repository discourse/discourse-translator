# frozen_string_literal: true

require "rails_helper"

describe BasicTopicSerializer do
  fab!(:user) { Fabricate(:user, locale: "ja") }
  fab!(:topic)

  before do
    SiteSetting.translator_enabled = true
    SiteSetting.experimental_topic_translation = true
  end

  describe "#fancy_title" do
    let!(:guardian) { Guardian.new(user) }
    let!(:original_title) { "<h1>FUS ROH DAAHHH</h1>" }
    let!(:jap_title) { "<h1>フス・ロ・ダ・ア</h1>" }

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

    it "does not replace fancy_title with translation when experimental_topic_translation is disabled" do
      SiteSetting.experimental_topic_translation = false
      topic.set_translation("ja", jap_title)

      expect(serialize_topic.fancy_title).to eq(topic.fancy_title)
    end

    it "does not replace fancy_title with translation when show_original param is present" do
      topic.set_translation("ja", jap_title)
      expect(serialize_topic(params: { "show" => "original" }).fancy_title).to eq(topic.fancy_title)
    end

    it "does not replace fancy_title with translation when no translation exists" do
      expect(serialize_topic.fancy_title).to eq(topic.fancy_title)
    end

    it "does not replace fancy_title when topic is already in correct locale" do
      I18n.locale = "ja"
      topic.set_detected_locale("ja")
      topic.set_translation("ja", jap_title)

      expect(serialize_topic.fancy_title).to eq(topic.fancy_title)
    end

    it "returns translated title in fancy_title when translation exists for current locale" do
      topic.set_translation("ja", jap_title)
      expect(serialize_topic.fancy_title).to eq("&lt;h1&gt;フス・ロ・ダ・ア&lt;/h1&gt;")
    end
  end
end
