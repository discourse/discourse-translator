require 'rails_helper'

RSpec.describe ::DiscourseTranslator::TranslatorController do
  routes { ::DiscourseTranslator::Engine.routes }

  before do
    SiteSetting.translator_enabled = true
    SiteSetting.translator = 'Microsoft'
  end

  after do
    SiteSetting.translator_enabled = false
  end

  describe "#translate" do
    describe 'anon user' do
      it 'should not allow translation of posts' do
        expect{ xhr :post, :translate, { post_id: 1 } }
          .to raise_error Discourse::NotLoggedIn
      end
    end

    describe 'logged in user' do
      let!(:user) { log_in }

      describe "when disabled" do
        before { SiteSetting.translator_enabled = false }

        it 'should deny request to translate' do
          response = xhr :post, :translate, { post_id: 1 }

          expect(response.status).to eq(404)
        end
      end

      describe "when enabled" do
        let(:reply) { Fabricate(:post) }

        it 'raises an error with a missing parameter' do
          expect{ xhr :post, :translate }
            .to raise_error(ActionController::ParameterMissing)
        end

        it 'raises the right error when post_id is invalid' do
          expect { xhr :post, :translate, post_id: -1 }
            .to raise_error(Discourse::InvalidParameters)
        end

        it 'rescues translator errors' do
          DiscourseTranslator::Microsoft.expects(:translate).raises(::DiscourseTranslator::TranslatorError)

          xhr :post, :translate, { post_id: reply.id }

          expect(response).to have_http_status(422)
        end

        it 'returns the translated text' do
          DiscourseTranslator::Microsoft.expects(:translate).with(reply).returns(['ja', 'ニャン猫'])

          xhr :post, :translate, { post_id: reply.id }

          expect(response).to be_success
          expect(response.body).to eq({ translation: 'ニャン猫', detected_lang: 'ja' }.to_json)
        end
      end
    end
  end
end
