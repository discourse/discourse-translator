# frozen_string_literal: true

RSpec.describe "Inline translation", type: :system do
  fab!(:japanese_user) { Fabricate(:user, locale: "ja") }
  fab!(:site_local_user) { Fabricate(:user, locale: "en") }
  fab!(:author) { Fabricate(:user) }

  fab!(:topic) { Fabricate(:topic, title: "Life strategies from The Art of War", user: author) }
  fab!(:post_1) do
    Fabricate(:post, topic: topic, raw: "The masterpiece isn’t just about military strategy")
  end
  fab!(:post_2) do
    Fabricate(:post, topic: topic, raw: "The greatest victory is that which requires no battle")
  end

  let(:topic_page) { PageObjects::Pages::Topic.new }
  let(:topic_list) { PageObjects::Components::TopicList.new }

  before do
    # topic translation setup
    topic.set_detected_locale("en")
    post_1.set_detected_locale("en")
    post_2.set_detected_locale("en")

    topic.set_translation("ja", "孫子兵法からの人生戦略")
    topic.set_translation("es", "Estrategias de vida de El arte de la guerra")
    post_1.set_translation("ja", "傑作は単なる軍事戦略についてではありません")
    post_2.set_translation("ja", "最大の勝利は戦いを必要としないものです")
  end

  context "when the feature is enabled" do
    before do
      SiteSetting.translator_enabled = true
      SiteSetting.allow_user_locale = true
      SiteSetting.set_locale_from_cookie = true
      SiteSetting.set_locale_from_param = true
      SiteSetting.experimental_inline_translation = true
      SiteSetting.automatic_translation_backfill_rate = 1
      SiteSetting.automatic_translation_target_languages = "ja"
    end

    it "shows the correct language based on the selected language and login status" do
      visit("/t/#{topic.slug}/#{topic.id}?lang=ja")
      expect(topic_page.has_topic_title?("孫子兵法からの人生戦略")).to eq(true)
      expect(find(topic_page.post_by_number_selector(1))).to have_content("傑作は単なる軍事戦略についてではありません")

      visit("/t/#{topic.id}")
      expect(topic_page.has_topic_title?("Life strategies from The Art of War")).to eq(true)
      expect(find(topic_page.post_by_number_selector(1))).to have_content(
        "The masterpiece isn’t just about military strategy",
      )

      sign_in(japanese_user)
      visit("/")
      visit("/t/#{topic.id}")
      expect(topic_page.has_topic_title?("孫子兵法からの人生戦略")).to eq(true)
    end

    it "shows original content when 'Show Original' is selected" do
      sign_in(japanese_user)

      visit("/")
      topic_list.visit_topic_with_title("孫子兵法からの人生戦略")

      expect(topic_page.has_topic_title?("孫子兵法からの人生戦略")).to eq(true)
      page.find(".discourse-translator_toggle-original button").click

      expect(topic_page.has_topic_title?("Life strategies from The Art of War")).to eq(true)

      visit("/")
      topic_list.visit_topic_with_title("Life strategies from The Art of War")
    end
  end
end
