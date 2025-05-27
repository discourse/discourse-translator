# frozen_string_literal: true

describe Jobs::DetectTranslatePost do
  fab!(:post)
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
    DiscourseTranslator::PostLocaleDetector.expects(:detect_locale).never
    DiscourseTranslator::PostTranslator.expects(:translate).never

    job.execute({ post_id: post.id })
  end

  it "does nothing when content translation is disabled" do
    SiteSetting.experimental_content_translation = false
    DiscourseTranslator::PostLocaleDetector.expects(:detect_locale).never
    DiscourseTranslator::PostTranslator.expects(:translate).never

    job.execute({ post_id: post.id })
  end

  it "detects locale" do
    SiteSetting.translator_enabled = true
    DiscourseTranslator::PostLocaleDetector.expects(:detect_locale).with(post).once
    DiscourseTranslator::PostTranslator.expects(:translate).twice

    job.execute({ post_id: post.id })
  end

  it "skips bot posts" do
    post.update!(user: Discourse.system_user)
    DiscourseTranslator::PostTranslator.expects(:translate).never

    job.execute({ post_id: post.id })
  end

  it "does not translate when no target languages are configured" do
    SiteSetting.automatic_translation_target_languages = ""
    DiscourseTranslator::PostLocaleDetector.expects(:detect_locale).with(post).returns("en")
    DiscourseTranslator::PostTranslator.expects(:translate).never

    job.execute({ post_id: post.id })
  end

  it "skips translating to the post's language" do
    post.update(locale: "en")
    DiscourseTranslator::PostLocaleDetector.expects(:detect_locale).with(post).returns("en")
    DiscourseTranslator::PostTranslator.expects(:translate).with(post, "en").never
    DiscourseTranslator::PostTranslator.expects(:translate).with(post, "ja").once

    job.execute({ post_id: post.id })
  end

  it "handles translation errors gracefully" do
    post.update(locale: "en")
    DiscourseTranslator::PostLocaleDetector.expects(:detect_locale).with(post).returns("en")
    DiscourseTranslator::PostTranslator.expects(:translate).raises(StandardError.new("API error"))

    expect { job.execute({ post_id: post.id }) }.not_to raise_error
  end

  it "skips public content when configured" do
    SiteSetting.automatic_translation_backfill_limit_to_public_content = true
    post.topic.category.update!(read_restricted: true)

    DiscourseTranslator::PostLocaleDetector.expects(:detect_locale).with(post).never
    DiscourseTranslator::PostTranslator.expects(:translate).never

    job.execute({ post_id: post.id })
  end
end
