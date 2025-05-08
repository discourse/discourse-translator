# frozen_string_literal: true

describe Jobs::TopicsLocaleDetectionBackfill do
  fab!(:topic) { Fabricate(:topic, locale: nil) }
  subject(:job) { described_class.new }

  before do
    SiteSetting.translator_enabled = true
    SiteSetting.experimental_content_translation = true
    SiteSetting.automatic_translation_backfill_rate = 100
  end

  it "does nothing when translator is disabled" do
    SiteSetting.translator_enabled = false
    DiscourseTranslator::TopicLocaleDetector.expects(:detect_locale).never

    job.execute({})
  end

  it "does nothing when content translation is disabled" do
    SiteSetting.experimental_content_translation = false
    DiscourseTranslator::TopicLocaleDetector.expects(:detect_locale).never

    job.execute({})
  end

  it "does nothing when there are no topics to detect" do
    Topic.update_all(locale: "en")
    DiscourseTranslator::TopicLocaleDetector.expects(:detect_locale).never

    job.execute({})
  end

  it "detects locale for topics with nil locale" do
    DiscourseTranslator::TopicLocaleDetector.expects(:detect_locale).with(topic).once
    job.execute({})
  end

  it "detects most recently updated topics first" do
    topic_2 = Fabricate(:topic, locale: nil)
    topic_3 = Fabricate(:topic, locale: nil)

    topic.update!(updated_at: 3.days.ago)
    topic_2.update!(updated_at: 2.day.ago)
    topic_3.update!(updated_at: 4.day.ago)

    SiteSetting.automatic_translation_backfill_rate = 1

    DiscourseTranslator::TopicLocaleDetector.expects(:detect_locale).with(topic_2).once
    DiscourseTranslator::TopicLocaleDetector.expects(:detect_locale).with(topic).never
    DiscourseTranslator::TopicLocaleDetector.expects(:detect_locale).with(topic_3).never

    job.execute({})
  end

  it "skips bot topics" do
    topic.update!(user: Discourse.system_user)
    DiscourseTranslator::TopicLocaleDetector.expects(:detect_locale).with(topic).never

    job.execute({})
  end

  it "handles detection errors gracefully" do
    DiscourseTranslator::TopicLocaleDetector
      .expects(:detect_locale)
      .with(topic)
      .raises(StandardError.new("jiboomz"))
      .once

    expect { job.execute({}) }.not_to raise_error
  end

  it "logs a summary after running" do
    DiscourseTranslator::TopicLocaleDetector.stubs(:detect_locale)
    DiscourseTranslator::VerboseLogger.expects(:log).with(includes("Detected 1 topic locales"))

    job.execute({})
  end
end
