# frozen_string_literal: true

require_relative "../../db/migrate/20250210171147_hyphenate_translator_locales"

module DiscourseTranslator
  describe HyphenateTranslatorLocales do
    let(:migration) { described_class.new }

    it "normalizes underscores to dashes in all translator tables" do
      topic = Fabricate(:topic)
      post = Fabricate(:post, topic: topic)

      DiscourseTranslator::TopicTranslation.create!(topic:, locale: "en_GB", translation: "test")
      DiscourseTranslator::PostTranslation.create!(post:, locale: "fr_CA", translation: "test")
      DiscourseTranslator::TopicLocale.create!(topic:, detected_locale: "es_MX")
      DiscourseTranslator::PostLocale.create!(post:, detected_locale: "pt_BR")

      migration.up

      expect(DiscourseTranslator::TopicTranslation.last.locale).to eq("en-GB")
      expect(DiscourseTranslator::PostTranslation.last.locale).to eq("fr-CA")
      expect(DiscourseTranslator::TopicLocale.last.detected_locale).to eq("es-MX")
      expect(DiscourseTranslator::PostLocale.last.detected_locale).to eq("pt-BR")
    end

    it "handles multiple batches" do
      described_class.const_set(:BATCH_SIZE, 2)

      topic = Fabricate(:topic)
      post = Fabricate(:post, topic: topic)

      5.times { |i| post.set_translation("en_#{i}", "test#{i}") }
      5.times { |i| post.set_translation("en-#{i + 10}", "test#{i}") }
      5.times { |i| post.set_translation("en_#{i + 20}", "test#{i}") }

      migration.up

      locales = DiscourseTranslator::PostTranslation.pluck(:locale)
      expect(locales).to all(match(/\A[a-z]+-\d+\z/))
      expect(locales).not_to include(match(/_/))
    end

    it "only updates records containing underscores" do
      topic = Fabricate(:topic)

      topic.set_translation("en_GB", "test")
      DiscourseTranslator::TopicTranslation.create!(
        topic: topic,
        locale: "fr_CA",
        translation: "test2",
      )

      expect { migration.up }.to change {
        DiscourseTranslator::TopicTranslation.where("locale LIKE ? ESCAPE '\\'", "%\\_%").count
      }.from(1).to(0)

      expect(DiscourseTranslator::TopicTranslation.pluck(:locale)).to contain_exactly(
        "en-GB",
        "fr-CA",
      )
    end
  end
end
