# frozen_string_literal: true

describe Jobs::AutomaticTranslationBackfill do
  before do
    SiteSetting.translator_enabled = true
    SiteSetting.translator = "Google"
    SiteSetting.translator_google_api_key = "api_key"
  end

  def expect_google_check_language
    Excon
      .expects(:post)
      .with(DiscourseTranslator::Google::SUPPORT_URI, anything, anything)
      .returns(
        Struct.new(:status, :body).new(
          200,
          %{ { "data": { "languages": [ { "language": "es" }, { "language": "de" }] } } },
        ),
      )
      .at_least_once
  end

  def expect_google_detect(locale)
    Excon
      .expects(:post)
      .with(DiscourseTranslator::Google::DETECT_URI, anything, anything)
      .returns(
        Struct.new(:status, :body).new(
          200,
          %{ { "data": { "detections": [ [ { "language": "#{locale}" } ] ] } } },
        ),
      )
      .once
  end

  def expect_google_translate(text)
    Excon
      .expects(:post)
      .with(DiscourseTranslator::Google::TRANSLATE_URI, body: anything, headers: anything)
      .returns(
        Struct.new(:status, :body).new(
          200,
          %{ { "data": { "translations": [ { "translatedText": "#{text}" } ] } } },
        ),
      )
  end

  describe "backfilling" do
    it "does not backfill if translator is disabled" do
      SiteSetting.translator_enabled = false
      expect_any_instance_of(Jobs::AutomaticTranslationBackfill).not_to receive(:process_batch)
      described_class.new.execute
    end

    it "does not backfill if backfill languages are not set" do
      SiteSetting.automatic_translation_target_languages = ""
      expect_any_instance_of(Jobs::AutomaticTranslationBackfill).not_to receive(:process_batch)
      described_class.new.execute
    end

    it "does not backfill if backfill limit is set to 0" do
      SiteSetting.automatic_translation_target_languages = "de"
      SiteSetting.automatic_translation_backfill_maximum_translations_per_hour = 0
      expect_any_instance_of(Jobs::AutomaticTranslationBackfill).not_to receive(:process_batch)
    end

    it "does not backfill if backfill lock is not secure" do
      SiteSetting.automatic_translation_target_languages = "de"
      SiteSetting.automatic_translation_backfill_maximum_translations_per_hour = 1
      Discourse.redis.set("discourse_translator_backfill_lock", "1")
      expect_any_instance_of(Jobs::AutomaticTranslationBackfill).not_to receive(:translate_records)
    end

    describe "with two locales ['de', 'es']" do
      before do
        SiteSetting.automatic_translation_target_languages = "de|es"
        SiteSetting.automatic_translation_backfill_maximum_translations_per_hour = 100
        expect_google_check_language
      end

      it "backfills if topic is not in target languages" do
        expect_google_detect("de")
        expect_google_translate("hola")
        topic = Fabricate(:topic)

        described_class.new.execute

        expect(topic.translations.pluck(:locale, :translation)).to eq([%w[es hola]])
      end

      it "backfills both topics and posts" do
        post = Fabricate(:post)
        topic = post.topic

        topic.set_detected_locale("de")
        post.set_detected_locale("es")

        expect_google_translate("hallo")
        expect_google_translate("hola")

        described_class.new.execute

        expect(topic.translations.pluck(:locale, :translation)).to eq([%w[es hola]])
        expect(post.translations.pluck(:locale, :translation)).to eq([%w[de hallo]])
      end
    end

    describe "with just one locale ['de']" do
      before do
        SiteSetting.automatic_translation_target_languages = "de"
        SiteSetting.automatic_translation_backfill_maximum_translations_per_hour = 5 * 12
        expect_google_check_language
      end

      it "backfills all (1) topics and (4) posts as it is within the maximum per job run" do
        topic = Fabricate(:topic)
        posts = Fabricate.times(4, :post, topic: topic)

        topic.set_detected_locale("es")
        posts.each { |p| p.set_detected_locale("es") }

        expect_google_translate("hallo").times(5)

        described_class.new.execute

        expect(topic.translations.pluck(:locale, :translation)).to eq([%w[de hallo]])
        expect(posts.map { |p| p.translations.pluck(:locale, :translation).flatten }).to eq(
          [%w[de hallo]] * 4,
        )
      end
    end
  end

  describe ".fetch_untranslated_model_ids" do
    fab!(:posts_1) { Fabricate.times(2, :post) }
    fab!(:post_1) { Fabricate(:post) }
    fab!(:post_2) { Fabricate(:post) }
    fab!(:post_3) { Fabricate(:post) }
    fab!(:posts_2) { Fabricate.times(2, :post) }
    fab!(:post_4) { Fabricate(:post) }
    fab!(:post_5) { Fabricate(:post) }
    fab!(:post_6) { Fabricate(:post) }
    fab!(:post_7) { Fabricate(:post) }
    fab!(:posts_3) { Fabricate.times(2, :post) }

    before do
=begin
This is the scenario we are testing for:
    | Post ID | detected_locale | translations | selected? | Why? |
    |---------|-----------------|--------------|-----------|------|
    |   1     | en              | none         | YES       | source not de/es, needs both translations
    |   2     | es              | none         | YES       | source is es, but missing de translation
    |   3     | null            | es           | YES       | missing de translation
    |   4     | null            | de, es       | NO        | has both de and es translations
    |   5     | de              | es           | NO        | source is de and has es translation
    |   6     | de              | de           | YES       | both source and translation is de, missing es translation
    |   7     | de              | ja           | YES       | source is de, missing es translation
=end

      [posts_1, posts_2, posts_3].flatten.each do |post|
        post.set_translation("es", "hola")
        post.set_translation("de", "hallo")
      end

      post_1.set_detected_locale("en")
      post_2.set_detected_locale("es")
      post_5.set_detected_locale("de")
      post_6.set_detected_locale("de")
      post_7.set_detected_locale("de")

      post_3.set_translation("es", "hola")
      post_4.set_translation("de", "hallo")
      post_4.set_translation("es", "hola")
      post_5.set_translation("es", "hola")
      post_6.set_translation("de", "hallo")
      post_7.set_translation("ja", "こんにちは")
    end

    it "returns correct post ids needing translation in descending id" do
      result = described_class.new.fetch_untranslated_model_ids(Post, "cooked", 50, %w[de es])
      expect(result).to include(post_7.id, post_6.id, post_3.id, post_2.id, post_1.id)
    end

    it "does not return posts that are deleted" do
      post_1.trash!
      result = described_class.new.fetch_untranslated_model_ids(Post, "cooked", 50, %w[de es])
      expect(result).not_to include(post_1.id)
    end

    it "does not return posts that are empty" do
      post_1.cooked = ""
      post_1.save!(validate: false)
      result = described_class.new.fetch_untranslated_model_ids(Post, "cooked", 50, %w[de es])
      expect(result).not_to include(post_1.id)
    end

    it "does not return posts by bots" do
      post_1.update(user: Discourse.system_user)

      result = described_class.new.fetch_untranslated_model_ids(Post, "cooked", 50, %w[de es])

      expect(result).not_to include(post_1.id)
    end
  end
end
