# frozen_string_literal: true

describe Jobs::TranslatePosts do
  fab!(:post)
  subject(:job) { described_class.new }

  let(:locales) { %w[en ja de] }

  before do
    SiteSetting.translator_enabled = true
    SiteSetting.experimental_content_translation = true
    SiteSetting.automatic_translation_backfill_rate = 1
    SiteSetting.experimental_content_localization_supported_locales = locales.join("|")
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
    SiteSetting.experimental_content_localization_supported_locales = ""
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
    DiscourseTranslator::VerboseLogger.expects(:log).with(includes("Translated 1 posts to en"))
    DiscourseTranslator::VerboseLogger.expects(:log).with(includes("Translated 1 posts to ja"))
    DiscourseTranslator::VerboseLogger.expects(:log).with(includes("Translated 1 posts to de"))

    job.execute({})
  end

  context "for translation scenarios" do
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

  describe "with public content limitation" do
    fab!(:private_category) { Fabricate(:private_category, group: Group[:staff]) }
    fab!(:private_topic) { Fabricate(:topic, category: private_category) }
    fab!(:private_post) { Fabricate(:post, topic: private_topic, locale: "es") }
    fab!(:public_post) { Fabricate(:post, locale: "es") }

    before { SiteSetting.automatic_translation_backfill_limit_to_public_content = true }

    it "only processes posts from public categories" do
      DiscourseTranslator::PostTranslator.expects(:translate).with(public_post, "en").once
      DiscourseTranslator::PostTranslator.expects(:translate).with(public_post, "ja").once
      DiscourseTranslator::PostTranslator.expects(:translate).with(public_post, "de").once

      DiscourseTranslator::PostTranslator
        .expects(:translate)
        .with(private_post, any_parameters)
        .never

      job.execute({})
    end

    it "processes all posts when setting is disabled" do
      SiteSetting.automatic_translation_backfill_limit_to_public_content = false

      DiscourseTranslator::PostTranslator.expects(:translate).with(public_post, "en").once
      DiscourseTranslator::PostTranslator.expects(:translate).with(public_post, "ja").once
      DiscourseTranslator::PostTranslator.expects(:translate).with(public_post, "de").once

      DiscourseTranslator::PostTranslator.expects(:translate).with(private_post, "en").once
      DiscourseTranslator::PostTranslator.expects(:translate).with(private_post, "ja").once
      DiscourseTranslator::PostTranslator.expects(:translate).with(private_post, "de").once

      job.execute({})
    end
  end

  describe "with max age limit" do
    fab!(:old_post) { Fabricate(:post, locale: "es", created_at: 10.days.ago) }
    fab!(:new_post) { Fabricate(:post, locale: "es", created_at: 2.days.ago) }

    before { SiteSetting.automatic_translation_backfill_max_age_days = 5 }

    it "only processes posts within the age limit" do
      DiscourseTranslator::PostTranslator.expects(:translate).with(new_post, "en").once
      DiscourseTranslator::PostTranslator.expects(:translate).with(new_post, "ja").once
      DiscourseTranslator::PostTranslator.expects(:translate).with(new_post, "de").once

      DiscourseTranslator::PostTranslator.expects(:translate).with(old_post, any_parameters).never

      job.execute({})
    end

    it "processes all posts when setting is disabled" do
      SiteSetting.automatic_translation_backfill_max_age_days = 0

      DiscourseTranslator::PostTranslator.expects(:translate).with(new_post, "en").once
      DiscourseTranslator::PostTranslator.expects(:translate).with(new_post, "ja").once
      DiscourseTranslator::PostTranslator.expects(:translate).with(new_post, "de").once

      DiscourseTranslator::PostTranslator.expects(:translate).with(old_post, "en").once
      DiscourseTranslator::PostTranslator.expects(:translate).with(old_post, "ja").once
      DiscourseTranslator::PostTranslator.expects(:translate).with(old_post, "de").once

      job.execute({})
    end
  end
end
