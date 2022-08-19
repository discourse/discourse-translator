# frozen_string_literal: true

require 'rails_helper'

RSpec.describe TopicViewSerializer do
  let(:topic) { Fabricate(:topic) }
  let(:japanese_locale) { 'ja' }
  let(:user) { Fabricate(:user, locale: japanese_locale) }

  it "doesn't affect normal title serialization" do
    serializer = described_class.new(TopicView.new(topic.id), scope: Guardian.new(user), root: false)
    expect(serializer.title).to eq(topic.title)
    expect(serializer.fancy_title).to eq(topic.fancy_title)
  end

  describe "when plugin enabled" do
    before do
      SiteSetting.translator_enabled = true
    end

    it "doesn't affect normal title serialization" do
      serializer = described_class.new(TopicView.new(topic.id), scope: Guardian.new(user), root: false)
      expect(serializer.title).to eq(topic.title)
      expect(serializer.fancy_title).to eq(topic.fancy_title)
    end

    describe "when show topic titles in user locale enabled" do
      let(:translated_title) { 'ニャン猫' }

      before do
        SiteSetting.translator_show_topic_titles_in_user_locale = true
        Topic.any_instance.stubs(:translated_title).returns(translated_title)
        Topic.any_instance.stubs(:title_language).returns(japanese_locale)
      end

      it "serializes translated titles and metadata" do
        serializer = described_class.new(TopicView.new(topic.id), scope: Guardian.new(user), root: false)
        expect(serializer.title).to eq(translated_title)
        expect(serializer.fancy_title).to eq(translated_title)
        expect(serializer.original_title).to eq(topic.title)
        expect(serializer.title_translated).to eq(true)
        expect(serializer.title_language).to eq(japanese_locale)
        expect(serializer.can_translate_title).to eq(true)
      end
    end
  end
end
