# frozen_string_literal: true

require "rails_helper"

describe Jobs::TranslateCategories do
  subject(:job) { described_class.new }

  let(:translator) { mock }

  def localize_all_categories(*locales)
    Category.all.each do |category|
      locales.each { |locale| Fabricate(:category_localization, category:, locale:, name: "x") }
    end
  end

  before do
    SiteSetting.translator_enabled = true
    SiteSetting.experimental_category_translation = true
    SiteSetting.automatic_translation_backfill_rate = 100
    SiteSetting.automatic_translation_target_languages = "pt|zh_CN"

    DiscourseTranslator::Provider.stubs(:get).returns(translator)
    Jobs.run_immediately!
  end

  it "does nothing when translator is disabled" do
    SiteSetting.translator_enabled = false

    translator.expects(:translate_text!).never

    job.execute({})
  end

  it "does nothing when experimental_category_translation is disabled" do
    SiteSetting.experimental_category_translation = false

    translator.expects(:translate_text!).never

    job.execute({})
  end

  it "does nothing when no target languages are configured" do
    SiteSetting.automatic_translation_target_languages = ""

    translator.expects(:translate_text!).never

    job.execute({})
  end

  it "does nothing when no categories exist" do
    Category.destroy_all

    translator.expects(:translate_text!).never

    job.execute({})
  end

  it "translates categories to the configured locales" do
    number_of_categories = Category.count
    DiscourseTranslator::CategoryTranslator
      .expects(:translate)
      .with(is_a(Category), "pt")
      .times(number_of_categories)
    DiscourseTranslator::CategoryTranslator
      .expects(:translate)
      .with(is_a(Category), "zh_CN")
      .times(number_of_categories)

    job.execute({})
  end

  it "skips categories that already have localizations" do
    localize_all_categories("pt", "zh_CN")

    category1 =
      Fabricate(:category, name: "First Category", description: "First category description")
    Fabricate(:category_localization, category: category1, locale: "pt", name: "Primeira Categoria")

    # It should only translate to Chinese, not Portuguese
    DiscourseTranslator::CategoryTranslator.expects(:translate).with(category1, "pt").never
    DiscourseTranslator::CategoryTranslator.expects(:translate).with(category1, "zh_CN").once

    job.execute({})
  end

  it "continues from a specified category ID" do
    category1 = Fabricate(:category, name: "First", description: "First description")
    category2 = Fabricate(:category, name: "Second", description: "Second description")

    DiscourseTranslator::CategoryTranslator
      .expects(:translate)
      .with(category1, any_parameters)
      .never
    DiscourseTranslator::CategoryTranslator
      .expects(:translate)
      .with(category2, any_parameters)
      .twice

    job.execute(from_category_id: category2.id)
  end

  it "handles translation errors gracefully" do
    localize_all_categories("pt", "zh_CN")

    category1 = Fabricate(:category, name: "First", description: "First description")
    DiscourseTranslator::CategoryTranslator
      .expects(:translate)
      .with(category1, "pt")
      .raises(StandardError.new("API error"))
    DiscourseTranslator::CategoryTranslator.expects(:translate).with(category1, "zh_CN").once

    expect { job.execute({}) }.not_to raise_error
  end

  it "enqueues the next batch when there are more categories" do
    Jobs::TranslateCategories.const_set(:BATCH_SIZE, 1)

    Jobs
      .expects(:enqueue_in)
      .with(10.seconds, :translate_categories, from_category_id: any_parameters)
      .times(Category.count)

    job.execute({})

    # Reset the constant
    Jobs::TranslateCategories.send(:remove_const, :BATCH_SIZE)
    Jobs::TranslateCategories.const_set(:BATCH_SIZE, 50)
  end
end
