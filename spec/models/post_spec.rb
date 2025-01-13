# frozen_string_literal: true

require "rails_helper"

RSpec.describe Post do
  before { SiteSetting.translator_enabled = true }

  describe "translator custom fields" do
    let(:post) do
      Fabricate(
        :post,
        raw: "this is a sample post",
        custom_fields: {
          ::DiscourseTranslator::DETECTED_LANG_CUSTOM_FIELD => "en",
          ::DiscourseTranslator::TRANSLATED_CUSTOM_FIELD => {
            "en" => "lol",
          },
        },
      )
    end

    it "should reset custom fields when post has been updated" do
      post.update!(raw: "this is an updated post")

      expect(post.custom_fields[::DiscourseTranslator::DETECTED_LANG_CUSTOM_FIELD]).to be_nil

      expect(post.custom_fields[::DiscourseTranslator::TRANSLATED_CUSTOM_FIELD]).to be_nil
    end
  end

  describe "queueing post for language detection" do
    fab!(:group)
    fab!(:topic)
    fab!(:user) { Fabricate(:user, groups: [group]) }

    before do
      Jobs.run_immediately!
      SiteSetting.create_topic_allowed_groups = Group::AUTO_GROUPS[:everyone]
    end

    it "queues the post for language detection when user and posts are in the right group" do
      SiteSetting.restrict_translation_by_poster_group = "#{group.id}"
      post =
        PostCreator.new(
          user,
          {
            title: "a topic about cats",
            raw: "tomtom is a cat",
            category: Fabricate(:category).id,
          },
        ).create

      expect(
        Discourse.redis.sismember(DiscourseTranslator::LANG_DETECT_NEEDED, post.id),
      ).to be_truthy
    end

    context "when user and posts are not in the right group" do
      it "does not queue the post for language detection" do
        SiteSetting.restrict_translation_by_poster_group = "#{group.id + 1}"
        post =
          PostCreator.new(
            user,
            {
              title: "hello world topic",
              raw: "my name is fred",
              category: Fabricate(:category).id,
            },
          ).create

        expect(
          Discourse.redis.sismember(DiscourseTranslator::LANG_DETECT_NEEDED, post.id),
        ).to be_falsey
      end
    end
  end
end
