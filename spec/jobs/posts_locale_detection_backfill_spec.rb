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
end
