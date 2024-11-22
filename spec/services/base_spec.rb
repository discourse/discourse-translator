# frozen_string_literal: true

require "rails_helper"

describe DiscourseTranslator::Base do
  class TestTranslator < DiscourseTranslator::Base
    SUPPORTED_LANG_MAPPING = { en: "en", ar: "ar", es_MX: "es-MX", pt: "pt" }
  end

  class EmptyTranslator < DiscourseTranslator::Base
  end

  describe ".language_supported?" do
    it "raises an error when the method is not implemented" do
      expect { EmptyTranslator.language_supported?("en") }.to raise_error(NotImplementedError)
    end

    it "returns false when the locale is not supported" do
      I18n.stubs(:locale).returns(:xx)
      expect(TestTranslator.language_supported?("en")).to eq(false)
    end

    it "returns true when the detected language is not the current locale" do
      I18n.locale = :pt
      expect(TestTranslator.language_supported?("en")).to eq(true)
      expect(TestTranslator.language_supported?("ar")).to eq(true)
      expect(TestTranslator.language_supported?("es-MX")).to eq(true)
    end

    it "returns false when the detected language is the detected locale" do
      I18n.locale = :pt
      expect(TestTranslator.language_supported?("pt")).to eq(false)
    end
  end
end
