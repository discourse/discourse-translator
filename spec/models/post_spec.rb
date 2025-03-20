# frozen_string_literal: true

require "rails_helper"

RSpec.describe Post do
  before do
    SiteSetting.translator_enabled = true
    SiteSetting.create_topic_allowed_groups = Group::AUTO_GROUPS[:everyone]
  end

  describe "translatable" do
    fab!(:post)

    it "should reset translation data when post title has been updated" do
      Fabricate(:post_translation, post:)
      Fabricate(:post_locale, post:)
      post.update!(raw: "this is an updated title")

      expect(DiscourseTranslator::PostLocale.where(post:)).to be_empty
      expect(DiscourseTranslator::PostLocale.find_by(post:)).to be_nil
    end

    describe "#set_translation" do
      it "creates new translation" do
        post.set_translation("en", "Hello")

        translation = post.translations.find_by(locale: "en")
        expect(translation.translation).to eq("Hello")
      end

      it "updates existing translation" do
        post.set_translation("en", "Hello")
        post.set_translation("en", "Updated hello")

        expect(post.translations.where(locale: "en").count).to eq(1)
        expect(post.translation_for("en")).to eq("Updated hello")
      end

      it "converts underscore to hyphen in locale" do
        post.set_translation("en_US", "Hello")

        expect(post.translations.find_by(locale: "en-US")).to be_present
        expect(post.translations.find_by(locale: "en_US")).to be_nil
      end
    end

    describe "#translation_for" do
      it "returns nil when translation doesn't exist" do
        expect(post.translation_for("fr")).to be_nil
      end

      it "returns translation when it exists" do
        post.set_translation("es", "Hola")
        expect(post.translation_for("es")).to eq("Hola")
      end
    end

    describe "#set_locale" do
      it "creates new locale" do
        post.set_detected_locale("en-US")
        expect(post.content_locale.detected_locale).to eq("en-US")
      end

      it "converts underscore to hyphen" do
        post.set_detected_locale("en_US")
        expect(post.content_locale.detected_locale).to eq("en-US")
      end
    end
  end

  describe "queueing post for language detection" do
    fab!(:group)
    fab!(:user) { Fabricate(:user, groups: [group]) }

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
      CookedPostProcessor.new(post).post_process

      expect_job_enqueued(
        job: :detect_translatable_language,
        args: {
          type: "Post",
          translatable_id: post.id,
        },
      )
      expect_job_enqueued(
        job: :detect_translatable_language,
        args: {
          type: "Topic",
          translatable_id: post.topic_id,
        },
      )
    end

    it "does not queue bot posts for language detection" do
      SiteSetting.restrict_translation_by_poster_group = Group::AUTO_GROUPS[:everyone]
      post =
        PostCreator.new(
          Discourse.system_user,
          { title: "hello world topic", raw: "my name is cat", category: Fabricate(:category).id },
        ).create

      expect(
        Discourse.redis.sismember(DiscourseTranslator::LANG_DETECT_NEEDED, post.id),
      ).to be_falsey
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

  describe "automatic translation job" do
    fab!(:user)

    it "enqueues translate_translatable job when post cooked" do
      SiteSetting.automatic_translation_backfill_rate = 100
      SiteSetting.automatic_translation_target_languages = "es"
      post = Fabricate(:post, user: user)
      CookedPostProcessor.new(post).post_process

      expect_job_enqueued(
        job: :translate_translatable,
        args: {
          type: "Post",
          translatable_id: post.id,
        },
      )
    end

    it "does not enqueue translate_translatable job for bot posts" do
      SiteSetting.automatic_translation_backfill_rate = 1
      SiteSetting.automatic_translation_target_languages = "es"
      post = Fabricate(:post, user: Discourse.system_user)
      CookedPostProcessor.new(post).post_process

      expect(
        job_enqueued?(
          job: :translate_translatable,
          args: {
            type: "Post",
            translatable_id: post.id,
          },
        ),
      ).to eq false
    end
  end
end
