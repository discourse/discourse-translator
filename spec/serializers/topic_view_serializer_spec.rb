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
end
