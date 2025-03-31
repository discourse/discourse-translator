# frozen_string_literal: true

require "rails_helper"

describe TopicListSerializer do
  fab!(:topic1) { Fabricate(:topic) }
  fab!(:topic2) { Fabricate(:topic) }
  fab!(:topic3) { Fabricate(:topic) }
  fab!(:user)

  let(:topic_list) { TopicList.new(nil, user, [topic1, topic2, topic3]) }

  before do
    SiteSetting.translator_enabled = true
    SiteSetting.experimental_inline_translation = true

    # required for other core parts of topic_view
    [topic1, topic2, topic3].each { |topic| topic.tap { |t| t.allowed_user_ids = [t.user_id] } }
  end

  describe "preloading" do
    it "preloads locale and translations without N+1 queries" do
      serializer = described_class.new(topic_list, scope: Guardian.new(user))

      queries = track_sql_queries { serializer.as_json }

      locale_queries = queries.count { |q| q.include?("discourse_translator_topic_locales") }
      expect(locale_queries).to eq(1) # would be 3 if not preloaded

      translation_queries = queries.count { |q| q.include?("discourse_translator_topic_translations") }
      expect(translation_queries).to eq(1) # would be 3 if not preloaded

      expect(topic_list.topics.first.association(:content_locale)).to be_loaded
    end

    it "never preloads translations if SiteSetting.experimental_inline_translations is false" do
      SiteSetting.experimental_inline_translation = false

      serializer = described_class.new(topic_list, scope: Guardian.new(user))
      queries = track_sql_queries { serializer.as_json }

      locale_queries =
        queries.count { |q| q.include?("discourse_translator_topic_locales") }
      expect(locale_queries).to eq(0)
      translation_queries =
        queries.count { |q| q.include?("discourse_translator_topic_translations") }
      expect(translation_queries).to eq(0)
    end
  end
end
