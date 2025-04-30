# frozen_string_literal: true

describe Jobs::TranslatePosts do
  fab!(:post)
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
    DiscourseTranslator::PostTranslator.expects(:translate).never

    job.execute({})
  end

  it "does nothing when content translation is disabled" do
    SiteSetting.experimental_content_translation = false
    DiscourseTranslator::PostTranslator.expects(:translate).never

    job.execute({})
  end

  it "does nothing when no target languages are configured" do
    SiteSetting.automatic_translation_target_languages = ""
    DiscourseTranslator::PostTranslator.expects(:translate).never

    job.execute({})
  end

  it "does nothing when there are no posts to translate" do
    Post.destroy_all
    DiscourseTranslator::PostTranslator.expects(:translate).never

    job.execute({})
  end

  it "skips posts that already have localizations" do
    Post.all.each do |post|
      Fabricate(:post_localization, post:, locale: "en")
      Fabricate(:post_localization, post:, locale: "ja")
    end
    DiscourseTranslator::PostTranslator.expects(:translate).never

    job.execute({})
  end

  it "skips bot posts" do
    post.update!(user: Discourse.system_user)
    DiscourseTranslator::PostTranslator.expects(:translate).with(post, "en").never
    DiscourseTranslator::PostTranslator.expects(:translate).with(post, "ja").never

    job.execute({})
  end

  it "handles translation errors gracefully" do
    post.update(locale: "es")
    DiscourseTranslator::PostTranslator
      .expects(:translate)
      .with(post, "en")
      .raises(StandardError.new("API error"))
    DiscourseTranslator::PostTranslator.expects(:translate).with(post, "ja").once
    DiscourseTranslator::PostTranslator.expects(:translate).with(post, "de").once

    expect { job.execute({}) }.not_to raise_error
  end

  it "logs a summary after translation" do
    post.update(locale: "es")
    DiscourseTranslator::PostTranslator.stubs(:translate)
    DiscourseTranslator::VerboseLogger.expects(:log).with(includes("Translated 1 posts to en, ja"))

    job.execute({})
  end

  context "translation scenarios" do
    it "scenario 1: skips post when locale is not set" do
      DiscourseTranslator::PostTranslator.expects(:translate).never

      job.execute({})
    end

    it "scenario 2: returns post with locale 'es' if localizations for en/ja/de do not exist" do
      post = Fabricate(:post, locale: "es")

      DiscourseTranslator::PostTranslator.expects(:translate).with(post, "en").once
      DiscourseTranslator::PostTranslator.expects(:translate).with(post, "ja").once
      DiscourseTranslator::PostTranslator.expects(:translate).with(post, "de").once

      job.execute({})
    end

    it "scenario 3: returns post with locale 'en' if ja/de localization does not exist" do
      post = Fabricate(:post, locale: "en")

      DiscourseTranslator::PostTranslator.expects(:translate).with(post, "ja").once
      DiscourseTranslator::PostTranslator.expects(:translate).with(post, "de").once
      DiscourseTranslator::PostTranslator.expects(:translate).with(post, "en").never

      job.execute({})
    end

    it "scenario 4: skips post with locale 'en' if 'ja' localization already exists" do
      post = Fabricate(:post, locale: "en")
      Fabricate(:post_localization, post: post, locale: "ja")

      DiscourseTranslator::PostTranslator.expects(:translate).with(post, "en").never
      DiscourseTranslator::PostTranslator.expects(:translate).with(post, "ja").never
      DiscourseTranslator::PostTranslator.expects(:translate).with(post, "de").once

      job.execute({})
    end
  end
end
