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

  describe "with Spanish and Japanese" do
    before do
      SiteSetting.automatic_translation_target_languages = "es|ja"
      SiteSetting.experimental_anon_language_switcher = true
      SiteSetting.experimental_inline_translation = true

      topic.set_detected_locale("en")
      topic.set_translation("ja", "孫子兵法からの人生戦略")
      topic.set_translation("es", "Estrategias de vida de El arte de la guerra")
    end

    it "shows the correct language based on the selected language and login status" do
      visit("/")
      expect(find(".nav-item_latest")).to have_content("Latest")

      switcher.expand
      switcher.click_button("Español")
      expect(find(".nav-item_latest")).to have_content("Recientes")

      sign_in(japanese_user)
      visit("/")
      expect(find(".nav-item_latest")).to have_content("最新")
    end

    it "shows the most recently selected language" do
      visit("/")

      switcher.expand
      switcher.click_button("Español")
      expect(find(".nav-item_latest")).to have_content("Recientes")

      topic_page.visit_topic(topic)
      topic_page.has_topic_title?("Estrategias de vida de El arte de la guerra")

      switcher.expand
      switcher.click_button("日本語")
      topic_page.visit_topic(topic)
      topic_page.has_topic_title?("孫子兵法からの人生戦略")

      visit("/")
      expect(find(".nav-item_latest")).to have_content("最新")
    end
  end
end
