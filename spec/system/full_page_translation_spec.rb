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

  def create_new_post_with_jap_translation
    post =
      Fabricate(:post, topic: topic, raw: "The greatest victory is that which requires no battle")
    post.set_detected_locale("en")
    post.set_translation("ja", "最大の勝利は戦いを必要としないものです")
  end

  before do
    # topic translation setup
    topic.set_detected_locale("en")
    post_1.set_detected_locale("en")
    post_2.set_detected_locale("en")

    topic.set_translation("ja", "孫子兵法からの人生戦略")
    topic.set_translation("es", "Estrategias de vida de El arte de la guerra")
    post_1.set_translation("ja", "傑作は単なる軍事戦略についてではありません")
    post_2.set_translation("ja", "最大の勝利は戦いを必要としないものです")
    Jobs.run_immediately!
  end

  context "when the feature is enabled" do
    before do
      SiteSetting.translator_enabled = true
      SiteSetting.translator_provider = "Google"
      SiteSetting.translator_google_api_key = "api_key"
      SiteSetting.experimental_inline_translation = true

      SiteSetting.allow_user_locale = true
      SiteSetting.set_locale_from_cookie = true
      SiteSetting.set_locale_from_param = true
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

      # creating a new post with translation
      # for the new post to show up translated
      post =
        PostCreator.create!(
          site_local_user,
          topic_id: topic.id,
          raw: "You need not fear the result of a hundred battles.",
          skip_guardian: true,
        )
      post.set_detected_locale("en")
      post.set_translation("ja", "彼を知り己を知れば、百戦して危うからず。")

      expect(find(topic_page.post_by_number_selector(3))).to have_content("彼を知り己を知れば、百戦して危うからず。")
    end

    it "is mindful of 'show original'" do
      sign_in(japanese_user)

      visit("/t/#{topic.id}")
      expect(topic_page.has_topic_title?("孫子兵法からの人生戦略")).to eq(true)

      page.find(".discourse-translator_toggle-original button").click
      expect(page).to have_current_path(/.*show=original.*/)

      expect(topic_page.has_topic_title?("Life strategies from The Art of War")).to eq(true)
      expect(find(topic_page.post_by_number_selector(1))).to have_content(
        "The masterpiece isn’t just about military strategy",
      )

      # creating a new post with translation
      # for the new post to show up translated
      stub_request(:post, DiscourseTranslator::Google::SUPPORT_URI).to_return(
        status: 200,
        body: %{ { "data": { "languages": [ { "language": "en" }] } } },
      )
      stub_request(:post, DiscourseTranslator::Google::DETECT_URI).to_return(
        status: 200,
        body: %{ { "data": { "detections": [ [ { "language": "en" } ] ] } } },
      )
      stub_request(:post, DiscourseTranslator::Google::TRANSLATE_URI).to_return(
        status: 200,
        body: %{ { "data": { "translations": [ { "translatedText": "should not appear" } ] } } },
      )
      post =
        PostCreator.create!(
          site_local_user,
          topic_id: topic.id,
          raw: "You need not fear the result of a hundred battles.",
          skip_guardian: true,
        )
      expect(find(topic_page.post_by_number_selector(3))).to have_content("should not appear")
      expect(find(topic_page.post_by_number_selector(3))).to have_content(
        "You need not fear the result of a hundred battles.",
      )
    end
  end
end
