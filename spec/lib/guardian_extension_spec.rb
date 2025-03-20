# frozen_string_literal: true

require "rails_helper"

describe DiscourseTranslator::Extensions::GuardianExtension do
  describe "anon user" do
    let!(:guardian) { Guardian.new }
    fab!(:post)

    before do
      SiteSetting.restrict_translation_by_group = "#{Group::AUTO_GROUPS[:everyone]}"
      SiteSetting.restrict_translation_by_poster_group = "#{Group::AUTO_GROUPS[:everyone]}"
    end

    describe "#user_group_allow_translate?" do
      it "returns false" do
        expect(guardian.user_group_allow_translate?).to eq(false)
      end
    end

    describe "#poster_group_allow_translate?" do
      it "returns false" do
        expect(guardian.poster_group_allow_translate?(post)).to eq(false)
      end
    end
  end

  describe "deleted poster" do
    fab!(:group)
    fab!(:user)
    fab!(:poster) { Fabricate(:user, groups: [group]) }
    fab!(:post) { Fabricate(:post, user: poster) }
    let!(:guardian) { Guardian.new(user) }

    describe "#poster_group_allow_translate?" do
      it "returns false when the post user has been deleted" do
        SiteSetting.restrict_translation_by_poster_group = "#{group.id}"

        post.update(user: nil)

        expect(guardian.poster_group_allow_translate?(post)).to eq(false)
      end
    end
  end

  describe "logged in user" do
    fab!(:group)
    fab!(:user) { Fabricate(:user, groups: [group]) }
    fab!(:post) { Fabricate(:post, user: user) }
    let(:guardian) { Guardian.new(user) }

    describe "#user_group_allow_translate?" do
      it "returns true when the user is in restrict_translation_by_group" do
        SiteSetting.restrict_translation_by_group = "#{group.id}"

        expect(guardian.user_group_allow_translate?).to eq(true)
      end

      it "returns false when the user is not in restrict_translation_by_group" do
        SiteSetting.restrict_translation_by_group = "#{Group::AUTO_GROUPS[:moderators]}"

        expect(guardian.user_group_allow_translate?).to eq(false)
      end
    end

    describe "#poster_group_allow_translate?" do
      it "returns true when the post user is in restrict_translation_by_poster_group" do
        SiteSetting.restrict_translation_by_poster_group = "#{group.id}"

        expect(guardian.poster_group_allow_translate?(post)).to eq(true)
      end

      it "returns false when the post user is not in restrict_translation_by_poster_group" do
        SiteSetting.restrict_translation_by_poster_group = "#{Group::AUTO_GROUPS[:moderators]}"

        expect(guardian.poster_group_allow_translate?(post)).to eq(false)
      end
    end
  end

  describe "#can_detect_language?" do
    fab!(:group)
    fab!(:user) { Fabricate(:user, groups: [group]) }
    fab!(:post) { Fabricate(:post, user: user, raw: "Hello, world!") }
    let(:guardian) { Guardian.new(user) }

    it "returns false when the post user is not in restrict_translation_by_poster_group" do
      SiteSetting.restrict_translation_by_poster_group = "#{Fabricate(:group).id}"

      expect(guardian.can_detect_language?(post)).to eq(false)
    end

    context "when post author is in allowed groups" do
      before do
        SiteSetting.restrict_translation_by_group = "#{group.id}"
        SiteSetting.restrict_translation_by_poster_group = "#{group.id}"
      end

      it "returns true when the post is not a small action post" do
        expect(guardian.can_detect_language?(post)).to eq(true)
      end

      it "returns false when the post is a small action post" do
        post.update!(post_type: Post.types[:small_action])

        expect(guardian.can_detect_language?(post)).to eq(false)
      end

      it "returns false when the post raw is empty" do
        expect { post.update(raw: "") }.to change { guardian.can_detect_language?(post) }.from(
          true,
        ).to(false)
      end
    end
  end

  describe "#can_translate?" do
    fab!(:group)
    fab!(:user) { Fabricate(:user, locale: "en", groups: [group]) }
    fab!(:post) { Fabricate(:post, created_at: 5.minutes.ago) }

    let(:guardian) { Guardian.new(user) }

    it "returns false when translator disabled" do
      SiteSetting.translator_enabled = false

      expect(guardian.can_translate?(post)).to eq(false)
    end

    describe "when translator enabled and user locale is pt" do
      before do
        SiteSetting.translator_enabled = true
        I18n.locale = :pt
      end

      it "cannot translate bot posts" do
        post.update!(user: Discourse.system_user)
        expect(Guardian.new.can_translate?(post)).to eq(false)
      end

      describe "anon user" do
        before { SiteSetting.restrict_translation_by_group = "#{Group::AUTO_GROUPS[:everyone]}" }

        it "cannot translate" do
          SiteSetting.experimental_inline_translation = true
          expect(Guardian.new.can_translate?(post)).to eq(false)

          SiteSetting.experimental_inline_translation = false
          expect(Guardian.new.can_translate?(post)).to eq(false)
        end
      end

      it "cannot translate when post detected locale matches i18n locale" do
        post.set_detected_locale("pt")

        SiteSetting.experimental_inline_translation = true
        expect(guardian.can_translate?(post)).to eq(false)

        SiteSetting.experimental_inline_translation = false
        expect(guardian.can_translate?(post)).to eq(false)
      end

      it "allows translation depending on when the post is created" do
        SiteSetting.restrict_translation_by_group = "#{group.id}"

        post.update(created_at: Time.now)
        expect(guardian.can_translate?(post)).to eq(false)

        post.set_detected_locale("jp")
        expect(guardian.can_translate?(post)).to eq(true)

        post.update(created_at: 5.minutes.ago)
        expect(guardian.can_translate?(post)).to eq(true)

        post.set_detected_locale("pt")
        expect(guardian.can_translate?(post)).to eq(false)
      end

      describe "when experimental_inline_translation enabled" do
        before do
          SiteSetting.experimental_inline_translation = true

          SiteSetting.automatic_translation_backfill_rate = 1
          SiteSetting.automatic_translation_target_languages = "pt"
        end

        describe "logged in user" do
          it "cannot translate when user is not in restrict_translation_by_group" do
            SiteSetting.restrict_translation_by_group = "#{group.id + 1}"

            expect(guardian.can_translate?(post)).to eq(false)
          end

          describe "user is in restrict_translation_by_group" do
            before { SiteSetting.restrict_translation_by_group = "#{group.id}" }

            it "cannot translate when post has translation for user locale" do
              post.set_detected_locale("ja")
              post.set_translation("pt", "Olá, mundo!")

              expect(guardian.can_translate?(post)).to eq(false)
            end

            it "can translate when post does not have translation for user locale" do
              post.set_detected_locale("jp")

              expect(guardian.can_translate?(post)).to eq(true)
            end
          end
        end
      end

      describe "when experimental inline translation disabled" do
        before { SiteSetting.experimental_inline_translation = false }

        it "cannot translate when user is not in restrict_translation_by_group" do
          SiteSetting.restrict_translation_by_group = "#{group.id + 1}"

          expect(guardian.can_translate?(post)).to eq(false)
        end

        describe "user is in restrict_translation_by_group" do
          before { SiteSetting.restrict_translation_by_group = "#{group.id}" }

          it "can translate when post's detected locale does not match i18n locale, regardless of translation presence" do
            post.set_detected_locale("jp")
            expect(guardian.can_translate?(post)).to eq(true)

            post.set_translation("pt", "Olá, mundo!")
            expect(guardian.can_translate?(post)).to eq(true)
          end

          it "cannot translate if poster is not in restrict_translation_by_poster_group" do
            SiteSetting.restrict_translation_by_poster_group = "#{Group::AUTO_GROUPS[:staff]}"

            expect(guardian.can_translate?(post)).to eq(false)
          end

          it "can translate if poster is in restrict_translation_by_poster_group" do
            poster = post.user
            poster_group = Fabricate(:group, users: [poster])

            SiteSetting.restrict_translation_by_poster_group = "#{poster_group.id}"
            expect(guardian.can_translate?(post)).to eq(true)

            SiteSetting.restrict_translation_by_poster_group = ""
            expect(guardian.can_translate?(post)).to eq(true)
          end
        end
      end
    end

    it "does not error out when post user is deleted" do
      post.update(user: nil)

      expect { guardian.can_translate?(post) }.not_to raise_error
    end
  end
end
