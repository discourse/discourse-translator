# frozen_string_literal: true

require "rails_helper"

describe TopicViewSerializer do
  fab!(:topic)

  before do
    SiteSetting.translator_enabled = true
    SiteSetting.restrict_translation_by_group = "#{Group::AUTO_GROUPS[:everyone]}"
    SiteSetting.restrict_translation_by_poster_group = "#{Group::AUTO_GROUPS[:everyone]}"
  end

  describe "preloading" do
    fab!(:user)
    fab!(:en_post) do
      post = Fabricate(:post, topic: topic)
      post.set_detected_locale("en")
      post
    end
    fab!(:es_post) do
      post = Fabricate(:post, topic: topic)
      post.set_detected_locale("es")
      post
    end
    fab!(:ja_post) do
      post = Fabricate(:post, topic: topic)
      post.set_detected_locale("ja")
      post
    end

    it "always preloads locale without N+1 queries" do
      topic_view = TopicView.new(topic)
      serializer = TopicViewSerializer.new(topic_view, scope: Guardian.new(user), root: false)

      json = {}
      queries = track_sql_queries { json = serializer.as_json }
      expect(json[:post_stream][:posts].map { |p| p[:can_translate] }).to eq([false, true, true])

      translation_queries = queries.count { |q| q.include?("discourse_translator_post_locales") }
      expect(translation_queries).to eq(1) # would be 3 (posts) if not preloaded

      expect(topic_view.posts.first.association(:content_locale)).to be_loaded
    end

    it "never preloads translations if SiteSetting.experimental_inline_translations is false" do
      SiteSetting.experimental_inline_translation = false

      topic_view = TopicView.new(topic)
      serializer = TopicViewSerializer.new(topic_view, scope: Guardian.new(user), root: false)

      queries = track_sql_queries { serializer.as_json }
      translation_queries =
        queries.count { |q| q.include?("discourse_translator_post_translations") }
      expect(translation_queries).to eq(0)
    end

    describe "SiteSetting.experimental_inline_translations enabled with target language 'es'" do
      before do
        SiteSetting.experimental_inline_translation = true

        SiteSetting.automatic_translation_backfill_rate = 1
        SiteSetting.automatic_translation_target_languages = "es"

        SiteSetting.default_locale = "en"
        en_post.set_translation("es", "Hola")
        en_post.set_translation("ja", "こんにちは")
        es_post.set_translation("en", "Hello")
      end

      it "does not preload translations when user locale matches site default locale as we assume most posts are written in default locale" do
        SiteSetting.default_locale = "en"
        I18n.locale = "en"

        topic_view = TopicView.new(topic)
        serializer = TopicViewSerializer.new(topic_view, scope: Guardian.new(user), root: false)

        queries = track_sql_queries { serializer.as_json }
        # has to manually load the es and ja post
        expect(queries.count { |q| q.include?("discourse_translator_post_translations") }).to eq(2)
      end

      it "does not preload translations when user locale is not site default and not in automatic_translation_target_languages" do
        SiteSetting.default_locale = "en"
        I18n.locale = "de"

        topic_view = TopicView.new(topic)
        serializer = TopicViewSerializer.new(topic_view, scope: Guardian.new(user), root: false)

        queries = track_sql_queries { serializer.as_json }

        # english post is not loaded
        expect(topic_view.posts.first.user_id).to eq en_post.user_id
        expect(topic_view.posts.first.association(:translations)).not_to be_loaded
        expect(queries.count { |q| q.include?("discourse_translator_post_translations") }).to eq(2)
      end

      it "preloads translations when locales are different and in automatic_translation_target_languages" do
        SiteSetting.default_locale = "en"
        I18n.locale = "es"

        topic_view = TopicView.new(topic)
        serializer = TopicViewSerializer.new(topic_view, scope: Guardian.new(user), root: false)

        topic_view.posts.reload

        queries = track_sql_queries { serializer.as_json }

        expect(queries.count { |q| q.include?("discourse_translator_post_translations") }).to eq(1)
        expect(topic_view.posts.first.association(:translations)).to be_loaded
      end
    end
  end

  describe "Inline translations" do
    describe "#fancy_title" do
      fab!(:user) { Fabricate(:user, locale: "ja") }

      let!(:original_title) { "<h1>FUS ROH DAAHHH</h1>" }
      let!(:jap_title) { "<h1>フス・ロ・ダ・ア</h1>" }

      before do
        topic.title = original_title
        SiteSetting.experimental_inline_translation = true
        I18n.locale = "en"
      end

      def serialize_topic(guardian_user: user, cookie: "")
        env = create_request_env.merge("HTTP_COOKIE" => cookie)
        request = ActionDispatch::Request.new(env)
        guardian = Guardian.new(guardian_user, request)
        TopicViewSerializer.new(TopicView.new(topic), scope: guardian)
      end

      it "does not replace fancy_title with translation when experimental_inline_translation is disabled" do
        SiteSetting.experimental_inline_translation = false
        topic.set_translation("ja", jap_title)

        expect(serialize_topic.fancy_title).to eq(topic.fancy_title)
      end

      it "does not replace fancy_title with translation when show_original param is present" do
        topic.set_translation("ja", jap_title)
        expect(
          serialize_topic(
            cookie: DiscourseTranslator::InlineTranslation::SHOW_ORIGINAL_COOKIE,
          ).fancy_title,
        ).to eq(topic.fancy_title)
      end

      it "does not replace fancy_title with translation when no translation exists" do
        expect(serialize_topic.fancy_title).to eq(topic.fancy_title)
      end

      it "does not replace fancy_title when topic is already in correct locale" do
        I18n.locale = "ja"
        topic.set_detected_locale("ja")
        topic.set_translation("ja", jap_title)

        expect(serialize_topic.fancy_title).to eq(topic.fancy_title)
      end

      it "returns translated title in fancy_title when translation exists for current locale" do
        I18n.locale = "ja"
        SiteSetting.automatic_translation_backfill_rate = 1
        SiteSetting.automatic_translation_target_languages = "ja"
        topic.set_translation("ja", jap_title)
        expect(serialize_topic.fancy_title).to eq("&lt;h1&gt;フス・ロ・ダ・ア&lt;/h1&gt;")
      end
    end

    describe "#show_translation_toggle" do
      fab!(:user)
      fab!(:post_1) { Fabricate(:post, topic:) }
      fab!(:post_2) { Fabricate(:post, topic:) }

      before do
        SiteSetting.automatic_translation_backfill_rate = 1
        SiteSetting.automatic_translation_target_languages = "ja"
      end

      def serialize_topic(guardian_user: user)
        TopicViewSerializer.new(TopicView.new(topic), scope: Guardian.new(guardian_user))
      end

      it "returns depending on translator disabled or experimental inline translation disabled" do
        I18n.locale = "ja"
        topic.set_translation("ja", "こんにちは")

        SiteSetting.translator_enabled = false
        SiteSetting.experimental_inline_translation = false
        expect(serialize_topic.show_translation_toggle).to eq(false)

        SiteSetting.translator_enabled = true
        SiteSetting.experimental_inline_translation = false
        expect(serialize_topic.show_translation_toggle).to eq(false)

        SiteSetting.translator_enabled = true
        SiteSetting.experimental_inline_translation = true
        expect(serialize_topic.show_translation_toggle).to eq(true)
      end

      it "returns true when there is translation for the topic" do
        SiteSetting.translator_enabled = true
        SiteSetting.experimental_inline_translation = true
        I18n.locale = "ja"
        topic.set_translation("ja", "こんにちは")

        expect(serialize_topic.show_translation_toggle).to eq(true)
      end
    end
  end
end
