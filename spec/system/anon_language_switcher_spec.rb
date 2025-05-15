# frozen_string_literal: true

RSpec.describe "Anonymous user language switcher", type: :system do
  SWITCHER_SELECTOR = "button[data-identifier='discourse-translator_language-switcher']"

  let(:topic_page) { PageObjects::Pages::Topic.new }
  let(:switcher) { PageObjects::Components::DMenu.new(SWITCHER_SELECTOR) }

  fab!(:japanese_user) { Fabricate(:user, locale: "ja") }
  fab!(:topic) do
    topic = Fabricate(:topic, title: "Life strategies from The Art of War")
    Fabricate(:post, topic:)
    topic
  end

  before do
    SiteSetting.translator_enabled = true
    SiteSetting.allow_user_locale = true
    SiteSetting.set_locale_from_cookie = true
    SiteSetting.automatic_translation_backfill_rate = 1
  end

  it "only shows the language switcher based on what is in target languages" do
    SiteSetting.automatic_translation_target_languages = "es|ja"
    SiteSetting.experimental_anon_language_switcher = true
    visit("/")

    expect(page).to have_css(SWITCHER_SELECTOR)

    switcher.expand
    expect(switcher).to have_content("日本語")
    expect(switcher).to have_content("Español")

    SiteSetting.automatic_translation_target_languages = "es"
    visit("/")

    switcher.expand
    expect(switcher).not_to have_content("日本語")
  end
end
