# frozen_string_literal: true

require "rails_helper"

describe TopicViewSerializer do
  fab!(:user)
  fab!(:topic)
  fab!(:post1) { Fabricate(:post, topic: topic).set_detected_locale("en") }
  fab!(:post2) { Fabricate(:post, topic: topic).set_detected_locale("es") }
  fab!(:post3) { Fabricate(:post, topic: topic).set_detected_locale("ja") }

  before do
    SiteSetting.translator_enabled = true
    SiteSetting.restrict_translation_by_group = "#{Group::AUTO_GROUPS[:everyone]}"
    SiteSetting.restrict_translation_by_poster_group = "#{Group::AUTO_GROUPS[:everyone]}"
  end

  it "preloads translations without N+1 queries" do
    topic_view = TopicView.new(topic)
    serializer = TopicViewSerializer.new(topic_view, scope: Guardian.new(user), root: false)

    # ensure translation data is included in the JSON
    json = {}
    queries = track_sql_queries { json = serializer.as_json }
    posts_json = json[:post_stream][:posts]
    expect(posts_json.map { |p| p[:can_translate] }).to eq([false, true, true])

    translation_queries = queries.count { |q| q.include?("discourse_translator_post_locales") }
    expect(translation_queries).to eq(1) # would be 3 (posts) if not preloaded

    expect(topic_view.posts.first.association(:content_locale)).to be_loaded
  end

  describe "#fancy_title" do
    fab!(:user) { Fabricate(:user, locale: "ja") }
    fab!(:topic)

    let!(:guardian) { Guardian.new(user) }
    let!(:original_title) { "FUS ROH DAAHHH" }
    let!(:jap_title) { "フス・ロ・ダ・ア" }

    before do
      topic.fancy_title = original_title
      SiteSetting.experimental_topic_translation = true
      I18n.locale = "ja"
    end

    def serialize_topic(guardian_user: user, params: {})
      env = { "action_dispatch.request.parameters" => params, "REQUEST_METHOD" => "GET" }
      request = ActionDispatch::Request.new(env)
      guardian = Guardian.new(guardian_user, request)
      TopicViewSerializer.new(TopicView.new(topic), scope: guardian)
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

    it "returns translated fancy title in fancy_title when translation exists for current locale" do
      topic.set_translation("ja", jap_title)
      expect(serialize_topic.fancy_title).to eq(jap_title)
    end
  end
end
