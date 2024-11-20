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
      SiteSetting.translator_enabled = true
      serializer = PostSerializer.new(post, scope: Guardian.new)

      expect(serializer.can_translate).to eq(false)
    end

    describe "when translator enabled" do
      before do
        SiteSetting.translator_enabled = true
        Jobs.run_later!
      end

      describe "when small action post" do
        fab!(:small_action)
        let(:serializer) { PostSerializer.new(small_action, scope: Guardian.new) }

        it "cannot translate" do
          expect(serializer.can_translate).to eq(false)
        end
      end

      describe "when post raw is empty" do
        fab!(:empty_post) do
          empty_post = Fabricate.build(:post, raw: "")
          empty_post.save!(validate: false)
          empty_post
        end
        let(:serializer) { PostSerializer.new(empty_post, scope: Guardian.new) }

        it "cannot translate" do
          expect(serializer.can_translate).to eq(false)
        end
      end

      describe "logged in user" do
        let(:serializer) { PostSerializer.new(post, scope: Guardian.new(user)) }

        describe "when user is not in restrict_translation_by_group" do
          it "cannot translate" do
            SiteSetting.restrict_translation_by_group = ""

            expect(serializer.can_translate).to eq(false)
          end
        end

        describe "when post is not in restrict_translation_by_poster_group" do
          it "cannot translate" do
            SiteSetting.restrict_translation_by_group = "#{group.id}"
            SiteSetting.restrict_translation_by_poster_group = ""

            expect(serializer.can_translate).to eq(false)
          end
        end

        describe "when user is in restrict_translation_by_group and poster in restrict_translation_by_poster_group" do
          before do
            SiteSetting.restrict_translation_by_group = "#{group.id}"
            SiteSetting.restrict_translation_by_poster_group = "#{post_user_group.id}"
          end

          describe "when post does not have DETECTED_LANG_CUSTOM_FIELD" do
            it "cannot translate" do
              expect(serializer.can_translate).to eq(false)
            end

            it "adds post id to redis if detected_language is blank" do
              post.custom_fields["detected_language"] = nil
              post.save_custom_fields

              expect { serializer.can_translate }.to change {
                Discourse.redis.sismember(DiscourseTranslator::LANG_DETECT_NEEDED, post.id)
              }.from(false).to(true)
            end
          end

          describe "when post has DETECTED_LANG_CUSTOM_FIELD matches user locale" do
            before do
              post.custom_fields[DiscourseTranslator::DETECTED_LANG_CUSTOM_FIELD] = "en"
              post.save
            end

            it { expect(serializer.can_translate).to eq(false) }
          end

          describe "when post has DETECTED_LANG_CUSTOM_FIELD does not match user locale" do
            before do
              post.custom_fields[DiscourseTranslator::DETECTED_LANG_CUSTOM_FIELD] = "jp"
              post.save
            end

            it { expect(serializer.can_translate).to eq(true) }
          end
        end
      end
    end
  end
end
