# frozen_string_literal: true

require "rails_helper"

RSpec.describe ::DiscourseTranslator::TranslatorController do
  routes { ::DiscourseTranslator::Engine.routes }

  before do
    SiteSetting.translator_enabled = true
    SiteSetting.translator = "Microsoft"
    SiteSetting.restrict_translation_by_group = "#{Group.find_by(name: "trust_level_1").id}"
  end

  after { SiteSetting.translator_enabled = false }

  shared_examples "translation_successful" do
    it "returns the translated text" do
      DiscourseTranslator::Microsoft.expects(:translate).with(reply).returns(%w[ja ニャン猫])
      if reply.is_first_post?
        DiscourseTranslator::Microsoft.expects(:translate).with(reply.topic).returns(%w[ja タイトル])
      end

      post :translate, params: { post_id: reply.id }, format: :json

      expect(response).to have_http_status(:ok)
      expect(response.body).to eq(
        { translation: "ニャン猫", detected_lang: "ja", title_translation: "タイトル" }.to_json,
      )
    end
  end

  shared_examples "deny_request_to_translate" do
    it "should deny request to translate" do
      response = post :translate, params: { post_id: reply.id }, format: :json
      expect(response).to have_http_status(:forbidden)
    end
  end

  describe "#translate" do
    describe "anon user" do
      it "should not allow translation of posts" do
        post :translate, params: { post_id: 1 }, format: :json
        expect(response).to have_http_status(:forbidden)
      end
    end

    describe "logged in user" do
      let!(:user) do
        user = log_in
        user.group_users << Fabricate(:group_user, user: user, group: Group[:trust_level_1])
        user
      end
      let!(:poster) do
        poster = Fabricate(:user)
        poster.group_users << Fabricate(:group_user, user: user, group: Group[:trust_level_2])
        poster
      end

      describe "when config translator_enabled disabled" do
        before { SiteSetting.translator_enabled = false }

        it "should deny request to translate" do
          response = post :translate, params: { post_id: 1 }, format: :json

          expect(response).to have_http_status(:not_found)
        end
      end

      describe "when enabled" do
        let(:reply) { Fabricate(:post, user: poster) }

        it "raises an error with a missing parameter" do
          post :translate, format: :json
          expect(response).to have_http_status(:bad_request)
        end

        it "raises the right error when post_id is invalid" do
          post :translate, params: { post_id: -1 }, format: :json
          expect(response).to have_http_status(:bad_request)
        end

        it "raises the right error when post is inaccessible" do
          user = log_in
          mypost = Fabricate(:private_message_post)
          post :translate, params: { post_id: mypost.id }, format: :json
          expect(response.status).to eq(403)
        end

        it "rescues translator errors" do
          DiscourseTranslator::Microsoft.expects(:translate).raises(
            ::DiscourseTranslator::TranslatorError,
          )

          post :translate, params: { post_id: reply.id }, format: :json

          expect(response).to have_http_status(:unprocessable_entity)
        end

        describe "all groups can translate" do
          include_examples "translation_successful"
        end

        describe "user is in a allowlisted group" do
          before do
            SiteSetting.restrict_translation_by_group =
              "#{Group.find_by(name: "admins").id}|not_in_the_list"
          end
          let!(:user) { log_in :admin }
          include_examples "translation_successful"
        end

        describe "user is not in a allowlisted group" do
          before { SiteSetting.restrict_translation_by_group = "not_in_the_list" }

          include_examples "deny_request_to_translate"
        end

        describe "restrict_translation_by_poster_group" do
          before do
            SiteSetting.restrict_translation_by_group =
              "#{Group.find_by(name: "admins").id}|not_in_the_list"
          end
          describe "post made by an user in a allowlisted group" do
            before do
              SiteSetting.restrict_translation_by_poster_group = "#{poster.groups.first.id}"
            end
            let!(:user) { log_in :admin }
            include_examples "translation_successful"
          end

          describe "post made by an user not in a allowlisted group" do
            before { SiteSetting.restrict_translation_by_poster_group = "not_in_the_list" }
            let!(:user) { log_in :admin }
            include_examples "deny_request_to_translate"
          end
        end
      end
    end
  end
end
