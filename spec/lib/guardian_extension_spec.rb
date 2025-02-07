# frozen_string_literal: true

require "rails_helper"

describe DiscourseTranslator::GuardianExtension do
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
    fab!(:post)

    let(:guardian) { Guardian.new(user) }

    it "returns false when translator disabled" do
      SiteSetting.translator_enabled = false

      expect(guardian.can_translate?(post)).to eq(false)
    end

    describe "when translator enabled" do
      before { SiteSetting.translator_enabled = true }

      describe "anon user" do
        before { SiteSetting.restrict_translation_by_group = "#{Group::AUTO_GROUPS[:everyone]}" }

        it "cannot translate" do
          expect(Guardian.new.can_translate?(post)).to eq(false)
        end
      end

      describe "logged in user" do
        it "cannot translate when user is not in restrict_translation_by_group" do
          SiteSetting.restrict_translation_by_group = "#{group.id + 1}"

          expect(guardian.can_translate?(post)).to eq(false)
        end

        describe "user is in restrict_translation_by_group" do
          before { SiteSetting.restrict_translation_by_group = "#{group.id}" }

          describe "locale is :xx" do
            before { I18n.stubs(:locale).returns(:pt) }

            it "cannot translate when post does not have detected locale" do
              expect(post.detected_locale).to eq(nil)
              expect(guardian.can_translate?(post)).to eq(false)
            end

            it "cannot translate when post detected locale matches i18n locale" do
              post.set_detected_locale("pt")

              expect(guardian.can_translate?(post)).to eq(false)
            end

            it "can translate when post detected locale does not match i18n locale" do
              post.set_detected_locale("jp")

              expect(guardian.can_translate?(post)).to eq(true)
            end
          end
        end
      end
    end
  end
end
