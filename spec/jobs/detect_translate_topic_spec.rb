# frozen_string_literal: true

describe Jobs::DetectTranslateTopic do
  fab!(:topic)
  subject(:job) { described_class.new }

  let(:locales) { %w[en ja] }

  before do
    SiteSetting.translator_enabled = true
    SiteSetting.experimental_content_translation = true
    SiteSetting.automatic_translation_backfill_rate = 1
    SiteSetting.automatic_translation_target_languages = locales.join("|")
  end

  it "does nothing when translator is disabled" do
    SiteSetting.translator_enabled = false
    DiscourseTranslator::TopicLocaleDetector.expects(:detect_locale).never
    DiscourseTranslator::TopicTranslator.expects(:translate).never

    job.execute({ topic_id: topic.id })
  end

  it "does nothing when content translation is disabled" do
    SiteSetting.experimental_content_translation = false
    DiscourseTranslator::TopicLocaleDetector.expects(:detect_locale).never
    DiscourseTranslator::TopicTranslator.expects(:translate).never

    job.execute({ topic_id: topic.id })
  end

  it "detects locale" do
    SiteSetting.translator_enabled = true
    DiscourseTranslator::TopicLocaleDetector.expects(:detect_locale).with(topic).once
    DiscourseTranslator::TopicTranslator.expects(:translate).twice

    job.execute({ topic_id: topic.id })
  end

  it "skips bot topics" do
    topic.update!(user: Discourse.system_user)
    DiscourseTranslator::TopicTranslator.expects(:translate).never

    job.execute({ topic_id: topic.id })
  end

  it "does not translate when no target languages are configured" do
    SiteSetting.automatic_translation_target_languages = ""
    DiscourseTranslator::TopicLocaleDetector.expects(:detect_locale).with(topic).returns("en")
    DiscourseTranslator::TopicTranslator.expects(:translate).never

    job.execute({ topic_id: topic.id })
  end

  it "skips translating to the topic's language" do
    topic.update(locale: "en")
    DiscourseTranslator::TopicLocaleDetector.expects(:detect_locale).with(topic).returns("en")
    DiscourseTranslator::TopicTranslator.expects(:translate).with(topic, "en").never
    DiscourseTranslator::TopicTranslator.expects(:translate).with(topic, "ja").once

    job.execute({ topic_id: topic.id })
  end

  it "handles translation errors gracefully" do
    topic.update(locale: "en")
    DiscourseTranslator::TopicLocaleDetector.expects(:detect_locale).with(topic).returns("en")
    DiscourseTranslator::TopicTranslator.expects(:translate).raises(StandardError.new("API error"))

    expect { job.execute({ topic_id: topic.id }) }.not_to raise_error
  end
end
