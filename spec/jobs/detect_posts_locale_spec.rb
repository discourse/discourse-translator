# frozen_string_literal: true

describe Jobs::DetectPostsLocale do
  fab!(:post) { Fabricate(:post, locale: nil) }
  subject(:job) { described_class.new }

  before do
    SiteSetting.translator_enabled = true
    SiteSetting.experimental_content_translation = true
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
