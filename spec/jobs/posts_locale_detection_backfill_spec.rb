# frozen_string_literal: true

describe Jobs::PostsLocaleDetectionBackfill do
  fab!(:post) { Fabricate(:post, locale: nil) }
  subject(:job) { described_class.new }

  before do
    SiteSetting.translator_enabled = true
    SiteSetting.experimental_content_translation = true
    SiteSetting.automatic_translation_backfill_rate = 100
  end

  it "does nothing when translator is disabled" do
    SiteSetting.translator_enabled = false
    DiscourseTranslator::PostLocaleDetector.expects(:detect_locale).never

    job.execute({})
  end

  it "does nothing when content translation is disabled" do
    SiteSetting.experimental_content_translation = false
    DiscourseTranslator::PostLocaleDetector.expects(:detect_locale).never

    job.execute({})
  end

  it "does nothing when there are no posts to detect" do
    Post.update_all(locale: "en")
    DiscourseTranslator::PostLocaleDetector.expects(:detect_locale).never

    job.execute({})
  end

  it "detects locale for posts with nil locale" do
    DiscourseTranslator::PostLocaleDetector.expects(:detect_locale).with(post).once
    job.execute({})
  end

  it "detects most recently updated posts first" do
    post_2 = Fabricate(:post, locale: nil)
    post_3 = Fabricate(:post, locale: nil)

    post.update!(updated_at: 3.days.ago)
    post_2.update!(updated_at: 2.day.ago)
    post_3.update!(updated_at: 4.day.ago)

    SiteSetting.automatic_translation_backfill_rate = 1

    DiscourseTranslator::PostLocaleDetector.expects(:detect_locale).with(post_2).once
    DiscourseTranslator::PostLocaleDetector.expects(:detect_locale).with(post).never
    DiscourseTranslator::PostLocaleDetector.expects(:detect_locale).with(post_3).never

    job.execute({})
  end

  it "skips bot posts" do
    post.update!(user: Discourse.system_user)
    DiscourseTranslator::PostLocaleDetector.expects(:detect_locale).with(post).never

    job.execute({})
  end

  it "handles detection errors gracefully" do
    DiscourseTranslator::PostLocaleDetector
      .expects(:detect_locale)
      .with(post)
      .raises(StandardError.new("jiboomz"))
      .once

    expect { job.execute({}) }.not_to raise_error
  end

  it "logs a summary after running" do
    DiscourseTranslator::PostLocaleDetector.stubs(:detect_locale)
    DiscourseTranslator::VerboseLogger.expects(:log).with(includes("Detected 1 post locales"))

    job.execute({})
  end

  describe "with public content limitation" do
    fab!(:private_category) { Fabricate(:private_category, group: Group[:staff]) }
    fab!(:private_topic) { Fabricate(:topic, category: private_category) }
    fab!(:private_post) { Fabricate(:post, topic: private_topic, locale: nil) }

    before { SiteSetting.automatic_translation_backfill_limit_to_public_content = true }

    it "only processes posts from public categories" do
      DiscourseTranslator::PostLocaleDetector.expects(:detect_locale).with(post).once
      DiscourseTranslator::PostLocaleDetector.expects(:detect_locale).with(private_post).never

      job.execute({})
    end

    it "processes all posts when setting is disabled" do
      SiteSetting.automatic_translation_backfill_limit_to_public_content = false

      DiscourseTranslator::PostLocaleDetector.expects(:detect_locale).with(post).once
      DiscourseTranslator::PostLocaleDetector.expects(:detect_locale).with(private_post).once

      job.execute({})
    end
  end

  describe "with max age limit" do
    fab!(:old_post) { Fabricate(:post, locale: nil, created_at: 10.days.ago) }
    fab!(:new_post) { Fabricate(:post, locale: nil, created_at: 2.days.ago) }

    before { SiteSetting.automatic_translation_backfill_max_age_days = 5 }

    it "only processes posts within the age limit" do
      # other posts
      DiscourseTranslator::PostLocaleDetector.expects(:detect_locale).at_least_once

      DiscourseTranslator::PostLocaleDetector.expects(:detect_locale).with(new_post).once
      DiscourseTranslator::PostLocaleDetector.expects(:detect_locale).with(old_post).never

      job.execute({})
    end

    it "processes all posts when setting is disabled" do
      SiteSetting.automatic_translation_backfill_max_age_days = 0

      # other posts
      DiscourseTranslator::PostLocaleDetector.expects(:detect_locale).at_least_once

      DiscourseTranslator::PostLocaleDetector.expects(:detect_locale).with(new_post).once
      DiscourseTranslator::PostLocaleDetector.expects(:detect_locale).with(old_post).once

      job.execute({})
    end
  end
end
