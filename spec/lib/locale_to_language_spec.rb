# frozen_string_literal: true

describe DiscourseTranslator::LocaleToLanguage do
  describe ".get_language" do
    it "returns the language name for a valid locale" do
      expect(DiscourseTranslator::LocaleToLanguage.get_language("en")).to eq("English (US)")
      expect(DiscourseTranslator::LocaleToLanguage.get_language("es")).to eq("Español")
    end

    it "returns nil for a locale that doesn't exist" do
      expect(DiscourseTranslator::LocaleToLanguage.get_language("xx")).to be_nil
    end

    it "handles symbol locales" do
      expect(DiscourseTranslator::LocaleToLanguage.get_language(:en_GB)).to eq("English (UK)")
    end
  end
end
