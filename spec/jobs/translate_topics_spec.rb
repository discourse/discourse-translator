# frozen_string_literal: true

describe Jobs::TranslateTopics do
  fab!(:topic)
  subject(:job) { described_class.new }

  let(:locales) { %w[en ja de] }

  before do
    SiteSetting.translator_enabled = true
    SiteSetting.experimental_content_translation = true
    SiteSetting.automatic_translation_backfill_rate = 1
    SiteSetting.automatic_translation_target_languages = locales.join("|")
  end

  it "does nothing when translator is disabled" do
    SiteSetting.translator_enabled = false
    DiscourseTranslator::TopicTranslator.expects(:translate).never

    job.execute({})
  end

  it "does nothing when content translation is disabled" do
    SiteSetting.experimental_content_translation = false
    DiscourseTranslator::TopicTranslator.expects(:translate).never

    job.execute({})
  end

  it "does nothing when no target languages are configured" do
    SiteSetting.automatic_translation_target_languages = ""
    DiscourseTranslator::TopicTranslator.expects(:translate).never

    job.execute({})
  end

  it "does nothing when there are no topics to translate" do
    Topic.destroy_all
    DiscourseTranslator::TopicTranslator.expects(:translate).never

    job.execute({})
  end

  it "skips topics that already have localizations" do
    Topic.all.each do |topic|
      Fabricate(:topic_localization, topic:, locale: "en")
      Fabricate(:topic_localization, topic:, locale: "ja")
    end
    DiscourseTranslator::TopicTranslator.expects(:translate).never

    job.execute({})
  end

  it "skips bot topics" do
    topic.update!(user: Discourse.system_user)
    DiscourseTranslator::TopicTranslator.expects(:translate).with(topic, "en").never
    DiscourseTranslator::TopicTranslator.expects(:translate).with(topic, "ja").never

    job.execute({})
  end

  it "handles translation errors gracefully" do
    topic.update(locale: "es")
    DiscourseTranslator::TopicTranslator
      .expects(:translate)
      .with(topic, "en")
      .raises(StandardError.new("API error"))
    DiscourseTranslator::TopicTranslator.expects(:translate).with(topic, "ja").once
    DiscourseTranslator::TopicTranslator.expects(:translate).with(topic, "de").once

    expect { job.execute({}) }.not_to raise_error
  end

  it "logs a summary after translation" do
    topic.update(locale: "es")
    DiscourseTranslator::TopicTranslator.stubs(:translate)
    DiscourseTranslator::VerboseLogger.expects(:log).with(includes("Translated 1 topics to en"))
    DiscourseTranslator::VerboseLogger.expects(:log).with(includes("Translated 1 topics to ja"))
    DiscourseTranslator::VerboseLogger.expects(:log).with(includes("Translated 1 topics to de"))

    job.execute({})
  end

  context "for translation scenarios" do
    it "scenario 1: skips topic when locale is not set" do
      DiscourseTranslator::TopicTranslator.expects(:translate).never

      job.execute({})
    end

    it "scenario 2: returns topic with locale 'es' if localizations for en/ja/de do not exist" do
      topic = Fabricate(:topic, locale: "es")

      DiscourseTranslator::TopicTranslator.expects(:translate).with(topic, "en").once
      DiscourseTranslator::TopicTranslator.expects(:translate).with(topic, "ja").once
      DiscourseTranslator::TopicTranslator.expects(:translate).with(topic, "de").once

      job.execute({})
    end

    it "scenario 3: returns topic with locale 'en' if ja/de localization does not exist" do
      topic = Fabricate(:topic, locale: "en")

      DiscourseTranslator::TopicTranslator.expects(:translate).with(topic, "ja").once
      DiscourseTranslator::TopicTranslator.expects(:translate).with(topic, "de").once
      DiscourseTranslator::TopicTranslator.expects(:translate).with(topic, "en").never

      job.execute({})
    end

    it "scenario 4: skips topic with locale 'en' if 'ja' localization already exists" do
      topic = Fabricate(:topic, locale: "en")
      Fabricate(:topic_localization, topic: topic, locale: "ja")

      DiscourseTranslator::TopicTranslator.expects(:translate).with(topic, "en").never
      DiscourseTranslator::TopicTranslator.expects(:translate).with(topic, "ja").never
      DiscourseTranslator::TopicTranslator.expects(:translate).with(topic, "de").once

      job.execute({})
    end
  end
end
