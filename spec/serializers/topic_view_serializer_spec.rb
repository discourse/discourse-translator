# frozen_string_literal: true

require "rails_helper"

describe TopicViewSerializer do
  fab!(:topic)

  before do
    SiteSetting.translator_enabled = true
    SiteSetting.restrict_translation_by_group = "#{Group::AUTO_GROUPS[:everyone]}"
    SiteSetting.restrict_translation_by_poster_group = "#{Group::AUTO_GROUPS[:everyone]}"
  end

  describe "preloading" do
    fab!(:user)
    fab!(:en_post) do
      post = Fabricate(:post, topic: topic)
      post.set_detected_locale("en")
      post
    end
    fab!(:es_post) do
      post = Fabricate(:post, topic: topic)
      post.set_detected_locale("es")
      post
    end
    fab!(:ja_post) do
      post = Fabricate(:post, topic: topic)
      post.set_detected_locale("ja")
      post
    end

    it "preloads locale without N+1 queries" do
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

    it "preloads translations when experimental_inline_translation is enabled" do
      SiteSetting.experimental_inline_translation = true

      en_post.set_translation("es", "Hola")
      es_post.set_translation("en", "Hello")

      topic_view = TopicView.new(topic)
      serializer = TopicViewSerializer.new(topic_view, scope: Guardian.new(user), root: false)

      topic_view.posts.reload

      queries =
        track_sql_queries do
          json = serializer.as_json
          json[:post_stream][:posts].each { |p| p[:translations] }
        end

      translation_queries =
        queries.count { |q| q.include?("discourse_translator_post_translations") }
      expect(translation_queries).to eq(1)
      expect(topic_view.posts.first.association(:translations)).to be_loaded
    end
  end

  describe "#fancy_title" do
    fab!(:user) { Fabricate(:user, locale: "ja") }

    let!(:original_title) { "<h1>FUS ROH DAAHHH</h1>" }
    let!(:jap_title) { "<h1>フス・ロ・ダ・ア</h1>" }

    before do
      topic.title = original_title
      SiteSetting.experimental_inline_translation = true
      I18n.locale = "ja"
    end

    def serialize_topic(guardian_user: user, params: {})
      env = { "action_dispatch.request.parameters" => params, "REQUEST_METHOD" => "GET" }
      request = ActionDispatch::Request.new(env)
      guardian = Guardian.new(guardian_user, request)
      TopicViewSerializer.new(TopicView.new(topic), scope: guardian)
    end

    it "does not replace fancy_title with translation when experimental_inline_translation is disabled" do
      SiteSetting.experimental_inline_translation = false
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

  describe "#is_translated" do
    fab!(:user)

    def serialize_topic(guardian_user: user)
      TopicViewSerializer.new(TopicView.new(topic), scope: Guardian.new(guardian_user))
    end

    it "returns false when translator is disabled or experimental inline translation is disabled" do
      SiteSetting.translator_enabled = true
      SiteSetting.experimental_inline_translation = true
      I18n.locale = "ja"
      Fabricate(:post, topic: topic)

      expect(serialize_topic.is_translated).to eq(false)
    end

    it "returns true when there is translation for the topic" do
      SiteSetting.translator_enabled = true
      SiteSetting.experimental_inline_translation = true
      I18n.locale = "ja"
      topic.set_translation("ja", "こんにちは")

      expect(serialize_topic.is_translated).to eq(true)
    end

    it "returns true when there is translation for a post in the topic" do
      SiteSetting.translator_enabled = true
      SiteSetting.experimental_inline_translation = true
      I18n.locale = "ja"
      Fabricate(:post, topic: topic).set_translation("ja", "こんにちは")

      expect(serialize_topic.is_translated).to eq(true)
    end
  end
end
