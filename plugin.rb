# name: discourse-translator
# about: Provides inline translation of posts.
# version: 0.0.2
# authors: Alan Tan
# url: https://github.com/tgxworld/discourse-translator

enabled_site_setting :translator_enabled
register_asset "stylesheets/common/post.scss"

after_initialize do
  module ::DiscourseTranslator
    PLUGIN_NAME = "discourse_translator".freeze
    DETECTED_LANG_CUSTOM_FIELD = 'post_detected_lang'.freeze
    TRANSLATED_CUSTOM_FIELD = 'translated_text'.freeze

    class Engine < ::Rails::Engine
      engine_name PLUGIN_NAME
      isolate_namespace DiscourseTranslator
    end
  end

  require_dependency "application_controller"
  Dir["#{Rails.root}/plugins/discourse-translator/services/**/*.rb"].each { |file| require file }

  class DiscourseTranslator::TranslatorController < ::ApplicationController
    before_filter :ensure_logged_in

    def translate
      raise PluginDisabled if !SiteSetting.translator_enabled
      RateLimiter.new(current_user, "translate_post", 3, 1.minute).performed! unless current_user.staff?

      params.require(:post_id)
      post = Post.find(params[:post_id].to_i)

      begin
        detected_lang, translation = "DiscourseTranslator::#{SiteSetting.translator}".constantize.translate(post)
        render json: { translation: translation, detected_lang: detected_lang }, status: 200
      rescue ::DiscourseTranslator::TranslatorError => e
        render_json_error e.message, status: 422
      end
    end
  end

  Post.register_custom_field_type(::DiscourseTranslator::TRANSLATED_CUSTOM_FIELD, :json)

  require_dependency "post"
  class ::Post < ActiveRecord::Base
    before_update :clear_translator_custom_fields, if: :raw_changed?

    private

    def clear_translator_custom_fields
      self.custom_fields[DiscourseTranslator::DETECTED_LANG_CUSTOM_FIELD] = nil
      self.custom_fields[DiscourseTranslator::TRANSLATED_CUSTOM_FIELD] = {}
    end
  end

  require_dependency "cooked_post_processor"
  class ::CookedPostProcessor
    def post_process(bypass_bump = false)
      if SiteSetting.translator_enabled
        DistributedMutex.synchronize("post_process_#{@post.id}") do
          "DiscourseTranslator::#{SiteSetting.translator}".constantize.detect(@post)
          @post.save!
          @post.publish_change_to_clients! :revised
        end
      end

      super
    end
  end

  require_dependency "post_serializer"
  class ::PostSerializer
    attributes :can_translate

    def can_translate
      detected_lang = object.custom_fields[::DiscourseTranslator::DETECTED_LANG_CUSTOM_FIELD]

      if !detected_lang
        return false
      else
        detected_lang != "DiscourseTranslator::#{SiteSetting.translator}::SUPPORTED_LANG".constantize[I18n.locale]
      end
    end
  end

  DiscourseTranslator::Engine.routes.draw do
    post "translate" => "translator#translate"
  end

  Discourse::Application.routes.append do
    mount ::DiscourseTranslator::Engine, at: "translator"
  end
end
