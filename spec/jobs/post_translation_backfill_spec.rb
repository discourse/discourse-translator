# frozen_string_literal: true

describe Jobs::PostTranslationBackfill do
  before do
    SiteSetting.automatic_translation_backfill_rate = 100
    SiteSetting.automatic_translation_target_languages = "en"
  end

  it "does not enqueue post translation when translator disabled" do
    SiteSetting.translator_enabled = false

    described_class.new.execute({})

    expect_not_enqueued_with(job: :translate_posts)
  end

  it "does not enqueue post translation when experimental translation disabled" do
    SiteSetting.translator_enabled = true
    SiteSetting.experimental_content_translation = false

    described_class.new.execute({})

    expect_not_enqueued_with(job: :translate_posts)
  end

  it "does not enqueue psot translation if backfill languages are not set" do
    SiteSetting.translator_enabled = true
    SiteSetting.experimental_content_translation = true
    SiteSetting.automatic_translation_target_languages = ""

    described_class.new.execute({})

    expect_not_enqueued_with(job: :translate_posts)
  end

  it "does not enqueue psot translation if backfill limit is set to 0" do
    SiteSetting.translator_enabled = true
    SiteSetting.experimental_content_translation = true
    SiteSetting.automatic_translation_backfill_rate = 0

    described_class.new.execute({})

    expect_not_enqueued_with(job: :translate_posts)
  end

  it "enqueues post translation with correct limit" do
    SiteSetting.translator_enabled = true
    SiteSetting.experimental_content_translation = true
    SiteSetting.automatic_translation_backfill_rate = 10

    described_class.new.execute({})

    expect_job_enqueued(job: :translate_posts, args: { limit: 10 })
  end
end
