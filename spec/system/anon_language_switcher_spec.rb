# frozen_string_literal: true

RSpec.describe "Anonymous user language switcher", type: :system do
  fab!(:japanese_user) { Fabricate(:user, locale: "ja") }

  it "shows the correct language based on the selected language and login status" do
    SWITCHER_SELECTOR = "button[data-identifier='discourse-translator_language-switcher']"

    visit("/")
    expect(page).not_to have_css(SWITCHER_SELECTOR)

    SiteSetting.translator_enabled = true
    SiteSetting.allow_user_locale = true
    SiteSetting.set_locale_from_cookie = true
    SiteSetting.automatic_translation_backfill_maximum_translations_per_hour = 1
    SiteSetting.automatic_translation_target_languages = "es|ja"
    SiteSetting.experimental_anon_language_switcher = true
    visit("/")
    expect(page).to have_css(SWITCHER_SELECTOR)
    expect(find(".nav-item_latest")).to have_content("Latest")

    switcher = PageObjects::Components::DMenu.new(SWITCHER_SELECTOR)
    switcher.expand
    expect(switcher).to have_content("日本語")

    SiteSetting.automatic_translation_target_languages = "es"
    SiteSetting.experimental_anon_language_switcher = true
    visit("/")

    switcher.expand
    expect(switcher).not_to have_content("日本語")
    switcher.click_button("Español")
    expect(find(".nav-item_latest")).to have_content("Recientes")

    sign_in(japanese_user)
    visit("/")
    expect(find(".nav-item_latest")).to have_content("最新")
  end
end
