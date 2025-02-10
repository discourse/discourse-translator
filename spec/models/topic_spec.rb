# frozen_string_literal: true

require "rails_helper"

describe Topic do
  describe "translatable" do
    fab!(:topic)

    before { SiteSetting.translator_enabled = true }

    it "should reset translation data when topic title has been updated" do
      Fabricate(:topic_translation, topic:)
      Fabricate(:topic_locale, topic:)
      topic.update!(title: "this is an updated title")

      expect(DiscourseTranslator::TopicLocale.where(topic:)).to be_empty
      expect(DiscourseTranslator::TopicLocale.find_by(topic:)).to be_nil
    end

    describe "#set_translation" do
      it "creates new translation" do
        topic.set_translation("en", "Hello")

        translation = topic.translations.find_by(locale: "en")
        expect(translation.translation).to eq("Hello")
      end

      it "updates existing translation" do
        topic.set_translation("en", "Hello")
        topic.set_translation("en", "Updated hello")

        expect(topic.translations.where(locale: "en").count).to eq(1)
        expect(topic.translation_for("en")).to eq("Updated hello")
      end

      it "converts underscore to hyphen in locale" do
        topic.set_translation("en_US", "Hello")

        expect(topic.translations.find_by(locale: "en-US")).to be_present
        expect(topic.translations.find_by(locale: "en_US")).to be_nil
      end
    end

    describe "#translation_for" do
      it "returns nil when translation doesn't exist" do
        expect(topic.translation_for("fr")).to be_nil
      end

      it "returns translation when it exists" do
        topic.set_translation("es", "Hola")
        expect(topic.translation_for("es")).to eq("Hola")
      end
    end

    describe "#set_locale" do
      it "creates new locale" do
        topic.set_detected_locale("en-US")
        expect(topic.content_locale.detected_locale).to eq("en-US")
      end

      it "converts underscore to hyphen" do
        topic.set_detected_locale("en_US")
        expect(topic.content_locale.detected_locale).to eq("en-US")
      end
    end
  end
end
