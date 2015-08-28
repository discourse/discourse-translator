require 'spec_helper'

describe ::DiscourseTranslator::TranslatorController do
  routes { ::DiscourseTranslator::Engine.routes }

  let!(:user) { log_in }

  before do
    SiteSetting.translator_enabled = true
    SiteSetting.translator = 'Microsoft'
  end

  describe "#translate" do
    describe "when disable" do
      before { SiteSetting.translator_enabled = false }

      it 'should deny request to translate' do
        expect{ xhr :put, :translate, { post_id: 1 } }
          .to raise_error ApplicationController::PluginDisabled
      end
    end

    describe "when enabled" do
      let(:post) { Fabricate(:post) }

      it 'raises an error with a missing parameter' do
        expect{ xhr :put, :translate }
          .to raise_error(ActionController::ParameterMissing)
      end

      it 'rescues all exceptions' do
        DiscourseTranslator::Microsoft.expects(:translate).raises(StandardError)

        xhr :put, :translate, { post_id: post.id }

        expect(response).to have_http_status(422)
      end

      it 'returns the translated text' do
        DiscourseTranslator::Microsoft.expects(:translate).with(post).returns(['ja', 'ニャン猫'])

        xhr :put, :translate, { post_id: post.id }

        expect(response).to be_success
        expect(response.body).to eq({ translation: 'ニャン猫', detected_lang: 'ja' }.to_json)
      end
    end
  end
end
