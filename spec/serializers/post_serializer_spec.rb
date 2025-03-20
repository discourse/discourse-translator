# frozen_string_literal: true

require "rails_helper"

RSpec.describe PostSerializer do
  fab!(:group)
  fab!(:user) { Fabricate(:user, locale: "en", groups: [group]) }

  fab!(:post_user_group) { Fabricate(:group) }
  fab!(:post_user) { Fabricate(:user, locale: "en", groups: [post_user_group]) }
  fab!(:post) { Fabricate(:post, user: post_user) }

  describe "#can_translate" do
    it "returns false when translator disabled" do
      SiteSetting.translator_enabled = false
      serializer = PostSerializer.new(post, scope: Guardian.new)

      expect(serializer.can_translate).to eq(false)
    end

    describe "when translator enabled" do
      before do
        SiteSetting.translator_enabled = true
        SiteSetting.restrict_translation_by_group = "#{Group::AUTO_GROUPS[:everyone]}"
        SiteSetting.restrict_translation_by_poster_group = ""
      end
      let(:serializer) { PostSerializer.new(post, scope: Guardian.new) }

      it "cannot translate for anon" do
        expect(serializer.can_translate).to eq(false)
      end

      describe "logged in user" do
        let(:serializer) { PostSerializer.new(post, scope: Guardian.new(user)) }

        it "cannot translate when user is not in restrict_translation_by_group" do
          SiteSetting.restrict_translation_by_group = "#{group.id + 1}"

          expect(serializer.can_translate).to eq(false)
        end

        describe "user is in restrict_translation_by_group" do
          describe "post author in restrict_translation_by_poster_group and locale is :xx" do
            it "can translate when post detected locale does not match i18n locale" do
              SiteSetting.restrict_translation_by_group = "#{group.id}"
              SiteSetting.restrict_translation_by_poster_group = "#{post_user_group.id}"
              I18n.stubs(:locale).returns(:pt)

              post.set_detected_locale("jp")

              expect(serializer.can_translate).to eq(true)
            end
          end
        end
      end
    end
  end

  describe "#is_translated" do
    fab!(:post)

    it "returns false when translator disabled" do
      SiteSetting.translator_enabled = false
      serializer = PostSerializer.new(post, scope: Guardian.new)

      expect(serializer.is_translated).to eq(false)
    end

    it "returns false when experimental inline translation disabled" do
      SiteSetting.translator_enabled = true
      SiteSetting.experimental_inline_translation = false
      serializer = PostSerializer.new(post, scope: Guardian.new)

      expect(serializer.is_translated).to eq(false)
    end

    it "returns true when there is a translation for the user's locale in target languages" do
      SiteSetting.translator_enabled = true
      SiteSetting.experimental_inline_translation = true
      SiteSetting.automatic_translation_backfill_rate = 1
      SiteSetting.automatic_translation_target_languages = "ja"
      I18n.locale = "ja"
      post.set_detected_locale("en")
      post.set_translation("ja", "こんにちは")
      serializer = PostSerializer.new(post, scope: Guardian.new)

      expect(serializer.is_translated).to eq(true)
    end

    it "returns false when there is a translation for the user's locale not in target languages" do
      SiteSetting.translator_enabled = true
      SiteSetting.experimental_inline_translation = true
      SiteSetting.automatic_translation_backfill_rate = 1
      SiteSetting.automatic_translation_target_languages = "es"
      I18n.locale = "ja"
      post.set_detected_locale("en")
      post.set_translation("ja", "こんにちは")
      serializer = PostSerializer.new(post, scope: Guardian.new)

      expect(serializer.is_translated).to eq(false)
    end

    it "returns false when there is no translation for the current locale in target languages" do
      SiteSetting.translator_enabled = true
      SiteSetting.experimental_inline_translation = true
      SiteSetting.automatic_translation_backfill_rate = 1
      SiteSetting.automatic_translation_target_languages = "ja"
      I18n.locale = "ja"
      post.set_translation("es", "Hola")
      serializer = PostSerializer.new(post, scope: Guardian.new)

      expect(serializer.is_translated).to eq(false)
    end
  end

  describe "#cooked" do
    def serialize_post(guardian_user: user, params: {})
      env = { "action_dispatch.request.parameters" => params, "REQUEST_METHOD" => "GET" }
      request = ActionDispatch::Request.new(env)
      guardian = Guardian.new(guardian_user, request)
      PostSerializer.new(post, scope: guardian)
    end

    before do
      SiteSetting.translator_enabled = true
      SiteSetting.experimental_inline_translation = true
    end

    it "does not return translated_cooked when experimental_inline_translation is disabled" do
      SiteSetting.experimental_inline_translation = false
      expect(serialize_post.cooked).to eq(post.cooked)
    end

    it "does not return translated_cooked when show=original param is present" do
      I18n.locale = "ja"
      SiteSetting.automatic_translation_backfill_rate = 1
      SiteSetting.automatic_translation_target_languages = "ja"
      post.set_translation("ja", "こんにちは")

      expect(serialize_post(params: { "show" => "original" }).cooked).to eq(post.cooked)
      expect(serialize_post(params: { "show" => "derp" }).cooked).to eq("こんにちは")
    end

    it "does not return translated_cooked when post is already in correct locale" do
      I18n.locale = "ja"
      post.set_detected_locale("ja")
      post.set_translation("ja", "こんにちは")

      expect(serialize_post.cooked).to eq(post.cooked)
    end

    it "returns translated content based on locale presence in target languages" do
      SiteSetting.automatic_translation_backfill_rate = 1
      post.set_translation("ja", "こんにちは")
      post.set_translation("es", "Hola")
      I18n.locale = "ja"

      SiteSetting.automatic_translation_target_languages = "ja"
      expect(serialize_post.cooked).to eq("こんにちは")

      SiteSetting.automatic_translation_target_languages = "es"
      expect(serialize_post.cooked).to eq(post.cooked)
    end

    it "does not return translated_cooked when plugin is disabled" do
      SiteSetting.translator_enabled = false
      expect(serialize_post.cooked).to eq(post.cooked)
    end
  end
end
