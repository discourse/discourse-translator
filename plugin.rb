# name: discourse-translator
# about: Provides inline translation of posts.
# version: 0.0.1
# authors: Alan Tan
# url: https://github.com/tgxworld/discourse-translator

enabled_site_setting :translator_enabled

after_initialize do
  module ::DiscourseTranslator
    PLUGIN_NAME = "discourse_translator".freeze

    class Engine < ::Rails::Engine
      engine_name PLUGIN_NAME
      isolate_namespace DiscourseTranslator
    end
  end

  require_dependency "application_controller"
  Dir["#{Rails.root}/plugins/discourse-translator/services/**/*.rb"].each { |file| require file }

  class DiscourseTranslator::TranslatorController < ::ApplicationController
    def translate
      raise PluginDisabled if !SiteSetting.translator_enabled

      params.require(:post_id)
      post = Post.find(params[:post_id].to_i)

      begin
        translation =
          case SiteSetting.translator
          when 'microsoft'
            DiscourseTranslator::Microsoft.translate(post)
          end

        render json: { translation: translation }, status: 200
      rescue
        render json: failed_json, status: 422
      end
    end
  end

  DiscourseTranslator::Engine.routes.draw do
    post "/translate" => "translator#translate"
  end

  Discourse::Application.routes.append do
    mount ::DiscourseTranslator::Engine, at: "translator"
  end
end
