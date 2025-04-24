# frozen_string_literal: true

describe DiscourseTranslator::CategoryTranslator do
  fab!(:category) do
    Fabricate(:category, name: "Test Category", description: "This is a test category")
  end

  describe ".translate" do
    let(:target_locale) { :fr }
    let(:translator) { mock }

    before { DiscourseTranslator::Provider::TranslatorProvider.stubs(:get).returns(translator) }

    it "translates the category name and description" do
      translator
        .expects(:translate_text!)
        .with(category.name, target_locale)
        .returns("Catégorie de Test")
      translator
        .expects(:translate_text!)
        .with(category.description, target_locale)
        .returns("C'est une catégorie de test")

      res = DiscourseTranslator::CategoryTranslator.translate(category, target_locale)

      expect(res.name).to eq("Catégorie de Test")
      expect(res.description).to eq("C'est une catégorie de test")
    end

    it "translates the category name and description" do
      localized =
        Fabricate(
          :category_localization,
          category: category,
          locale: target_locale,
          name: "X",
          description: "Y",
        )
      translator
        .expects(:translate_text!)
        .with(category.name, target_locale)
        .returns("Catégorie de Test")
      translator
        .expects(:translate_text!)
        .with(category.description, target_locale)
        .returns("C'est une catégorie de test")

      DiscourseTranslator::CategoryTranslator.translate(category, target_locale)

      localized.reload
      expect(localized.name).to eq("Catégorie de Test")
      expect(localized.description).to eq("C'est une catégorie de test")
    end

    it "handles locale format standardization" do
      translator.expects(:translate_text!).with(category.name, :fr).returns("Catégorie de Test")
      translator
        .expects(:translate_text!)
        .with(category.description, :fr)
        .returns("C'est une catégorie de test")

      res = DiscourseTranslator::CategoryTranslator.translate(category, "fr")

      expect(res.name).to eq("Catégorie de Test")
      expect(res.description).to eq("C'est une catégorie de test")
    end

    it "returns nil if category is blank" do
      expect(DiscourseTranslator::CategoryTranslator.translate(nil)).to be_nil
    end

    it "returns nil if target locale is blank" do
      expect(DiscourseTranslator::CategoryTranslator.translate(category, nil)).to be_nil
    end

    it "uses I18n.locale as default when no target locale is provided" do
      I18n.locale = :es
      translator.expects(:translate_text!).with(category.name, :es).returns("Categoría de Prueba")
      translator
        .expects(:translate_text!)
        .with(category.description, :es)
        .returns("Esta es una categoría de prueba")

      res = DiscourseTranslator::CategoryTranslator.translate(category)

      expect(res.name).to eq("Categoría de Prueba")
      expect(res.description).to eq("Esta es una categoría de prueba")
      expect(res.locale).to eq("es")
    end
  end
end
