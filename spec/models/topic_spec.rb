# frozen_string_literal: true

require "rails_helper"

describe Topic do
  describe "translatable" do
    fab!(:topic)

    before { SiteSetting.translator_enabled = true }

    it "should reset translation data when topic fancy_title has been updated" do
      Fabricate(:topic_translation, topic:)
      Fabricate(:topic_locale, topic:)
      topic.update!(fancy_title: "this is an updated title")

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

    describe "#locale_matches?" do
      it "returns false when detected locale is blank" do
        expect(topic.locale_matches?("en-US")).to eq(false)
      end

      it "returns false when locale is blank" do
        topic.set_detected_locale("en-US")
        expect(topic.locale_matches?(nil)).to eq(false)
      end

      [:en, "en", "en-US", :en_US, "en-GB", "en_GB", :en_GB].each do |locale|
        it "returns true when matching normalised #{locale} to \"en\"" do
          topic.set_detected_locale("en")
          expect(topic.locale_matches?(locale)).to eq(true)
        end
      end

      ["en-GB", "en_GB", :en_GB].each do |locale|
        it "returns true when matching #{locale} to \"en_GB\"" do
          topic.set_detected_locale("en_GB")
          expect(topic.locale_matches?(locale, normalise_region: false)).to eq(true)
        end
      end

      [:en, "en", "en-US", :en_US].each do |locale|
        it "returns false when matching #{locale} to \"en_GB\"" do
          topic.set_detected_locale("en_GB")
          expect(topic.locale_matches?(locale, normalise_region: false)).to eq(false)
        end
      end
    end
  end
end
