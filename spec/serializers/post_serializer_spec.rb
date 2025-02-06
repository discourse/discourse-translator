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
      before { SiteSetting.translator_enabled = true }

      describe "anon user" do
        let(:serializer) { PostSerializer.new(post, scope: Guardian.new) }

        before do
          SiteSetting.restrict_translation_by_group = "#{Group::AUTO_GROUPS[:everyone]}"
          SiteSetting.restrict_translation_by_poster_group = ""
        end

        it "cannot translate" do
          expect(serializer.can_translate).to eq(false)
        end
      end

      describe "logged in user" do
        let(:serializer) { PostSerializer.new(post, scope: Guardian.new(user)) }

        it "cannot translate when user is not in restrict_translation_by_group" do
          SiteSetting.restrict_translation_by_group = "#{group.id + 1}"

          expect(serializer.can_translate).to eq(false)
        end

        describe "user is in restrict_translation_by_group" do
          before { SiteSetting.restrict_translation_by_group = "#{group.id}" }

          it "cannot translate when post author is not in restrict_translation_by_poster_group" do
            SiteSetting.restrict_translation_by_poster_group = "#{group.id}"

            expect(serializer.can_translate).to eq(false)
          end

          describe "post author in restrict_translation_by_poster_group and locale is :xx" do
            before do
              SiteSetting.restrict_translation_by_poster_group = "#{post_user_group.id}"
              I18n.stubs(:locale).returns(:pt)
            end

            it "cannot translate when post does not have DETECTED_LANG_CUSTOM_FIELD" do
              expect(serializer.can_translate).to eq(false)
            end

            it "cannot translate when post has DETECTED_LANG_CUSTOM_FIELD matches locale" do
              post.set_detected_locale("pt")

              expect(serializer.can_translate).to eq(false)
            end

            it "can translate when post has DETECTED_LANG_CUSTOM_FIELD does not match locale" do
              post.set_detected_locale("jp")

              expect(serializer.can_translate).to eq(true)
            end
          end
        end
      end
    end
  end
end
